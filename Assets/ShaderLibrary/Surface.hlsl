#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface
{
    float3 position;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    float3 viewDirection;
    float3 baseColor;
    float3 emission;
    float alpha;
    float metallic;
    float perceptualRoughness;
    float roughness;
    float occlusion;
    float reflectance;
    #ifdef _CLEARCOAT
        float clearCoat;
        float clearCoatPerceptualRoughness;
        float clearCoatRoughness;
    #endif
    float3 sheenColor;
    float3 subsurfaceColor;
};

#endif