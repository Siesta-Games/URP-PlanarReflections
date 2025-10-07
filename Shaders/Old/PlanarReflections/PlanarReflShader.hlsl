#ifndef PLANAR_REFL_SHADER_HLSL
#define PLANAR_REFL_SHADER_HLSL

#include "PlanarReflCommon.hlsl"


// Vertex shader for all subshaders
Varyings PlanarReflLitVert(Attributes input)
{
	Varyings output = (Varyings)0;

	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
	VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
	half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
	half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
	half fogFactor = 0;
#if !defined(_FOG_FRAGMENT)
	fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
#endif

	output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

	output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
	output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
	output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
	
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif


    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH4(vertexInput.positionWS, output.normalWS.xyz, GetWorldSpaceNormalizeViewDir(vertexInput.positionWS), output.vertexSH, output.probeOcclusion);

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif

	output.positionWS = vertexInput.positionWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	output.shadowCoord = GetShadowCoord(vertexInput);
#endif

	output.positionCS = vertexInput.positionCS;
	output.screenPos = ComputeScreenPos(vertexInput.positionCS, -1);

	return output;
}


half4 PlanarReflLitFrag(Varyings input) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

	PlanarSurfaceData surfaceData;
	InitSurfaceData(input.uv, input.screenPos, surfaceData);

	InputData inputData;
	InitializeInputData(input, surfaceData.normalTS, inputData);
    InitializeBakedGIData(input, inputData);

	half4 color = UniversalFragmentPBRPlanarRefl(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha, surfaceData.screenUV.xy);

	//color.rgb = MixFog(color.rgb, inputData.fogCoord);
	
	return color;
}


#endif // PLANAR_REFL_SHADER_HLSL