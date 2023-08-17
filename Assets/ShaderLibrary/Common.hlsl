#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

float Square (float x) {
    return x * x;
}

float3 Square(float3 x)
{
    return x * x;
}

float DistanceSquared(float3 pA, float3 pB) {
    return dot(pA - pB, pA - pB);
}

half Alpha(half4 color, half cutoff)
{
    half alpha = color.a;

    #if defined(_ALPHATEST_ON)
    clip(alpha - cutoff);
    #endif

    return alpha;
}

float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float3 tangentWS, float flipSign)
{
    float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, flipSign);
    return TransformTangentToWorld(normalTS, tangentToWorld);
}

float3 NormalBlendUDN(float3 n1, float3 n2)
{
    float3 r = normalize(float3(n1.xy + n2.xy, n1.z));
    return r;
}

float3 NormalBlendRNM(float3 n1, float3 n2)
{
    float3 t = n1.xyz + float3(0.0, 0.0, 1.0);
    float3 u = n2.xyz * float3(-1.0, -1.0, 1.0);
    float3 r = (t / t.z) * dot(t, u) - u;
    return r;
}

#if defined(_SHADING_MODEL_CLOTH) || defined(_SHADING_MODEL_LIT)
    float2 ParallaxMapping(float2 texCoords, float3 tangentView)
    {
        const float minLayers = 8.0;
        const float maxLayers = 64.0;
        const float numLayers = lerp(maxLayers, minLayers, max(tangentView.z, 0.0));
        const float layerHeight = 1.0 / numLayers;
        float currentLayerHeight = 0.0;
        float2 p = tangentView.xy * GetHeightScale();
        const float2 deltaTexCoords = p / numLayers;
    
        float2 currentTexCoords = texCoords;
        float currentHeightMapValue = GetHeight(currentTexCoords);
    
        UNITY_UNROLLX(64)
        while (currentLayerHeight < currentHeightMapValue)
        {
            currentTexCoords += deltaTexCoords;
            currentHeightMapValue = GetHeight(currentTexCoords);
            currentLayerHeight += layerHeight;
        }
    
        float2 prevTexCoords = currentTexCoords - deltaTexCoords;
        float afterHeight = currentHeightMapValue - currentLayerHeight;
        float beforeHeight = (currentLayerHeight - layerHeight) - GetHeight(prevTexCoords);
        // Linear interpolation using height difference before and after the collision.
        float weight = afterHeight / (afterHeight + beforeHeight);
        
        return lerp(currentTexCoords, prevTexCoords, weight);
    }
#endif

float3 ToneMap(in float3 color)
{
    return color * rcp(1 + Luminance(color));
}

float3 ToneUnmap(in float3 color)
{
    return color * rcp(1 - Luminance(color));
}

// Clip point to a AABB box
float3 ClipAABB(float3 Point, float3 BoxMin, float3 BoxMax)
{
    float3 Filtered = (BoxMin + BoxMax) * 0.5f;
    float3 RayOrigin = Point;
    float3 RayDir = Filtered - Point;
    RayDir = abs(RayDir) < 1.0 / 65536.0 ? 1.0 / 65536.0 : RayDir;
    float3 InvRayDir = rcp(RayDir);
                
    float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
    float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
    float3 EnterIntersect = min(MinIntersect, MaxIntersect);
    float ClipBlend = max(EnterIntersect.x, max(EnterIntersect.y, EnterIntersect.z));
    ClipBlend = saturate(ClipBlend);
    return lerp(Point, Filtered, ClipBlend);
}

// plane : Xx + Yy + Zz + W = 0
bool RayPlaneIntersect(float3 dir, float3 origin, float4 plane, out float t)
{
    t = -dot(plane, float4(origin, 1.0)) / dot(plane.xyz, dir);
    return t > 0.0;
}

#endif