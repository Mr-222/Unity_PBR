#ifndef CUSTOM_META_PASS_INCLUDED
#define CUSTOM_META_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

struct Attributes {
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv0          : TEXCOORD0;
    float2 uv1          : TEXCOORD1;
    float2 uv2          : TEXCOORD2;
    float4 color		: COLOR;
};

struct Varyings {
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD0;
};

Varyings MetaPassVertex(Attributes input) {
    Varyings output;
    output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2, unity_LightmapST, unity_DynamicLightmapST);
    output.uv = TransformBaseUV(input.uv0);
    return output;
}

half4 MetaPassFragment(Varyings input) : SV_Target {
    half4 baseMap = GetBase(input.uv);
    #if defined(_ALPHATEST_ON)
        clip(baseMap.a - GetCutoff());
    #endif
    float4 baseColor = baseMap * GetBaseColor();

    Surface surface;
    surface.baseColor = baseColor.rgb;
    surface.emission = GetEmission(input.uv);
    surface.alpha = baseColor.a;
    surface.metallic = GetMetallic(input.uv);
    surface.reflectance = GetReflectance();
    surface.perceptualRoughness = GetPerceptualRoughness(input.uv) + 1e-5;
    surface.roughness = PerceptualRoughnessToRoughness(surface.perceptualRoughness);

    CustomBRDFData brdf;
    InitializeBRDFData(surface, brdf);

    MetaInput metaInput;
    metaInput.Albedo = brdf.diffuseColor + brdf.f0 * brdf.roughness * 0.5;
    metaInput.Emission = surface.emission;

    return MetaFragment(metaInput);
}

#endif