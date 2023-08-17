Shader "Hidden/AreaLight" 
{
    SubShader 
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/UnityInput.hlsl"
        ENDHLSL
        
        Tags 
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        
        Pass 
        {
            Name "AreaLight"
            Tags { "LightMode"="UniversalForward" }
            
            Blend One Zero
            ZWrite On
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex AreaLightPassVertex
            #pragma fragment AreaLightPassFragment

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 baseUV :     TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 baseUV :     TEXCOORD0;
            };

            Varyings AreaLightPassVertex(Attributes input)
            {
                Varyings output;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = positionInputs.positionCS;
                output.baseUV = input.baseUV;

                return output;
            }

            float4 AreaLightPassFragment(Varyings input) : SV_TARGET
            {
                float3 base = SAMPLE_TEXTURE2D_LOD(_LightTexture, sampler_LightTexture, input.baseUV, 0.0).rgb;
                
                return float4(base * _AreaLightColor[_AreaLightIndex].rgb *  _AreaLightIntensity[_AreaLightIndex], 1.0);
            }
            
            ENDHLSL
        }
    }    
}