#ifndef CUSTOM_ANISOTROPY_PASS_INCLUDED
#define CUSTOM_ANISOTROPY_PASS_INCLUDED

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
    float3 positionWS  : TEXCOORD2;
    float3 normalWS    : TEXCOORD3;
    float4 tangentWS   : TEXCOORD4;
    float3 bitangentWS : TEXCOORD5;
    LIGHTMAP_UV_VARYINGS
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings AnisotropyPassVertex(Attributes input)
{
    Varyings output;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_LIGHTMAP_DATA(input, output);
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = positionInputs.positionCS;
    output.baseUV = TransformBaseUV(input.baseUV);
    output.positionWS = positionInputs.positionWS;

    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz, input.tangentOS);
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);
    output.bitangentWS = normalInputs.bitangentWS;
    
    return output;
}

float4 AnisotropyPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    half4 baseMap = GetBase(input.baseUV);
    float4 baseColor = baseMap * GetBaseColor();

    #if defined(_ALPHATEST_ON)
        clip(baseColor.a - GetCutoff());
    #endif

    Surface surface;
    surface.baseColor = baseColor.rgb;
    surface.alpha = baseColor.a;
    MaskConfig maskConfig = GetMask(input.baseUV);
    surface.metallic = maskConfig.metallic;
    surface.occlusion = maskConfig.occlusion;
    surface.position = input.positionWS;
    surface.reflectance = GetReflectance();
    surface.perceptualRoughness = maskConfig.perceptualRoughness;
    surface.roughness = PerceptualRoughnessToRoughness(surface.perceptualRoughness);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);

    AnisoConfig config = GetAnisoConfig(input.baseUV);
    
    float3 unpack_tangent = GetTangentTS(input.baseUV);
    float3 T = normalize(input.tangentWS.xyz);
    float3 B = normalize(input.bitangentWS);
    float3 N = NormalTangentToWorld(GetNormalTS(input.baseUV), input.normalWS, input.tangentWS.xyz, input.tangentWS.w);
    T = normalize(unpack_tangent.x * T + unpack_tangent.y * B * config.anisoStrength + unpack_tangent.z * input.normalWS * config.anisoStrength);
    B = normalize(cross(N, T));
    // Bent normal
    float3 AnisotropicDir = config.anisotropy >= 0.0f ? B : T;
    float3 AnisotropicT = cross(AnisotropicDir, surface.viewDirection); 
    float3 AnisotropicN = cross(AnisotropicT, AnisotropicDir);
    N = normalize(lerp(N, AnisotropicN, config.anisotropy)); 
    surface.normal = N;
    surface.tangent = T;
    surface.bitangent = B;
    
    CustomBRDFData brdf;
    InitializeBRDFDataAniso(surface, brdf, config);

    float3 luminance = GetLighting(LIGHTMAP_UV_FRAGMENT_DATA, surface, brdf, 1);

    // clamping brightness to 100 to avoid undesirable oversize blooming effect
    return float4(clamp(luminance, 0.0, 100.0), 1.0);
}

#endif