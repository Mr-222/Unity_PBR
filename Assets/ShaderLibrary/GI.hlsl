#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

float3 SpecularIBL(float3 positionWS, float3 n, float3 v, CustomBRDFData brdf, float2 dfg, bool isCloth = false)
{
    float3 r = reflect(-v, n);
    float3 ld = GlossyEnvironmentReflection(r, positionWS, brdf.perceptualRoughness, 1.0);
	float3 luminance;
    if (isCloth)
    {
	    luminance = brdf.f0 * dfg.y * ld;
    }
    else
    {
    	#if defined(_MULTISCATTERING)
    		//  Er() = (1 - f0) * DFV.x + f0 * DFV.y
    		//       = mix(DFV.xxx, DFV.yyy, 0)
    		luminance = ((1 - brdf.f0) * dfg.x + brdf.f0 * dfg.y) * ld;
    	#else
    		luminance = (brdf.f0 * dfg.x + 1.0 * dfg.y) * ld;
    	#endif
    }

	#if defined(_NORMALMAP)
		// horizon occlusion with falloff, should be computed for direct specular too, in case of light leaking
		// See https://google.github.io/filament/Filament.html#lighting/occlusion Section5.6.2.1
		float horizon = min(1.0 + dot(r, n), 1.0);
		luminance *= horizon * horizon;
	#endif
	
    return luminance;
}

float3 SpecularIBLClearCoat(float3 positionWS, float3 n, float3 v, CustomBRDFData brdf)
{
	float3 r = reflect(-v, n);
	float3 ld = GlossyEnvironmentReflection(r, positionWS, brdf.clearCoatPerceptualRoughness, 1.0);
	
	return ld;
}

float3 SampleLightMap(float2 lightMapUV)
{
	#if defined(LIGHTMAP_ON)
		return SampleSingleLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,
			float4(1.0, 1.0, 0.0, 0.0),
			#if defined(UNITY_LIGHTMAP_FULL_HDR)
				false,
			#else
				true,
			#endif
			float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0));
	#else
		return 0.0;
	#endif
}

float4 SampleShadowMask(float2 lightMapUV)
{
	#if defined(LIGHTMAP_ON) && defined(SHADOWS_SHADOWMASK)
		return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
	#elif !defined(LIGHTMAP_ON)
		return unity_ProbesOcclusion;
	#else
		return 1.0;
	#endif
}

float3 SampleLightProbe(float3 positionWS, float3 normalWS) {
	#if defined(LIGHTMAP_ON)
		return 0.0;
	#else
		if (unity_ProbeVolumeParams.x) {
			return SampleProbeVolumeSH4(
				TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
				positionWS, normalWS,
				unity_ProbeVolumeWorldToObject,
				unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
				unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
			);
		}
		else {
			float4 coefficients[7];
			coefficients[0] = unity_SHAr;
			coefficients[1] = unity_SHAg;
			coefficients[2] = unity_SHAb;
			coefficients[3] = unity_SHBr;
			coefficients[4] = unity_SHBg;
			coefficients[5] = unity_SHBb;
			coefficients[6] = unity_SHC;
			return max(0.0, SampleSH9(coefficients, normalWS));
		}
	#endif
}

float ComputeSpecularAO(float NoV, float ao, float roughness)
{
	return saturate(pow(abs(NoV + ao), exp2(-16.0 * roughness - 1.0)) - 1.0 + ao);
}

float3 GetGI(float2 lightMapUV, Surface surfaceWS, CustomBRDFData brdf, bool isCloth = false)
{
	float3 specular = SpecularIBL(surfaceWS.position, surfaceWS.normal, surfaceWS.viewDirection, brdf, brdf.dfg, isCloth)
		* ComputeSpecularAO(dot(surfaceWS.normal, surfaceWS.viewDirection), surfaceWS.occlusion, surfaceWS.roughness);
	
	float3 diffuse = brdf.diffuseColor * (SampleLightProbe(surfaceWS.position, surfaceWS.normal) + SampleLightMap(lightMapUV)) * surfaceWS.occlusion;

	#if defined(_CLOTH_SSS) || defined(_CLEARCOAT)
		float NoV = dot(surfaceWS.normal, surfaceWS.viewDirection);
	
	#ifdef _CLOTH_SSS
		diffuse *= saturate((NoV + 0.5) / 2.25);
		diffuse *= saturate(brdf.subsurfaceColor + NoV);
	#endif
	
	#ifdef _CLEARCOAT
		// clearCoat_NoV == shading_NoV if the clear coat layer doesn't have its own normal map
		float Fc = F_Schlick(0.04, NoV) * brdf.clearCoat;
		// base layer attenuation for energy compensation
		diffuse *= 1.0 - Fc;
		specular *= Square(1.0 - Fc);
		specular += SpecularIBLClearCoat(surfaceWS.position, surfaceWS.normal, surfaceWS.viewDirection, brdf) * Fc;
	#endif
	
	#endif
	
	return specular + diffuse;
}

#endif