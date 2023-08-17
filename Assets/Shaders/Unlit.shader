Shader "CustomPBR/Unlit" 
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor][HDR] _BaseColor("Base Color", Color) = (0, 0.66, 0.73, 1)
        
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Clipping", Float) = 0 
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5 
        
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
        [Enum(Off, 0, On ,1)] _ZWrite("Z Write", Float) = 1 
    }
    
    SubShader 
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/UnityInput.hlsl"
        #include "UnlitInput.hlsl"
        #include "../ShaderLibrary/Shadows.hlsl"
        ENDHLSL
        
        Tags 
        {
            "RenderPipeline"="UniversalPipeline"
        }
        
        Pass 
        {
            Name "Unlit"
            Tags { "LightMode"="SRPDefaultUnlit" }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            
            HLSLPROGRAM
            #pragma shader_feature _ALPHATEST_ON
            #pragma multi_compile_instancing
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl"
            ENDHLSL
        }

       Pass
       {
           Name "ShadowCaster"
           Tags { "LightMode"="ShadowCaster" }
           
           ZWrite On
           ZTest LEqual
           HLSLPROGRAM
           #pragma shader_feature _ALPHATEST_ON
           //#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
           #pragma multi_compile_instancing
           // Universal Pipeline Keywords
           // (v11+) This is used during shadow map generation to differentiate between directional and punctual (point/spot) light shadows, as they use different formulas to apply Normal Bias
           #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
           #pragma vertex ShadowCasterPassVertex
           #pragma fragment ShadowCasterPassFragment
           #include "ShadowCasterPass.hlsl"
           // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
           // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
           // #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
           ENDHLSL
       }
    }    
}