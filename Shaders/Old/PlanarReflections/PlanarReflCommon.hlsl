#ifndef PLANAR_REFL_COMMON_HLSL
#define PLANAR_REFL_COMMON_HLSL

// NOTE: [Barkley] Mostly copied from WaterLighting.hlsl in the BoatAttack project

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "CommonUtilities.hlsl"
#include "PlanarReflInputs.hlsl"
#include "PlanarReflLighting.hlsl"


// Copied from LitInput.hlsl (line 59)
half SampleOcclusion(float2 uv)
{
#ifdef _OCCLUSIONMAP
	// TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
#if defined(SHADER_API_GLES)
	return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
#else
	half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
	return LerpWhiteTo(occ, _OcclusionStrength);
#endif
#else
	return 1.0;
#endif
}



half3 CustomSampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = 1.0h)
{
	half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
	return UnpackNormalScale(n, scale);
}


void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
	inputData = (InputData)0;

	inputData.positionWS = input.positionWS;

	half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
	inputData.normalWS = TransformTangentToWorld(normalTS,
		half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));

	inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
	viewDirWS = SafeNormalize(viewDirWS);

	inputData.viewDirectionWS = viewDirWS;
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
	inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
	inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif
}

void InitializeBakedGIData(Varyings input, inout InputData inputData)
{
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
#elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(input.vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        inputData.normalWS,
        inputData.viewDirectionWS,
        input.positionCS.xy,
        input.probeOcclusion,
        inputData.shadowMask);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
#endif
}


// This method is copied and modified from InitializeStandardLitSurfData in LitInput.hlsl (line 74). It should be
// the equivalent to the surface shader somehow
void InitSurfaceData(float2 uv, float4 screenPos, out PlanarSurfaceData outSurfaceData)
{
	// no transparency surface data here
	outSurfaceData.alpha = 1.0h;

	// calculate the albedo color
	half4 defaultCol = _Color * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
	outSurfaceData.albedo = defaultCol.rgb;

	// get the metallic and smoothness from the metallic texture
	half4 metallicSmoothness = SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv);
	outSurfaceData.metallic = metallicSmoothness.r;
	outSurfaceData.smoothness = _Smoothness * metallicSmoothness.a;
	outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);

	// sample occlusion from the occlusion map
	outSurfaceData.occlusion = SampleOcclusion(uv);

	// calculate the emission color
	outSurfaceData.emission = _EmissionColor.rgb * SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb;

	// get the normal World Space and store it before 
	float4 normalPacked = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
	half3 normal = UnpackNormalScale(normalPacked, _BumpScale);
	outSurfaceData.normalTS = normal;

	// calculate the screen UVs which we may be using for the planar reflections
	outSurfaceData.screenUV = screenPos.xyz / screenPos.w;
}




// Fragment for water
/*half4 frag(WaterVertexOutput IN) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(IN);
	half3 screenUV = IN.shadowCoord.xyz / IN.shadowCoord.w;//screen UVs

	half4 waterFX = SAMPLE_TEXTURE2D(_WaterFXMap, sampler_ScreenTextures_linear_clamp, IN.preWaveSP.xy);

	// Depth
	float3 depth = WaterDepth(IN.posWS, IN.additionalData, screenUV.xy);// TODO - hardcoded shore depth UVs
	//return half4(0, frac(ceil(depth.y) / _MaxDepth), frac(IN.posWS.y), 1);
	half depthMulti = 1 / _MaxDepth;

	// Detail waves
	half2 detailBump1 = SAMPLE_TEXTURE2D(_SurfaceMap, sampler_SurfaceMap, IN.uv.zw).xy * 2 - 1;
	half2 detailBump2 = SAMPLE_TEXTURE2D(_SurfaceMap, sampler_SurfaceMap, IN.uv.xy).xy * 2 - 1;
	half2 detailBump = (detailBump1 + detailBump2 * 0.5) * saturate(depth.x * 0.25 + 0.25);

	IN.normal += half3(detailBump.x, 0, detailBump.y) * _BumpScale;
	IN.normal += half3(1 - waterFX.y, 0.5h, 1 - waterFX.z) - 0.5;
	IN.normal = normalize(IN.normal);

	// Distortion
	half2 distortion = DistortionUVs(depth.x, IN.normal);
	distortion = screenUV.xy + distortion;// * clamp(depth.x, 0, 5);
	float d = depth.x;
	depth.xz = AdjustedDepth(distortion, IN.additionalData);
	distortion = depth.x < 0 ? screenUV.xy : distortion;
	depth.x = depth.x < 0 ? d : depth.x;

	// Fresnel
	half fresnelTerm = CalculateFresnelTerm(IN.normal, IN.viewDir.xyz);
	//return fresnelTerm.xxxx;

	// Lighting
	Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.posWS));
	half shadow = SoftShadows(screenUV, IN.posWS, IN.viewDir.xyz, depth.x);
	half3 GI = SampleSH(IN.normal);

	// SSS
	half3 directLighting = dot(mainLight.direction, half3(0, 1, 0)) * mainLight.color;
	directLighting += saturate(pow(dot(IN.viewDir, -mainLight.direction) * IN.additionalData.z, 3)) * 5 * mainLight.color;
	half3 sss = directLighting * shadow + GI;

	// Foam
	half3 foamMap = SAMPLE_TEXTURE2D(_FoamMap, sampler_FoamMap,  IN.uv.zw).rgb; //r=thick, g=medium, b=light
	half depthEdge = saturate(depth.x * 20);
	half waveFoam = saturate(IN.additionalData.z - 0.75 * 0.5); // wave tips
	half depthAdd = saturate(1 - depth.x * 4) * 0.5;
	half edgeFoam = saturate((1 - min(depth.x, depth.y) * 0.5 - 0.25) + depthAdd) * depthEdge;
	half foamBlendMask = max(max(waveFoam, edgeFoam), waterFX.r * 2);
	half3 foamBlend = SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp, sampler_AbsorptionScatteringRamp, half2(foamBlendMask, 0.66)).rgb;
	half foamMask = saturate(length(foamMap * foamBlend) * 1.5 - 0.1);
	// Foam lighting
	half3 foam = foamMask.xxx * (mainLight.shadowAttenuation * mainLight.color + GI);

	BRDFData brdfData;
	half alpha = 1;
	InitializeBRDFData(half3(0, 0, 0), 0, half3(1, 1, 1), 0.95, alpha, brdfData);
	half3 spec = DirectBDRF(brdfData, IN.normal, mainLight.direction, IN.viewDir) * shadow * mainLight.color;
#ifdef _ADDITIONAL_LIGHTS
	uint pixelLightCount = GetAdditionalLightsCount();
	for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
	{
		Light light = GetAdditionalLight(lightIndex, IN.posWS);
		spec += LightingPhysicallyBased(brdfData, light, IN.normal, IN.viewDir);
		sss += light.distanceAttenuation * light.color;
	}
#endif

	sss *= Scattering(depth.x * depthMulti);

	// Reflections
	half3 reflection = SampleReflections(IN.normal, IN.viewDir.xyz, screenUV.xy, 0.0);

	// Refraction
	half3 refraction = Refraction(distortion, depth.x, depthMulti);

	// Do compositing
	half3 comp = lerp(lerp(refraction, reflection, fresnelTerm) + sss + spec, foam, foamMask); //lerp(refraction, color + reflection + foam, 1-saturate(1-depth.x * 25));

	// Fog
	float fogFactor = IN.fogFactorNoise.x;
	comp = MixFog(comp, fogFactor);
#if defined(_DEBUG_FOAM)
	return half4(foamMask.xxx, 1);
#elif defined(_DEBUG_SSS)
	return half4(sss, 1);
#elif defined(_DEBUG_REFRACTION)
	return half4(refraction, 1);
#elif defined(_DEBUG_REFLECTION)
	return half4(reflection, 1);
#elif defined(_DEBUG_NORMAL)
	return half4(IN.normal.x * 0.5 + 0.5, 0, IN.normal.z * 0.5 + 0.5, 1);
#elif defined(_DEBUG_FRESNEL)
	return half4(fresnelTerm.xxx, 1);
#elif defined(_DEBUG_WATEREFFECTS)
	return half4(waterFX);
#elif defined(_DEBUG_WATERDEPTH)
	return half4(frac(depth), 1);
#else
	return half4(comp, 1);
#endif
}*/

#endif // PLANAR_REFL_COMMON_HLSL