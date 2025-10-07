#ifndef PLANAR_REFL_LIGHTING_HLSL
#define PLANAR_REFL_LIGHTING_HLSL

// NOTE: [Barkley] Mostly copied from WaterLighting.hlsl in the BoatAttack project

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"


///////////////////////////////////////////////////////////////////////////////
//                           Reflection Modes                                //
///////////////////////////////////////////////////////////////////////////////

/// Returns the reflection color for the surface with the given parameters
half3 SampleReflections(half3 normalWS, half3 viewDirectionWS, half2 screenUV, half roughness)
{
    half2 reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.015);
    half3 reflection = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_ScreenTextures_linear_clamp, reflectionUV, 6 * roughness).rgb;//planar reflection

    return reflection;
}

// Computes the specular term for EnvironmentBRDF
half3 CustomEnvironmentBRDFSpecular(BRDFData brdfData, half fresnelTerm)
{
	float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
	half3 environmentBRDFSpec = surfaceReduction * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
	//environmentBRDFSpec = max(environmentBRDFSpec, half3(_MinPlanarReflection, _MinPlanarReflection, _MinPlanarReflection));
	environmentBRDFSpec += (1.0 - fresnelTerm) * half3(_MinPlanarReflection, _MinPlanarReflection, _MinPlanarReflection);
	environmentBRDFSpec = saturate(environmentBRDFSpec);

	return environmentBRDFSpec;
}

half3 CustomEnvironmentBRDF(BRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
	half3 c = indirectDiffuse * brdfData.diffuse;
	c += indirectSpecular * CustomEnvironmentBRDFSpecular(brdfData, fresnelTerm);
	return c;
}

// function that calculates the global illumination using planar reflections for the indirect specular component
half3 CustomGlobalIlluminationPlanarRefl(BRDFData brdfData, half3 bakedGI, half3 normalWS, half3 viewDirectionWS, half occlusion, half2 screenUV)
{
	half3 reflectVector = reflect(-viewDirectionWS, normalWS);
	half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

	half3 indirectDiffuse = bakedGI * occlusion;
	half3 indirectSpecular = SampleReflections(normalWS, viewDirectionWS, screenUV, brdfData.perceptualRoughness);

	return CustomEnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}

/*half3 CustomLighting(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    half NdotL = saturate(dot(normalWS, light.direction));
    half attenuation = light.shadowAttenuation * light.distanceAttenuation;
    half3 radiance = light.color * (attenuation * NdotL);

    half3 brdf = brdfData.diffuse;
#ifndef _SPECULARHIGHLIGHTS_OFF
    brdf += brdfData.specular * DirectBRDFSpecular(brdfData, normalWS, light.direction, viewDirectionWS);
#endif // _SPECULARHIGHLIGHTS_OFF

    return brdf * radiance;
}
*/
LightingData CustomCreateLightingData(half3 bakedGI, half3 emission)
{
    LightingData lightingData;

    lightingData.giColor = bakedGI;
    lightingData.emissionColor = emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

half4 UniversalFragmentPBRPlanarRefl(InputData inputData, half3 albedo, half metallic, half3 specular, half smoothness, half occlusion, half3 emission, half alpha, half2 screenUV)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

    // To ensure backward compatibility we have to avoid using shadowMask input, as it is not present in older shaders
#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
    half4 shadowMask = inputData.shadowMask;
#elif !defined (LIGHTMAP_ON)
    half4 shadowMask = unity_ProbesOcclusion;
#else
    half4 shadowMask = half4(1, 1, 1, 1);
#endif
	
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, occlusion);

    //uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
	
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));
	
    LightingData lightingData = CustomCreateLightingData(inputData.bakedGI, emission);
	
	// add the global illumination
    lightingData.giColor = CustomGlobalIlluminationPlanarRefl(brdfData, inputData.bakedGI, inputData.normalWS, inputData.viewDirectionWS, occlusion, screenUV);
	
	// now the main light
    const BRDFData noClearCoat = (BRDFData)0;
    lightingData.mainLightColor = LightingPhysicallyBased(brdfData, noClearCoat, mainLight,
														  inputData.normalWS, inputData.viewDirectionWS, 0.0, false);

#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTER_LIGHT_LOOP
    [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, noClearCoat, light,
                                                                      inputData.normalWS, inputData.viewDirectionWS,
                                                                      0, false);
    }
    #endif
	
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, noClearCoat, light,
                                                                      inputData.normalWS, inputData.viewDirectionWS,
                                                                      0, false);
    LIGHT_LOOP_END
#endif

#if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
#endif
#if REAL_IS_HALF
    // Clamp any half.inf+ to HALF_MAX
    return min(CalculateFinalColor(lightingData, alpha), HALF_MAX);
#else
    return CalculateFinalColor(lightingData, alpha);
#endif
}



///////////////////////////////////////////////////////////////////////////////
//                  Unused code from Boat Attack Shaders                     //
///////////////////////////////////////////////////////////////////////////////


/*
#define SHADOW_ITERATIONS 4

half CalculateFresnelTerm(half3 normalWS, half3 viewDirectionWS)
{
	return saturate(pow(1.0 - dot(normalWS, viewDirectionWS), 5));//fresnel TODO - find a better place
}

//diffuse
half4 VertexLightingAndFog(half3 normalWS, half3 posWS, half3 clipPos)
{
	half3 vertexLight = VertexLighting(posWS, normalWS);
	half fogFactor = ComputeFogFactor(clipPos.z);
	return half4(fogFactor, vertexLight);
}

//specular
half3 Highlights(half3 positionWS, half roughness, half3 normalWS, half3 viewDirectionWS)
{
	Light mainLight = GetMainLight();

	half roughness2 = roughness * roughness;
	half3 halfDir = SafeNormalize(mainLight.direction + viewDirectionWS);
	half NoH = saturate(dot(normalize(normalWS), halfDir));
	half LoH = saturate(dot(mainLight.direction, halfDir));
	// GGX Distribution multiplied by combined approximation of Visibility and Fresnel
	// See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
	// https://community.arm.com/events/1155
	half d = NoH * NoH * (roughness2 - 1.h) + 1.0001h;
	half LoH2 = LoH * LoH;
	half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * (roughness + 0.5h) * 4);
	// on mobiles (where half actually means something) denominator have risk of overflow
	// clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
	// sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if defined (SHADER_API_MOBILE)
	specularTerm = specularTerm - HALF_MIN;
	specularTerm = clamp(specularTerm, 0.0, 5.0); // Prevent FP16 overflow on mobiles
#endif
	return specularTerm * mainLight.color * mainLight.distanceAttenuation;
}

//Soft Shadows
half SoftShadows(float3 screenUV, float3 positionWS, half3 viewDir, half depth)
{
#if _MAIN_LIGHT_SHADOWS
	half2 jitterUV = screenUV.xy * _ScreenParams.xy * _DitherPattern_TexelSize.xy;
	half shadowAttenuation = 0;

	float loopDiv = 1.0 / SHADOW_ITERATIONS;
	half depthFrac = depth * loopDiv;
	half3 lightOffset = -viewDir * depthFrac;
	for (uint i = 0u; i < SHADOW_ITERATIONS; ++i)
	{
#ifndef _STATIC_SHADER
		jitterUV += frac(half2(_Time.x, -_Time.z));
#endif
		float3 jitterTexture = SAMPLE_TEXTURE2D(_DitherPattern, sampler_DitherPattern, jitterUV + i * _ScreenParams.xy).xyz * 2 - 1;
		half3 j = jitterTexture.xzy * depthFrac * i * 0.1;
		float3 lightJitter = (positionWS + j) + (lightOffset * (i + jitterTexture.y));
		shadowAttenuation += SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, TransformWorldToShadowCoord(lightJitter));
	}
	return BEYOND_SHADOW_FAR(TransformWorldToShadowCoord(positionWS * 1.1)) ? 1.0 : shadowAttenuation * loopDiv;
#else
	return 1;
#endif
}

// Fragment for water
half4 frag(WaterVertexOutput IN) : SV_Target
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
}
*/

#endif	// PLANAR_REFL_LIGHTING_HLSL