Shader "CustomPBR/Anisotropy"
{
    Properties
    {
	    [Space(20)]	
    	[MainTexture] _BaseMap ("Albedo(RGB)", 2D) = "white" { }
	    [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
    	
    	[Space(20)]
        [NoScaleOffset] _MaskMap ("R(metallic) G(occlusion) B(detail normal mask) A(smoothness)", 2D) = "white" { }
        
    	_Reflectance ("Reflectance", Range(0.0, 1.0)) = 0.5
    	
    	[Space(20)]
    	[Toggle(_NORMALMAP)] _NormalMapToggle ("Use Normal Map", Float) = 0
        [NoScaleOffset][Normal] _NormalMap ("Normal Map", 2D) = "Bump" { }
        [NoScaleOffset][Normal] _TangentMap ("Tangent Map", 2D) = "Bump" { }
        _NormalScale ("Normal Scale", Range(0.001, 1)) = 1

    	[Space(20)]
        [NoScaleOffset] _AnisoLevelMap ("Anisotropy Level", 2D) = "white" { } 
        _AnisotropyStrength ("Anisotropy Strength", Range(0, 1)) = 1
    	
    	[Space(20)]
	    [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Clipping", Float) = 0 
        _Cutoff ("Alpha Cutoff", Float) = 0.5
        
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
        [Enum(Off, 0, On ,1)] _ZWrite("Z Write", Float) = 1 
    }
    SubShader
    {
	    HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/UnityInput.hlsl"
	    #include "../ShaderLibrary/Surface.hlsl"
	    #include "../ShaderLibrary/Config.hlsl"
        #include "AnisotropyInput.hlsl"
	    #include "../ShaderLibrary/BRDF.hlsl"
	    #include "../ShaderLibrary/GI.hlsl"
	    #include "../ShaderLibrary/Shadows.hlsl"
	    #include "../ShaderLibrary/Lighting.hlsl"
        ENDHLSL
        
        Tags 
        {
            "RenderPipeline"="UniversalPipeline"
        }
        
        Pass
        {
            Name "Anisotropy"
            Tags 
        	{
        		"RenderType"="Opaque" 
            	"LightMode"="UniversalForward" 
            }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma shader_feature _ANISOTROPY
            #pragma shader_feature _NORMALMAP
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK 
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _LIGHTS_PER_OBJECT
            #pragma multi_compile_instancing
            #pragma vertex AnisotropyPassVertex
            #pragma fragment AnisotropyPassFragment
            #include "AnisotropyInit.hlsl"
            #include "AnisotropyPass.hlsl"
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
           ENDHLSL
        }
    	
	    Pass 
    	{
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ColorMask 0
			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment
			
			#pragma shader_feature _ALPHATEST_ON

			#pragma multi_compile_instancing
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "DepthOnlyPass.hlsl"
			ENDHLSL
		}
    	
    	Pass 
    	{
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormals" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment
			
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			
			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "DepthNormalsPass.hlsl"

			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
			/*
			#pragma vertex DisplacedDepthOnlyVertex (instead of DepthOnlyVertex above)

			Varyings DisplacedDepthOnlyVertex(Attributes input) {
				Varyings output = (Varyings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				// Example Displacement
				input.positionOS += float4(0, _SinTime.y, 0, 0);

				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
				output.positionCS = TransformObjectToHClip(input.position.xyz);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
				output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
				return output;
			}
			*/
			
			ENDHLSL
		}
    	
    	Pass
    	{
    		Name "Meta"
    		Tags { "LightMode"="Meta" }
    		
    		Cull Off
    		
            HLSLPROGRAM
    		#pragma vertex MetaPassVertex
    		#pragma fragment MetaPassFragment
    		#include "LitInit.hlsl"
    		#include "MetaPass.hlsl"
    		ENDHLSL
        }
    	
    }
}
