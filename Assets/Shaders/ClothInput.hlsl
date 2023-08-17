#ifndef CUSTOM_CLOTH_INPUT_INCLUDED
#define CUSTOM_CLOTH_INPUT_INCLUDED

TEXTURE2D(_BaseMap);
TEXTURE2D(_SheenColorMap);
TEXTURE2D(_SubsurfaceColorMap);
TEXTURE2D(_RoughnessMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_DetailNormalMap);
TEXTURE2D(_HeightMap);
TEXTURE2D(_DisplacementMap);
SAMPLER(sampler_DisplacementMap);
TEXTURE2D(_OcclusionMap);
TEXTURE2D(_EmissionMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_DFGLUT);
SAMPLER(sampler_DFGLUT);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _SheenColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _SubsurfaceColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Roughness)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailNormalMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _HeightScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _DisplacementScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _OcclusionStrength)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
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

float4 GetSheenColor(float2 uv)
{
    #if !defined(_USE_LUMINANCE)
        return SAMPLE_TEXTURE2D(_SheenColorMap, sampler_BaseMap, uv) * INPUT_PROP(_SheenColor);
    #else
        return Luminance(GetBase(uv));
    #endif
}

float4 GetSubsurfaceColor(float2 uv)
{
    return SAMPLE_TEXTURE2D(_SubsurfaceColorMap, sampler_BaseMap, uv) * INPUT_PROP(_SubsurfaceColor);
}

float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float2 TransformDetailUV (float2 detailUV) {
    float4 detailST = INPUT_PROP(_DetailNormalMap_ST);
    return detailUV * detailST.xy + detailST.zw;
}

float2 GetDFG(float NoV, float perceptualRoughness)
{
    float2 uv = float2(lerp(0, 0.99, NoV), lerp(0, 0.99, perceptualRoughness));
    float2 dfg = SAMPLE_TEXTURE2D_LOD(_DFGLUT, sampler_DFGLUT, uv, 0.0).bb;
    
    return dfg;
}

float2 GetDFG(Surface surface)
{
    return GetDFG(dot(surface.normal, surface.viewDirection), surface.perceptualRoughness);
}

float GetPerceptualRoughness(float2 uv)
{
    return INPUT_PROP(_Roughness) * SAMPLE_TEXTURE2D(_RoughnessMap, sampler_BaseMap, uv).r;
}

float3 GetNormalTS(float2 uv)
{
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, uv);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = UnpackNormalScale(map, scale);

    #if defined(_DETAIL_MAP)
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_BaseMap, uv);
        scale = INPUT_PROP(_DetailNormalScale);
        float3 detailNormal = DecodeNormal(map, scale).xyz;
        normal = NormalBlendRNM(normal, detailNormal);
    #endif
    
    return normal;
}

float GetHeight(float2 uv)
{
    return UnpackHeightmap(SAMPLE_TEXTURE2D(_HeightMap, sampler_BaseMap, uv)) - 0.5f;
}

float GetHeightScale()
{
    return INPUT_PROP(_HeightScale);
}

float GetDisplacement(float2 uv)
{
    float map = SAMPLE_TEXTURE2D_LOD(_DisplacementMap, sampler_DisplacementMap, uv, 0.0).r - 0.5;
    float scale = INPUT_PROP(_DisplacementScale);

    return map * scale;
}

float GetOcclusion(float2 uv)
{
    #if defined(_OCCLUSIONMAP)
        float map = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_BaseMap, uv).r;
        float strength = INPUT_PROP(_OcclusionStrength);
        return map * strength;
    #else
        return 1.0;
    #endif
}

float3 GetEmission(float2 uv)
{
    #if defined(_EMISSION)
        float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, uv);
        float4 color = INPUT_PROP(_EmissionColor);
        return map.rgb * color.rgb;
    #else
        return 0.0;
    #endif
}

float GetCutoff()
{
    return INPUT_PROP(_Cutoff);
}

#endif