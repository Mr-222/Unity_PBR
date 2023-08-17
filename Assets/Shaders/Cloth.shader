Shader "CustomPBR/Cloth"
{
    Properties
    {
        [MainTexture] _BaseMap ("Albedo(RGB)", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
    	
    	[Space(20)]
    	[Toggle(_USE_LUMINANCE)] _UseLuminanceToggle ("Use base color's luminance as sheen color", Float) = 0
    	_SheenColorMap ("Sheen Color Map", 2D) = "white"{}
    	_SheenColor ("Sheen Color", Color) = (0.04, 0.04, 0.04)
    	
    	[Space(20)]
        [Toggle(_CLOTH_SSS)] _ClothSubsurfaceScatteringToggle ("Subsurface Scattering", Float) = 0
    	_SubsurfaceColorMap ("Subsurface Color Map", 2D) = "white"{}
        _SubsurfaceColor ("Subsurface Color", Color) = (0.824, 0.824, 0.824)
        
    	[Space(20)]
    	[NoScaleOffset] _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
    	
        [Space(20)]
		[Toggle(_NORMALMAP)] _NormalMapToggle ("Use Normal Map", Float) = 0
		[NoScaleOffset][Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
		_NormalScale ("Normal Scale", Float) = 1
    	
        [Space(20)]
    	[Toggle(_DETAIL_NORMALMAP)] _DetailNormalMapToggle ("Use Detail Map", Float) = 0
	    [NoScaleOffset][Normal] _DetailNormalMap ("Detail Normal Map", 2D) = "bump" {}
    	_DetailNormalScale ("Detail Normal Scale", Float) = 1
        
        [Space(20)]
    	[Toggle(_HEIGHTMAP)] _HeightMapToggle ("Use Parallax Mapping", Float) = 0
    	[NoScaleOffset] _HeightMap ("Height Map", 2D) = "bump" {}
    	_HeightScale ("Height Scale", Range(0, 0.5)) = 1
        
    	[Space(20)]
    	[Toggle(_DISPLACEMENTMAP)] _DisplacementMapToggle ("Use Displacement Map", Float) = 0
    	_TessellationEdgeLength ("Tessellation Edge Length", Range(1, 100)) = 50
    	[NoScaleOffset] _DisplacementMap ("Displacement Map", 2D) = "black" {}
    	_DisplacementScale ("Displacement Scale", Range(0, 1)) = 0.1
        
		[Space(20)]
		[Toggle(_OCCLUSIONMAP)] _OcclusionToggle ("Use Occlusion Map", Float) = 0
		[NoScaleOffset] _OcclusionMap ("Occlusion(R)", 2D) = "white" {}
		_OcclusionStrength ("Occlusion Strength", Range(0.0, 1.0)) = 1.0

		[Space(20)]
		[Toggle(_EMISSION)] _Emission ("Emission", Float) = 0
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
		[NoScaleOffset]_EmissionMap ("Emission Map", 2D) = "black" {}
        
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle ("Alpha Clipping", Float) = 0 
        _Cutoff ("Alpha Cutoff", Float) = 0.5
        
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
        [Enum(Off, 0, On ,1)] _ZWrite("Z Write", Float) = 1 
    }
    SubShader
    {
	    HLSLINCLUDE
	    #define _SHADING_MODEL_CLOTH
	    
        #include "../ShaderLibrary/UnityInput.hlsl"
	    #include "../ShaderLibrary/Surface.hlsl"
	    #include "../ShaderLibrary/Config.hlsl"
        #include "ClothInput.hlsl"
	    #include "../ShaderLibrary/Common.hlsl"
	    #include "../ShaderLibrary/BRDF.hlsl"
	    #include "ClothInit.hlsl"
	    #include "../ShaderLibrary/GI.hlsl"
	    #include "../ShaderLibrary/Shadows.hlsl"
	    #include "../ShaderLibrary/Lighting.hlsl"
        ENDHLSL
        
        Tags 
        {
	        "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        
        Pass
        {
            Name "Cloth"
            Tags { "LightMode"="UniversalForward" }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            
            HLSLPROGRAM
            #pragma target 4.6
            #pragma shader_feature _CLOTH_SSS
            #pragma shader_feature _USE_LUMINANCE
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _DETAIL_NORMALMAP
            #pragma shader_feature _HEIGHTMAP
            #pragma shader_feature _DISPLACEMENTMAP
            #pragma shader_feature _OCCLUSIONMAP
            #pragma shader_feature _EMISSION
            #pragma shader_feature _ALPHATEST_ON
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK 
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _LIGHTS_PER_OBJECT
            #pragma multi_compile_instancing

            #ifdef _DISPLACEMENTMAP
				#define _TESSELLATION 1
            #else
				#undef _TESSELLATION
            #endif

            #pragma vertex MyTessellationVertexProgram
            #pragma hull MyHullProgram
            #pragma domain MyDomainProgram
            #pragma fragment ClothPassFragment
            
            #include "ClothPass.hlsl"
            #include "Tessellation.hlsl"
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
    		#include "MetaPassCloth.hlsl"
    		ENDHLSL
        }
    }
}
