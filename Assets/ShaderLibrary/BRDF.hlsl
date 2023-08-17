#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

struct CustomBRDFData
{
    float3 diffuseColor;
    float3 f0;
    float perceptualRoughness;
    float roughness;
    float2 dfg;
    
    // Clear Coat Data
    float clearCoat;
    float clearCoatPerceptualRoughness;
    float clearCoatRoughness;

    // Anisotropy Data
    float at;
    float ab;

    // Cloth Data
    float3 subsurfaceColor;
};

float3 RemapDiffuseColor(float3 baseColor, float metallic)
{
    float3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
    return diffuseColor;
}

float3 RemapF0(float reflectance, float metallic, float3 baseColor)
{
    float3 f0 = 0.16 * reflectance * reflectance * (1.0 - metallic) + baseColor * metallic;
    return f0;
}

float RemapPerceptualRoughness2Roughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
}

// Suppose clear coat's IOR is 1.5
float3 F0ClearCoatToSurface(float3 f0) {
    return saturate(f0 * (f0 * (.941892f - .263008f * f0) + .346479f) - .0285998f);
}

float D_GGX_Anisotropic(float NoH, const float3 h, const float3 t, const float3 b, float at, float ab) {
    float ToH = dot(t, h);
    float BoH = dot(b, h);
    float a2 = at * ab;
    float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / (float)v2;
    return a2 * w2 * w2 * (1.0 / PI);
}

float D_Ashikhmin(float roughness, float NoH) {
    // Ashikhmin 2007, "Distribution-based BRDFs"
    float a2 = roughness * roughness;
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    float sin4h = sin2h * sin2h;
    float cot2 = -cos2h / (a2 * sin2h);
    return 1.0 / (PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = roughness * roughness;
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

float V_Kelemen(float LoH) {
    return 0.25 / (LoH * LoH + 1e-5);
}

float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV, float ToL, float BoL, float NoV, float NoL) {
    float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL);
    return saturate(v);
}

float3 F_Schlick(float VoH, float3 f0, float f90) {
    return f0 + (float3(f90, f90, f90) - f0) * pow(1.0 - VoH, 5.0);
}

float3 F_Schlick(float VoH, float3 f0) {
    float f = pow(1.0 - VoH, 5.0);
    return f + f0 * (1.0 - f);
}

float Fd_Lambert() {
    //return 1.0 / PI;
    // HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
    // BUT 1) that will make shader look significantly darker than Legacy ones
    // and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
    return 1.0;
}

float Fd_DisneyDiffuse(float NoV, float NoL, float LoH, float roughness) {
    float energyBias = lerp(0, 0.5, roughness);
    float energyFactor = lerp(1.0, 1.0 / 1.51, roughness);
    float f90 = energyBias + 2.0 * roughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter = F_Schlick(1.0, f90, NoV);
    
    return lightScatter * viewScatter * energyFactor;
}

float3 Fd_Cloth(float NoL, float roughness, float3 subsurfaceColor = 1.0)
{
    float3 fd = FabricLambertNoPI(roughness);
    #if defined(_CLOTH_SSS)
        fd *= saturate((NoL + 0.5) / 2.25);
        fd *= saturate(subsurfaceColor + NoL);
    #endif

    return fd;
}

float3 standardBRDF(float3 n, float3 l, float3 v, CustomBRDFData brdf)
{
    float3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float LoH = clamp(dot(l, h), 0.0, 1.0);

    float roughness = brdf.roughness;

    float D = D_GGX(NoH, roughness);
    float3  F = F_Schlick(NoH, brdf.f0);
    float V = V_SmithGGXCorrelated(NoV, NoL, roughness);

    // specular BRDF
    float3 Fr = D * V * F * PI;
    #if defined(_MULTISCATTERING)
        float3 energyCompensation = 1.0 + brdf.f0 * (1.0 / brdf.dfg.y - 1.0);
        // Scale the specular lobe to account for multiscattering
        Fr *= energyCompensation;
    #endif

    // diffuse BRDF
    float3 Fd = brdf.diffuseColor * Fd_DisneyDiffuse(NoV, NoL, LoH, brdf.roughness);

    return (Fd + Fr) * NoL;
}

float3 clearCoatBRDF(float3 n, float3 l, float3 v, CustomBRDFData brdf)
{
    float3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float LoH = clamp(dot(l, h), 0.0, 1.0);

    float roughness = brdf.roughness;

    float D = D_GGX(NoH, roughness);
    float3  F = F_Schlick(NoH, brdf.f0);
    float V = V_SmithGGXCorrelated(NoV, NoL, roughness);

    // specular BRDF
    float3 Fr = D * V * F * PI;
    #if defined(_MULTISCATTERING)
        float3 energyCompensation = 1.0 + brdf.f0 * (1.0 / brdf.dfg.y - 1.0);
        // Scale the specular lobe to account for multiscattering
        Fr *= energyCompensation;
    #endif

    // diffuse BRDF
    float3 Fd = brdf.diffuseColor * Fd_DisneyDiffuse(NoV, NoL, LoH, brdf.roughness);

    // clear coat BRDF
    float Dc = D_GGX(NoH, brdf.clearCoatRoughness);
    float Vc = V_Kelemen(LoH);
    float Fc = F_Schlick(0.04, LoH) * brdf.clearCoat; // clear coat strength
    float Frc = Dc * Vc * Fc * PI;

    return ((Fd + Fr * (1.0 - Fc)) * (1.0 - Fc) + Frc) * NoL;
}

float3 anisotropyBRDF(float3 n, float3 l, float3 v, float3 tangent, float3 bitangent, CustomBRDFData brdf)
{
    float3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = saturate(dot(n, l));
    float NoH = saturate(dot(n, h));
    float LoH = saturate(dot(l, h));
    float ToV = saturate(dot(tangent, v));
    float BoV = saturate(dot(bitangent, v));
    float ToL = saturate(dot(tangent, l));
    float BoL = saturate(dot(bitangent, l));

    float D = D_GGX_Anisotropic(NoH, h, tangent, bitangent, brdf.at, brdf.ab);
    float3  F = F_Schlick(NoH, brdf.f0);
    float V = V_SmithGGXCorrelated_Anisotropic(brdf.at, brdf.ab, ToV, BoV, ToL, BoL, NoV, NoL);

    // specular BRDF
    float3 Fr = D * V * F * PI;

    // diffuse BRDF
    float3 Fd = brdf.diffuseColor * Fd_DisneyDiffuse(NoV, NoL, LoH, brdf.roughness);

    return (Fd + Fr) * NoL;
}

float3 clothBRDF(float3 n, float3 l, float3 v, CustomBRDFData brdf)
{
    float3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoH = clamp(dot(n, h), 0.0, 1.0);

    float roughness = brdf.roughness;

    float D = D_Charlie(NoH, roughness);
    float3  F = brdf.f0; // f0 = sheenColor
    float V = V_Ashikhmin(NoL, NoV);

    // specular BRDF
    float3 Fr = D * V * F * PI;
    
    // diffuse BRDF
    float3 Fd = brdf.diffuseColor * Fd_Cloth(NoL, roughness, brdf.subsurfaceColor);

    #if defined(_CLOTH_SSS)
        // Note that with wrap diffuse lighting, the diffuse term must not be multiplied by N*L.
        return Fd + Fr * NoL; 
    #else
        return (Fd + Fr) * NoL;
    #endif
}

#endif