#ifndef PLANAR_REFL_INPUTS_HLSL
#define PLANAR_REFL_INPUTS_HLSL

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


// Basic attributes to receive per vertex. This is a very complete set of parameters, but it'll be useful for most shaders
struct Attributes
{
	float4 positionOS   : POSITION;
	float3 normalOS     : NORMAL;
	float4 tangentOS    : TANGENT;
	float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Fragment shader inputs. It's the same as the normal Lit shader whic should be enough for most purposes
struct Varyings
{
	float2 uv                       : TEXCOORD0;

	float3 positionWS               : TEXCOORD1;

	float4 normalWS                 : TEXCOORD2;    // xyz: normal, w: viewDir.x
	float4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: viewDir.y
	float4 bitangentWS              : TEXCOORD4;    // xyz: bitangent, w: viewDir.z

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
#else
	half fogFactor : TEXCOORD5;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	float4 shadowCoord              : TEXCOORD6;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                : TEXCOORD7;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
#endif

#ifdef USE_APV_PROBE_OCCLUSION
    float4 probeOcclusion : TEXCOORD10;
#endif

	float4 screenPos : TEXCOORD11;

	float4 positionCS               : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};



TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
TEXTURE2D(_MetallicMap);        SAMPLER(sampler_MetallicMap);
TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
TEXTURE2D(_EmissionMap);        SAMPLER(sampler_EmissionMap);
TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);

SAMPLER(sampler_ScreenTextures_linear_clamp);
TEXTURE2D(_PlanarReflectionTexture);


CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float4 _Color;
float4 _EmissionColor;
float _BumpScale;
float _OcclusionStrength;
float _Smoothness;
float _Metallic;
float _MinPlanarReflection;
CBUFFER_END


// Must match Lightweigth ShaderGraph master node
struct PlanarSurfaceData
{
	half3 albedo;
	half3 specular;
	half  metallic;
	half  smoothness;
	half3 normalTS;
	half3 emission;
	half  occlusion;
	half  alpha;
	half3 screenUV;
};


#endif	// PLANAR_REFL_INPUTS_HLSL