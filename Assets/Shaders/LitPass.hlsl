#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#if defined(LIGHTMAP_ON)
    #define LIGHTMAP_UV_ATTRIBUTE float2 lightMapUV : TEXCOORD1;
    #define LIGHTMAP_UV_VARYINGS float2 lightMapUV : VAR_LIGHTMAP_UV;
    #define TRANSFER_LIGHTMAP_DATA(input, output) output.lightMapUV = input.lightMapUV * \
        unity_LightmapST.xy + unity_LightmapST.zw;
    #define LIGHTMAP_UV_FRAGMENT_DATA input.lightMapUV
#else
    #define LIGHTMAP_UV_ATTRIBUTE 
    #define LIGHTMAP_UV_VARYINGS 
    #define TRANSFER_LIGHTMAP_DATA(input, output) 
    #define LIGHTMAP_UV_FRAGMENT_DATA 0.0
#endif

struct Attributes
{
    float4 positionOS : POSITION;
    float2 baseUV     : TEXCOORD0;
    float4 normalOS   : NORMAL;
    float4 tangentOS : TANGENT;
    LIGHTMAP_UV_ATTRIBUTE
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS  : SV_POSITION;
    float2 baseUV      : TEXCOORD0;
    float2 detailUV    : TEXCOORD1;
    float3 positionWS  : TEXCOORD2;
    float3 normalWS    : TEXCOORD3;
    float4 tangentWS   : TEXCOORD4;
    float3 bitangentWS : TEXCOORD5;
    LIGHTMAP_UV_VARYINGS
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;

    TRANSFER_LIGHTMAP_DATA(input, output);
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = positionInputs.positionCS;
    output.baseUV = TransformBaseUV(input.baseUV);
    output.detailUV = TransformDetailUV(input.baseUV);
    output.positionWS = positionInputs.positionWS;

    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz, input.tangentOS);
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);
    output.bitangentWS = normalInputs.bitangentWS;

    #if _DISPLACEMENTMAP
        float displacement = GetDisplacement(input.baseUV);
        output.normalWS = normalize(output.normalWS);
        output.positionWS += output.normalWS * displacement;
    #endif
    
    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);

    #ifdef _HEIGHTMAP
        float3x3 tangentToWorld = float3x3(input.tangentWS.xyz, input.bitangentWS, input.normalWS);
        float3 positionTS = TransformWorldToTangent(input.positionWS, tangentToWorld);
        float3 cameraPosTS = TransformWorldToTangent(_WorldSpaceCameraPos, tangentToWorld);
        float3 viewDir = normalize(cameraPosTS - positionTS);
        input.baseUV = ParallaxMapping(GetHeight(input.baseUV), viewDir);
    #endif
    
    half4 baseMap = GetBase(input.baseUV);
    float4 baseColor = baseMap * GetBaseColor();

    #if defined(_ALPHATEST_ON)
        clip(baseColor.a - GetCutoff());
    #endif

    Surface surface;
    surface.baseColor = baseColor.rgb;
    surface.emission = GetEmission(input.baseUV);
    surface.alpha = baseColor.a;
    surface.metallic = GetMetallic(input.baseUV);
    surface.occlusion = GetOcclusion(input.detailUV);
    surface.position = input.positionWS;
    #if defined(_NORMALMAP)
        float3 n = NormalTangentToWorld(
            GetNormalTS(input.baseUV), input.normalWS, input.tangentWS.xyz, input.tangentWS.w
        );
    #else 
        float3 n = normalize(input.normalWS);
    #endif
    surface.normal = n;
    surface.reflectance = GetReflectance();
    surface.perceptualRoughness = GetPerceptualRoughness(input.baseUV) + 1e-5;
    surface.roughness = PerceptualRoughnessToRoughness(surface.perceptualRoughness);
    #ifdef _CLEARCOAT
        ClearCoatConfig config = GetClearCoatConfig(input.baseUV);
        surface.clearCoat = config.strength;
        surface.clearCoatPerceptualRoughness = clamp(config.roughness, 0.089, 1.0);
        surface.clearCoatRoughness = surface.clearCoatPerceptualRoughness * surface.clearCoatPerceptualRoughness;
    #endif
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);

    CustomBRDFData brdf;
    InitializeBRDFData(surface, brdf);

    float3 luminance = GetLighting(LIGHTMAP_UV_FRAGMENT_DATA, surface, brdf, 0);

    luminance += surface.emission;
    
    // clamping brightness to 100 to avoid undesirable oversize blooming effect
    return float4(clamp(luminance, 0.0, 100.0), 1.0);
}

#endif