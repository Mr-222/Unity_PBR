#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "LTC.hlsl"

float3 GetIlluminance(Light light)
{
    float3 illuminance = light.distanceAttenuation * light.color * light.shadowAttenuation;
    return illuminance;
}

float3 GetLighting(Surface surface, CustomBRDFData brdf, Light light, uint matCategory)
{
    float3 illuminance = GetIlluminance(light);

    float3 luminance;
    if (matCategory == 0)
    {
        #ifdef _CLEARCOAT
            luminance = clearCoatBRDF(surface.normal, light.direction, surface.viewDirection, brdf) * illuminance;
        #else
            luminance = standardBRDF(surface.normal, light.direction, surface.viewDirection, brdf) * illuminance;
        #endif
    }
    else if (matCategory == 1)
    {
        luminance = anisotropyBRDF(surface.normal, light.direction, surface.viewDirection, surface.tangent, surface.bitangent, brdf) * illuminance;
    }
    else
    {
        luminance = clothBRDF(surface.normal, light.direction, surface.viewDirection, brdf) * illuminance;
    }

    #if defined(_NORMALMAP)
        // horizon occlusion with falloff, should be computed for indirect specular too, in case of light leaking
        // See https://google.github.io/filament/Filament.html#lighting/occlusion Section5.6.2.1
        float horizon = min(1.0 + dot(surface.normal, light.direction), 1.0);
        luminance *= horizon * horizon;
    #endif
    
    return luminance;
}

float GetDistanceAtten(float distanceSqr, float lightInvRadiusSqr)
{
    float factor = distanceSqr * lightInvRadiusSqr;
    float smoothFactor = max(1.0 - factor * factor, 0.0);
    return smoothFactor * smoothFactor / max(distanceSqr, 1e-4);
}

float GetSpotAngleAtten(float3 l, float3 lightDir, float2 spotAttenuation) {
    // Spot Attenuation with a linear falloff can be defined as
    // (SdotL - cosOuterAngle) / (cosInnerAngle - cosOuterAngle)
    // This can be rewritten as
    // invAngleRange = 1.0 / (cosInnerAngle - cosOuterAngle)
    // SdotL * invAngleRange + (-cosOuterAngle * invAngleRange)
    // SdotL * spotAttenuation.x + spotAttenuation.y
    // the scale and offset computations can be done CPU-side
    
    float cd = dot(l, lightDir);
    float atten = saturate(cd * spotAttenuation.x + spotAttenuation.y);
    return atten * atten;
}

Light GetAddtionalLightCustom(uint i, float3 positionWS, float4 shadowMask)
{
    int index = GetPerObjectLightIndex(i);
    Light light;
    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        float4 lightPositionWS = _AdditionalLightsBuffer[index].position;
        float3 color = _AdditionalLightsBuffer[index].color.rgb;
        float4 distanceAndSpotAttenuation = _AdditionalLightsBuffer[index].attenuation;
        float4 spotDirection = _AdditionalLightsBuffer[index].spotDirection;
    
    #ifdef _LIGHT_LAYERS
        light.layerMask = _AdditionalLightsBuffer[index].layerMask;
    #else
        light.layerMask = DEFAULT_LIGHT_LAYERS;
    #endif
    
    #else
        float4 lightPositionWS = _AdditionalLightsPosition[index];
        float3 color = _AdditionalLightsColor[index].rgb;
        float4 distanceAndSpotAttenuation = _AdditionalLightsAttenuation[index];
        float4 spotDirection = _AdditionalLightsSpotDir[index];
    
    #ifdef _LIGHT_LAYERS
        light.layerMask = asuint(_AdditionalLightsLayerMasks[index]);
    #else
        light.layerMask = DEFAULT_LIGHT_LAYERS;
    #endif
    
    #endif
    
    // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
    // This way the following code will work for both directional and punctual lights.
    float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
    float distanceSqaure = dot(lightVector ,lightVector);
    float3 lightDiretion = lightVector * rsqrt(distanceSqaure);
    
    float distanceAttenuation = GetDistanceAtten(distanceSqaure, distanceAndSpotAttenuation.x);
    float SpotAngleAttenuation = GetSpotAngleAtten(lightDiretion, spotDirection.xyz, distanceAndSpotAttenuation.zw);

    light.direction = lightDiretion;
    light.color = color;
    light.distanceAttenuation = distanceAttenuation * SpotAngleAttenuation;
    #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        float4 occlusionProbeChannels = _AdditionalLightsBuffer[index].occlusionProbeChannels
    #else
        float4 occlusionProbeChannels = _AdditionalLightsOcclusionProbes[index];
    #endif
    light.shadowAttenuation = AdditionalLightShadow(index, positionWS, light.direction, shadowMask, occlusionProbeChannels);

    #if defined(_LIGHT_COOKIES)
        real3 cookieColor = SampleAdditionalLightCookie(lightIndex, positionWS);
        light.color *= cookieColor;
    #endif

    return light;
}

float3 GetAreaLighting(Surface surface, CustomBRDFData brdf)
{
    // Use roughness and sqrt(1 - cos_theta) to sample M inverse matrix
    float NoV = saturate(dot(surface.viewDirection, surface.normal));
    float2 uv = float2(brdf.roughness, sqrt(1.0 - NoV));
    uv = uv * LUT_SCALE + LUT_BIAS;
    // I did not manually flip the texture, so flip it here
    uv.y = 1.0 - uv.y;

    float4 t1 = SAMPLE_TEXTURE2D(_LTC1, sampler_LTC1, uv);
    float4 t2 = SAMPLE_TEXTURE2D(_LTC2, sampler_LTC2, uv);

    float3x3 Minv = float3x3(
        t1.x, 0.0, t1.z,
        0.0, 1.0, 0.0,
        t1.y, 0.0, t1.w
    );
    
    float3x3 E = float3x3(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    );
    
    float3 diffuse = 0.0;
    float3 specular = 0.0;
    for (int i = 0; i < _AreaLightNum; i++)
    {
        float4 points[4] = {
            _AreaLightVertexPositions[i*4],
            _AreaLightVertexPositions[i*4+1],
            _AreaLightVertexPositions[i*4+2],
            _AreaLightVertexPositions[i*4+3]
        };
        diffuse += LTC_Evaluate(surface.normal, surface.viewDirection, surface.position, E, points, _DoubleSided[i], false, i) * _AreaLightColor[i].rgb * _AreaLightIntensity[i];
        specular += LTC_Evaluate(surface.normal, surface.viewDirection, surface.position, Minv, points, _DoubleSided[i], true, i) * _AreaLightColor[i].rgb * _AreaLightIntensity[i];
    } 
    
    // Norm & Fresnel
    specular *= brdf.f0 * t2.x + (1.0 - brdf.f0) * t2.y;
    float3 result = specular + brdf.diffuseColor * diffuse;
    
    return result;
}

/*
 * matCategory specifies the material BRDF.
 * 0 : Standard BRDF
 * 1 : Anisotropy BRDF
 * 2 : Cloth BRDF
 */
float3 GetLighting(float2 lightMapUV, Surface surface, CustomBRDFData brdf, uint matCategory)
{
    float3 luminance = 0.0;
    
    float4 shadowMask = SampleShadowMask(lightMapUV);
    
    // Main light
    Light mainLight = GetMainLight(TransformWorldToShadowCoord(surface.position), surface.position, shadowMask);
    luminance += GetLighting(surface, brdf, mainLight, matCategory);
    
    // Additional light
    for (int i=0; i<GetAdditionalLightsCount(); i++)
    {
        Light light = GetAddtionalLightCustom(i, surface.position, shadowMask);
        luminance += GetLighting(surface, brdf, light, matCategory);
    }

    #if defined(_QUAD_AREA_LIGHT)
        luminance += GetAreaLighting(surface, brdf);
    #endif

    // Global Illumination
    bool isCloth = false;
    if (matCategory == 2)
    {
        isCloth = true;
    }
    luminance += GetGI(lightMapUV, surface, brdf, isCloth);

    return luminance;
}

#endif