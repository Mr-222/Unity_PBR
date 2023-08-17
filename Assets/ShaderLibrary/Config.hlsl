#ifndef CUSTOM_CONFIG_INCLUDED
#define CUSTOM_CONFIG_INCLUDED

struct ClearCoatConfig
{
    float strength;
    float roughness;
};

struct MaskConfig
{
    float metallic;
    float occlusion;
    float perceptualRoughness;
};

struct AnisoConfig
{
    float anisoStrength;
    float anisotropy;
};

#endif