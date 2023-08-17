Shader "Hidden/TAA"
{
    Properties
    {
        [MainTexture] _MainTex("MainTex", 2D) = "white" {}
    }

    SubShader
    {
        Cull Off 
        ZWrite Off 
        ZTest Always
        Tags 
        {
            "RenderPipeline"="UniversalRenderPipeline"
        }
        
        HLSLINCLUDE
        #include "../ShaderLibrary/UnityInput.hlsl"
        #include "../ShaderLibrary/Common.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_PrevTex);
        SAMPLER(sampler_PrevTex);
        SAMPLER(sampler_PointClamp);
        float4 _CameraDepthTexture_TexelSize;
        float4x4 _InvCameraProjection;
        float4x4 _FrameMatrix;
        float _Blend;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float3 viewVec      : TEXCOORD1;
                float4 positionCS  : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
            
                float3 ndcPos = float3(input.uv * 2.0 - 1.0, 1); 
                float far = _ProjectionParams.z; // Z : FarPlane
                float3 clipVec = float3(ndcPos.x, ndcPos.y, ndcPos.z * -1.0) * far; // Clip space far plane
                output.viewVec = mul(_InvCameraProjection, clipVec.xyzz).xyz; // Convert to View Space
                
                return output;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(input.uv);
                #else
                    // Adjust z to match NDC for OpenGL
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(input.uv));
                #endif
                
                float3 viewPos = input.viewVec * Linear01Depth(depth, _ZBufferParams);  // Reconstruct view space position
            
                // Reprojection
                viewPos.z = -viewPos.z; // _FrameMatrix comes from C# side, it consumes a right-hand coordinate, so we have to inverse Z.
                float4 positionClip = mul(_FrameMatrix, float4(viewPos, 1.0));
                float4 screenPos = ComputeScreenPos(positionClip);
                float2 uv = screenPos.xy / screenPos.w;
                uv.y = 1.0 - uv.y;
                
                float4 currentColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float4 prevColor;
                  if (abs(uv.x) > 1 || abs(uv.y) > 1)
                      prevColor = currentColor;
                  else
                      prevColor = SAMPLE_TEXTURE2D(_PrevTex, sampler_PrevTex, uv);

                currentColor.xyz = RGBToYCoCg(ToneMap(currentColor.rgb));
                prevColor.xyz = RGBToYCoCg(ToneMap(prevColor.rgb));
            
                float3 AABBMin, AABBMax;
                AABBMax = AABBMin = (currentColor.xyz);
            
                for (int x = -1; x <= 1; ++x) 
                {
                    for (int y = -1; y <= 1; ++y) 
                    {
                        float2 duv = float2(x, y) / _ScreenParams.xy;
                        float3 C = RGBToYCoCg(ToneMap(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + duv).xyz));
                        AABBMin = min(AABBMin, C);
                        AABBMax = max(AABBMax, C);
                    }
                }
                prevColor.rgb = ToneUnmap(YCoCgToRGB(ClipAABB(prevColor.xyz, AABBMin, AABBMax)));
                currentColor.rgb = ToneUnmap(YCoCgToRGB(currentColor.xyz));
          
                float4 final = float4(lerp(prevColor, currentColor, _Blend).rgb, 1.0);

                //final = SAMPLE_TEXTURE2D_LOD(_PrefilteredLightTexture, sampler_PrefilteredLightTexture, input.uv, 0.0);
                
                return final;
            }
            ENDHLSL
        }
    }    
}