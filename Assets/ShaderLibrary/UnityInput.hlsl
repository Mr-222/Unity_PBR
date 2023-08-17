#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

float4 unity_ProbeVolumeParams;
float4x4 unity_ProbeVolumeWorldToObject;
float4 unity_ProbeVolumeSizeInv;
float4 unity_ProbeVolumeMin;

// TAA
float4x4 _UnjitteredInvVP;
float4x4 _PrevUnjitteredVP;

// Tessellation
float _TessellationEdgeLength;

// LTC
TEXTURE2D(_LTC1);
SAMPLER(sampler_LTC1);
TEXTURE2D(_LTC2);
SAMPLER(sampler_LTC2);

int _AreaLightNum;
int _AreaLightIndex;
TEXTURE2D(_LightTexture);
SAMPLER(sampler_LightTexture);

SAMPLER(sampler_trilinear_clamp);
TEXTURE2D(_PrefilteredDiffuse0);
TEXTURE2D(_PrefilteredDiffuse1);
TEXTURE2D(_PrefilteredDiffuse2);
TEXTURE2D(_PrefilteredDiffuse3);
TEXTURE2D(_PrefilteredDiffuse4);
TEXTURE2D(_PrefilteredDiffuse5);
TEXTURE2D(_PrefilteredDiffuse6);
TEXTURE2D(_PrefilteredDiffuse7);
TEXTURE2D(_PrefilteredDiffuse8);
TEXTURE2D(_PrefilteredDiffuse9);
TEXTURE2D(_PrefilteredDiffuse10);
TEXTURE2D(_PrefilteredDiffuse11);
TEXTURE2D(_PrefilteredDiffuse12);
TEXTURE2D(_PrefilteredDiffuse13);
TEXTURE2D(_PrefilteredDiffuse14);
TEXTURE2D(_PrefilteredDiffuse15);
TEXTURE2D(_PrefilteredSpecular0);
TEXTURE2D(_PrefilteredSpecular1);
TEXTURE2D(_PrefilteredSpecular2);
TEXTURE2D(_PrefilteredSpecular3);
TEXTURE2D(_PrefilteredSpecular4);
TEXTURE2D(_PrefilteredSpecular5);
TEXTURE2D(_PrefilteredSpecular6);
TEXTURE2D(_PrefilteredSpecular7);
TEXTURE2D(_PrefilteredSpecular8);
TEXTURE2D(_PrefilteredSpecular9);
TEXTURE2D(_PrefilteredSpecular10);
TEXTURE2D(_PrefilteredSpecular11);
TEXTURE2D(_PrefilteredSpecular12);
TEXTURE2D(_PrefilteredSpecular13);
TEXTURE2D(_PrefilteredSpecular14);
TEXTURE2D(_PrefilteredSpecular15);

float4 _AreaLightColor[16];
float _AreaLightIntensity[16];
float _DoubleSided[16];
float4 _AreaLightVertexPositions[64];

#endif