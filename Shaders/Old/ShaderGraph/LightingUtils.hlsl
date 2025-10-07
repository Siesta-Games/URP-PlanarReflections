#ifndef LIGHTING_UTILITIES_INCLUDED
#define LIGHTING_UTILITIES_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

#if (SHADERPASS != SHADERPASS_FORWARD)
    #undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
#endif

#endif



void GetShadowCoord_float(float3 positionWS, out float4 shadowCoord)
{
#ifndef SHADERGRAPH_PREVIEW
#if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float4 positionCS = TransformWorldToHClip(positionWS);
    shadowCoord = ComputeScreenPos(positionCS);
#else
    shadowCoord = TransformWorldToShadowCoord(positionWS);
#endif
#else
    // NOTE: [Barkley] This is used to avoid compilation issues in the shader graph when previewing the shader
    shadowCoord = float4(0, 0, 0, 0);
#endif
}


void GetMainLight_float(float3 positionWS, float4 shadowCoord,
                        out float3 direction, out float3 color, out float distanceAttenuation, out float shadowAttenuation, out half4 shadowMask)
{
    direction = float3(0, 0, 1);
    color = float3(0, 0, 0);
    distanceAttenuation = 0;
    shadowAttenuation = 0;
    shadowMask = half4(1, 1, 1, 1);
    
#ifndef SHADERGRAPH_PREVIEW
    
    // To ensure backward compatibility we have to avoid using shadowMask input, as it is not present in older shaders
#if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
    shadowMask = shadowMask;
#elif !defined (LIGHTMAP_ON)
    shadowMask = unity_ProbesOcclusion;
#else
    shadowMask = half4(1, 1, 1, 1);
#endif
    
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	float4 inputShadowCoord = shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
	float4 inputShadowCoord = TransformWorldToShadowCoord(positionWS);
#else
    float4 inputShadowCoord = float4(0, 0, 0, 0);
#endif
    
    Light mainLight = GetMainLight(inputShadowCoord, positionWS, shadowMask);
    
    direction = mainLight.direction;
    color = mainLight.color;
    distanceAttenuation = mainLight.distanceAttenuation;
    shadowAttenuation = mainLight.shadowAttenuation;
#endif
}



void MixRealtimeAndBakedGI_float(float3 normalWS, float3 bakedGI, float3 lightDir, float3 lightColor, float lightDistAtten, float lightShadowAtten,
                                 /*float2 lightmapUV, float3 vertexSH, */out float3 outBakedGI)
{
    outBakedGI = bakedGI;
#if !defined(SHADERGRAPH_PREVIEW)
    Light mainLight = (Light)0;
    mainLight.direction = lightDir;
    mainLight.color = lightColor;
    mainLight.distanceAttenuation = lightDistAtten;
    mainLight.shadowAttenuation = lightShadowAtten;
    mainLight.layerMask = 0xffffffff;
    
    //outBakedGI = SAMPLE_GI(lightmapUV, vertexSH, normalWS);
    
    MixRealtimeAndBakedGI(mainLight, normalWS, outBakedGI);
#endif
}

void LightingPhysicallyBased_float(float3 color, float3 positionWS, float3 normalWS, float3 viewDirectionWS,
                                   float3 lightDir, float3 lightColor, float lightDistAtten, float lightShadowAtten,
                                   float3 brdfAlbedo, float3 brdfDiffuse, float3 brdfSpecular, float brdfReflectivity, float brdfPerceptualRoughness, float brdfRoughness, float brdfGrazingTerm,
                                   out float3 outColor)
{
    outColor = color;
#if !defined(SHADERGRAPH_PREVIEW)
    
    Light mainLight;
    mainLight.direction = lightDir;
    mainLight.color = lightColor;
    mainLight.distanceAttenuation = lightDistAtten;
    mainLight.shadowAttenuation = lightShadowAtten;
    mainLight.layerMask = 0xffffffff;
    
    BRDFData brdf = (BRDFData) 0;
    brdf.albedo = brdfAlbedo;
    brdf.diffuse = brdfDiffuse;
    brdf.specular = brdfSpecular;
    brdf.reflectivity = brdfReflectivity;
    brdf.perceptualRoughness = brdfPerceptualRoughness;
    brdf.roughness = brdfRoughness;
    brdf.roughness2 = max(brdfRoughness * brdfRoughness, HALF_MIN);
    brdf.grazingTerm = brdfGrazingTerm;
    brdf.normalizationTerm = brdf.roughness * half(4.0) + half(2.0);
    brdf.roughness2MinusOne = brdf.roughness2 - half(1.0);
    
    InputData inputData = (InputData) 0;
    inputData.positionWS = positionWS;
    inputData.positionCS = TransformWorldToHClip(positionWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(inputData.positionCS);
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirectionWS;
    inputData.bakedGI = color;
    
    const BRDFData noClearCoat = (BRDFData) 0;
    
    outColor += LightingPhysicallyBased(brdf, noClearCoat,
                                        mainLight,
                                        normalWS, viewDirectionWS, 0.0, false);

#ifdef _ADDITIONAL_LIGHTS
	uint meshRenderingLayers = GetMeshRenderingLayer();
    uint pixelLightCount = GetAdditionalLightsCount();

#if USE_CLUSTER_LIGHT_LOOP
    [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            outColor += LightingPhysicallyBased(brdf, noClearCoat, light,
                                                inputData.normalWS, inputData.viewDirectionWS,
                                                0, false);
        }
    }
#endif
	
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            outColor += LightingPhysicallyBased(brdf, noClearCoat, light,
                                                inputData.normalWS, inputData.viewDirectionWS,
                                                0, false);
        }
    LIGHT_LOOP_END
#endif

#endif
}



#endif // LIGHTING_UTILITIES_INCLUDED