#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

float4 _ShadowParams;
//float4 _ShadowBias; // x:Depth Bias y:Normal Bias

float3 ApplyDepthNormalBias(float3 positionWS, float3 normalWS, float3 lightDirectionWS)
{
    // // https://zhuanlan.zhihu.com/p/370951892
    // Approximate sin/tan with 1-cos
    float OneMinusNDotL = 1.0 - saturate(dot(normalWS, lightDirectionWS));
    // normal bias is negative since we want to apply an inset normal offset
    positionWS += OneMinusNDotL *  _ShadowBias.xxx * lightDirectionWS;
    positionWS += OneMinusNDotL * _ShadowBias.yyy * normalWS;
    return positionWS;
}

#endif