#ifndef CUSTOM_ANISOTROPY_INPUT_INCLUDED
#define CUSTOM_ANISOTROPY_INPUT_INCLUDED

TEXTURE2D(_BaseMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_TangentMap);
TEXTURE2D(_AnisoLevelMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_DFGLUT);
SAMPLER(sampler_DFGLUT);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _Reflectance)
    UNITY_DEFINE_INSTANCED_PROP(float, _AnisotropyStrength)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

float4 GetBaseColor()
{
    return INPUT_PROP(_BaseColor);
}

float4 GetBase(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
}

float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float2 GetDFG(float NoV, float perceptualRoughness)
{
    float2 uv = float2(lerp(0, 0.99, NoV), lerp(0, 0.99, perceptualRoughness));
    float2 dfg = SAMPLE_TEXTURE2D_LOD(_DFGLUT, sampler_DFGLUT, uv, 0.0).xy;
    return dfg;
}

float2 GetDFG(Surface surface)
{
    return GetDFG(dot(surface.normal, surface.viewDirection), surface.perceptualRoughness);
}


MaskConfig GetMask(float2 uv)
{
    MaskConfig config;
    float4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, uv);
    config.metallic = mask.r;
    config.occlusion = mask.g;
    config.perceptualRoughness = 1.0 - mask.a;

    return config;
}

float GetReflectance()
{
    return INPUT_PROP(_Reflectance);
}

float3 GetNormalTS(float2 uv)
{
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, uv);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = UnpackNormalScale(map, scale);

    return normal;
}

float3 GetTangentTS(float2 uv)
{
    float4 map = SAMPLE_TEXTURE2D(_TangentMap, sampler_BaseMap, uv);
    float scale = INPUT_PROP(_NormalScale);
    float3 tangent = UnpackNormalScale(map, scale);

    return tangent;
}

float GetAnisotropyStrength()
{
    return INPUT_PROP(_AnisotropyStrength);
}

float GetAnisotropy(float2 uv)
{
    float anisotropy = SAMPLE_TEXTURE2D(_AnisoLevelMap, sampler_BaseMap, uv).x;
    anisotropy = anisotropy * 2 - 1.0;
    return GetAnisotropyStrength() * anisotropy;
}

AnisoConfig GetAnisoConfig(float2 uv)
{
    AnisoConfig config;
    config.anisoStrength = GetAnisotropyStrength();
    config.anisotropy = GetAnisotropy(uv);

    return config;
}

float GetMetallic(float2 uv)
{
    return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, uv).r;
}

float GetPerceptualRoughness(float2 uv)
{
    return 1.0 - SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, uv).a;
}

float3 GetEmission(float2 uv)
{
    return 0.0;
}

float GetCutoff()
{
    return INPUT_PROP(_Cutoff);
}

#endif