#ifndef CUSTOM_IBL_INCLUDED
#define CUSTOM_IBL_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"

// Calculate direction based on face and uv
float3 DirectionFromCubemapTexel(int face, float2 uv)
{
    float3 dir = 0;

    switch (face)
    {
    case 0: //+X
        dir.x = 1.0;
        dir.yz = uv.yx * -2.0 + 1.0;
        break;

    case 1: //-X
        dir.x = -1.0;
        dir.y = uv.y * -2.0f + 1.0f;
        dir.z = uv.x * 2.0f - 1.0f;
        break;

    case 2: //+Y
        dir.xz = uv * 2.0f - 1.0f;
        dir.y = 1.0f;
        break;
    case 3: //-Y
        dir.x = uv.x * 2.0f - 1.0f;
        dir.z = uv.y * -2.0f + 1.0f;
        dir.y = -1.0f;
        break;

    case 4: //+Z
        dir.x = uv.x * 2.0f - 1.0f;
        dir.y = uv.y * -2.0f + 1.0f;
        dir.z = 1;
        break;

    case 5: //-Z
        dir.xy = uv * -2.0f + 1.0f;
        dir.z = -1;
        break;
    }
    return normalize(dir);
}

float DistributionGGX(float NdotH, float perceptualRoughness)
{
    float a = perceptualRoughness * perceptualRoughness;
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = NdotH2 * (a2 - 1.0) + 1.0;
    denom = PI * denom * denom;

    return nom / denom;
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = roughness * roughness;
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

float2 hammersley(uint i, float numSamples) {
    uint bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);
    return float2(i / numSamples, bits / exp2(32));
}

float3 hemisphereUniformSample(float2 u) { // pdf = 1.0 / (2.0 * F_PI);
    const float phi = 2.0f * PI * u.x;
    const float cosTheta = 1 - u.y;
    const float sinTheta = sqrt(1 - cosTheta * cosTheta);
    return float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
}

float3 hemisphereImportanceSampleDGGX(float2 u, float a) { // pdf = D(a) * cosTheta
    const float phi = 2.0f * PI * u.x;
    // NOTE: (aa-1) == (a-1)(a+1) produces better fp accuracy
    const float cosTheta2 = (1 - u.y) / (1 + (a + 1) * ((a - 1) * u.y));
    const float cosTheta = sqrt(cosTheta2);
    const float sinTheta = sqrt(1 - cosTheta2);
    return float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
}

float3 hemisphereImportanceSampleDGGXWorldSpace(float2 Xi, float3 N, float perceptualRoughness)
{
    float a = perceptualRoughness * perceptualRoughness;
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    // Convert to spherical coordinate
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;

    // Convert from local space to world space 
    float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);

    float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

static float Visibility(float NoV, float NoL, float a) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    // Height-correlated GGX
    const float a2 = a * a;
    const float GGXL = NoV * sqrt((NoL - NoL * a2) * NoL + a2);
    const float GGXV = NoL * sqrt((NoV - NoV * a2) * NoV + a2);
    return 0.5f / (GGXV + GGXL);
}

float2 DFV(float NoV, float linearRoughness, uint numSamples) {
    float2 r = 0;
    const float3 V = float3(sqrt(1.0 - NoV * NoV), 0, NoV);
    for (uint i = 0; i < numSamples; i++) {
        const float2 u = hammersley(i, 1.0f / numSamples);
        const float3 H = hemisphereImportanceSampleDGGX(u, linearRoughness);
        const float3 L = reflect(-V, H);
        const float VoH = saturate(dot(V, H));
        const float NoL = saturate(L.z);
        const float NoH = saturate(H.z);
        if (NoL > 0) {
            /*
             * Fc = (1 - V•H)^5
             * F(h) = f0*(1 - Fc) + f90*Fc
             *
             * f0 and f90 are known at runtime, but thankfully can be factored out, allowing us
             * to split the integral in two terms and store both terms separately in a LUT.
             *
             * At runtime, we can reconstruct Er() exactly as below:
             *
             *            4                      <v•h>
             *   DFV.x = --- ∑ (1 - Fc) V(v, l) ------- <n•l>
             *            N  h                   <n•h>
             *
             *
             *            4                      <v•h>
             *   DFV.y = --- ∑ (    Fc) V(v, l) ------- <n•l>
             *            N  h                   <n•h>
             *
             *
             *   Er() = f0 * DFV.x + f90 * DFV.y
             *
             */
            const float v = V_SmithGGXCorrelated(NoV, NoL, linearRoughness) * NoL * (VoH / NoH);
            const float Fc = pow(1 - VoH, 5);
            r.x += v * (1.0f - Fc);
            r.y += v * Fc;
        }
    }
    return r * (4.0f / numSamples);
}

float2 DFV_Multiscatter(float NoV, float linearRoughness, uint numSamples) {
    float2 r = 0;
    const float3 V = float3(sqrt(1.0 - NoV * NoV), 0, NoV);
    for (uint i = 0; i < numSamples; i++) {
        const float2 u = hammersley(i, 1.0f / numSamples);
        const float3 H = hemisphereImportanceSampleDGGX(u, linearRoughness);
        const float3 L = reflect(-V, H);
        const float VoH = saturate(dot(V, H));
        const float NoL = saturate(L.z);
        const float NoH = saturate(H.z);
        if (NoL > 0) {
            /*
             * Fc = (1 - V•H)^5
             * F(h) = f0*(1 - Fc) + f90*Fc
             *
             * f0 and f90 are known at runtime, but thankfully can be factored out, allowing us
             * to split the integral in two terms and store both terms separately in a LUT.
             *
             * At runtime, we can reconstruct Er() exactly as below:
             *
             *            4                      <v•h>
             *   DFV.x = --- ∑ (1 - Fc) V(v, l) ------- <n•l>
             *            N  h                   <n•h>
             *
             *
             *            4                      <v•h>
             *   DFV.y = --- ∑ (    Fc) V(v, l) ------- <n•l>
             *            N  h                   <n•h>
             *
             *
             *   Er() = f0 * DFV.x + f90 * DFV.y
             *
             */
            const float v = V_SmithGGXCorrelated(NoV, NoL, linearRoughness) * NoL * (VoH / NoH);
            const float Fc = pow(1 - VoH, 5);
            r.x += v * Fc;
            r.y += v;
        }
    }
    return r * (4.0f / numSamples);
}

static float DFV_Charlie_Uniform(float NoV, float linearRoughness, uint numSamples) {
    float r = 0.0;
    const float3 V = float3(sqrt(1.0 - NoV * NoV), 0, NoV);
    for (uint i = 0; i < numSamples; i++) {
        const float2 u = hammersley(i, 1.0f / numSamples);
        const float3 H = hemisphereUniformSample(u);
        const float3 L = 2 * dot(V, H) * H - V;
        const float VoH = saturate(dot(V, H));
        const float NoL = saturate(L.z);
        const float NoH = saturate(H.z);
        if (NoL > 0) {
            const float v = V_Ashikhmin(NoL, NoV);
            const float d = D_Charlie(NoH, linearRoughness);
            r += v * d * NoL * VoH; // VoH comes from the Jacobian, 1/(4*VoH)
        }
    }
    // uniform sampling, the PDF is 1/2pi, 4 comes from the Jacobian
    return r * (4.0f * 2.0f * (float) PI / numSamples);
}

#endif