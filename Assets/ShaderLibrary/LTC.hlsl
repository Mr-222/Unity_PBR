#ifndef CUSTOM_LTC_INCLUDED
#define CUSTOM_LTC_INCLUDED

#include "UnityInput.hlsl"

#define LUT_SIZE 64.0 // ltc_texture size
#define LUT_SCALE (LUT_SIZE - 1.0) / LUT_SIZE
#define LUT_BIAS 0.5 / LUT_SIZE

// Vector form without project to the plane (dot with the normal)
// Use for proxy sphere clipping
float3 IntegrateEdgeVec(float3 v1, float3 v2)
{
    // Using built-in acos() function will result flaws
    // Using fitting result for calculating acos()
    float x = dot(v1, v2);
    float y = abs(x);

    float a = 0.8543985 + (0.4965155 + 0.0145206*y)*y;
    float b = 3.4175940 + (4.1616724 + y)*y;
    float v = a / b;

    float theta_sintheta = x > 0.0 ? v : 0.5* rsqrt(max(1.0 - x*x, 1e-7)) - v;

    return cross(v1, v2)*theta_sintheta;
}

float4 SamplePrefilteredTex(int index, bool spec, float2 uv, float lod)
{
    // branch hell
    UNITY_BRANCH
    if (spec)
    {
        UNITY_BRANCH
        if (index == 0)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular0, sampler_trilinear_clamp, uv, lod);
        else if (index == 1)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular1, sampler_trilinear_clamp, uv, lod);
        else if (index == 2)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular2, sampler_trilinear_clamp, uv, lod);
        else if (index == 3)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular3, sampler_trilinear_clamp, uv, lod);
        else if (index == 4)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular4, sampler_trilinear_clamp, uv, lod);
        else if (index == 5)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular5, sampler_trilinear_clamp, uv, lod);
        else if (index == 6)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular6, sampler_trilinear_clamp, uv, lod);
        else if (index == 7)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular7, sampler_trilinear_clamp, uv, lod);
        else if (index == 8)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular8, sampler_trilinear_clamp, uv, lod);
        else if (index == 9)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular9, sampler_trilinear_clamp, uv, lod);
        else if (index == 10)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular10, sampler_trilinear_clamp, uv, lod);
        else if (index == 11)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular11, sampler_trilinear_clamp, uv, lod);
        else if (index == 12)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular12, sampler_trilinear_clamp, uv, lod);
        else if (index == 13)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular13, sampler_trilinear_clamp, uv, lod);
        else if (index == 14)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular14, sampler_trilinear_clamp, uv, lod);
        else
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredSpecular15, sampler_trilinear_clamp, uv, lod);
    }
    else
    {
        UNITY_BRANCH
        if (index == 0)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse0, sampler_trilinear_clamp, uv, lod);
        else if (index == 1)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse1, sampler_trilinear_clamp, uv, lod);
        else if (index == 2)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse2, sampler_trilinear_clamp, uv, lod);
        else if (index == 3)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse3, sampler_trilinear_clamp, uv, lod);
        else if (index == 4)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse4, sampler_trilinear_clamp, uv, lod);
        else if (index == 5)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse5, sampler_trilinear_clamp, uv, lod);
        else if (index == 6)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse6, sampler_trilinear_clamp, uv, lod);
        else if (index == 7)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse7, sampler_trilinear_clamp, uv, lod);
        else if (index == 8)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse8, sampler_trilinear_clamp, uv, lod);
        else if (index == 9)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse9, sampler_trilinear_clamp, uv, lod);
        else if (index == 10)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse10, sampler_trilinear_clamp, uv, lod);
        else if (index == 11)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse11, sampler_trilinear_clamp, uv, lod);
        else if (index == 12)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse12, sampler_trilinear_clamp, uv, lod);
        else if (index == 13)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse13, sampler_trilinear_clamp, uv, lod);
        else if (index == 14)
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse14, sampler_trilinear_clamp, uv, lod);
        else
            return SAMPLE_TEXTURE2D_LOD(_PrefilteredDiffuse15, sampler_trilinear_clamp, uv, lod);
    }
}

// See https://github.com/Hypnos-Render-Pipeline/HRP/blob/c948d5d20b7d02bad5aa15978e6500a370daa419/Lighting/Runtime/Resources/Shaders/Includes/LTCLight.hlsl#L4
float3 FetchFilteredTexture(float3 p1, float3 p2, float3 p3, float3 p4, float3 dir, bool spec, int lightIndex)
{
    // area light plane basis
    float3 V1 = p2 - p1;
    float3 V2 = p4 - p1;
    float3 planeOrtho = cross(V1, V2);
    float planeAreaSquared = dot(planeOrtho, planeOrtho);

    float4 plane = float4(planeOrtho, -dot(planeOrtho, p1));
    float planeDist;
    RayPlaneIntersect(dir, 0, plane, planeDist);

    float3 P = planeDist * dir - p1;

    // find tex coords of P
    float dot_V1_V2 = dot(V1, V2);
    float inv_dot_V1_V1 = 1.0 / dot(V1, V1);
    float3 V2_ = V2 - V1 * dot_V1_V2 * inv_dot_V1_V1;
    float2 Puv;
    Puv.y = dot(V2_, P) / dot(V2_, V2_);
    Puv.x = dot(V1, P) * inv_dot_V1_V1 - dot_V1_V2 * inv_dot_V1_V1 * Puv.y;

    // LOD
    float d = abs(planeDist) / pow(planeAreaSquared, 0.25);
	
    float lod = log(2048.0 * d) / log(3.0);
    lod = min(lod, 7.0);

    return SamplePrefilteredTex(lightIndex, spec, Puv, lod).rgb;
}

float3 LTC_Evaluate(float3 N, float3 V, float3 P, float3x3 Minv, float4 points[4], float twoSided, bool spec, int lightIndex)
{
    // Construct orthonormal basis around N
    float3 T1, T2;
    T1 = normalize(V - N * dot(V, N));
    T2 = normalize(cross(N, T1));

    // Convert vectors to local space
    Minv = mul(Minv, transpose(float3x3(
        T1.x, T2.x, N.x,
        T1.y, T2.y, N.y,
        T1.z, T2.z, N.z
    )));

    // Polygon (allocate 4 vertices for clipping)
    float3 L[4];
    L[0] = mul(Minv, points[0].xyz - P);
    L[1] = mul(Minv, points[1].xyz - P);
    L[2] = mul(Minv, points[2].xyz - P);
    L[3] = mul(Minv, points[3].xyz - P);

    // Check if the light is facing forward the polygon
    float3 dir = points[0].xyz - P;
    float3 lightNormal = cross(points[1].xyz - points[0].xyz, points[2].xyz - points[1].xyz);
    bool face = dot(dir, lightNormal) < 0.0;

    float3 originalL[4];
    originalL[0] = L[0];
    originalL[1] = L[1];
    originalL[2] = L[2];
    originalL[3] = L[3];
    
    // Cos weighted space
    L[0] = normalize(L[0]);
    L[1] = normalize(L[1]);
    L[2] = normalize(L[2]);
    L[3] = normalize(L[3]);

    // Integrate
    float3 vsum = float3(0.0, 0.0, 0.0);
    vsum += IntegrateEdgeVec(L[0], L[1]);
    vsum += IntegrateEdgeVec(L[1], L[2]);
    vsum += IntegrateEdgeVec(L[2], L[3]);
    vsum += IntegrateEdgeVec(L[3], L[0]);

    // Clipping
    // Form factor of the polygon in direction vsum
    float len = length(vsum);
    float z = vsum.z / len;
    if (face)
    {
        z = -z;
    }

    float2 uv = float2(z * .5f + .5f, len);
    uv = uv * LUT_SCALE + LUT_BIAS;
    // I did not manually flip the texture, flip it here
    uv.y = 1.0 - uv.y;

    // Fetch the form factor for horizon clipping
    float scale = SAMPLE_TEXTURE2D(_LTC2, sampler_LTC2, uv).w;
    float3 sum = len * scale;
    if (face && !twoSided)
        sum = 0.0;
    
    // Use F direction for texture fetch
    sum *= FetchFilteredTexture(originalL[0], originalL[1], originalL[2], originalL[3], normalize(vsum), spec, lightIndex);

    return sum;
}

#endif 