#ifndef __PLANARREFLCOMMON_HLSL__
#define __PLANARREFLCOMMON_HLSL__

SAMPLER(sampler_ScreenTextures_linear_clamp);
TEXTURE2D(_PlanarReflectionTexture);
TEXTURE2D(_PlanarReflectionTexture1);
TEXTURE2D(_PlanarReflectionTexture2);
TEXTURE2D(_PlanarReflectionTexture3);
TEXTURE2D(_PlanarReflectionTexture4);
TEXTURE2D(_PlanarReflectionTexture5);

struct PlanarReflInfo
{
    float2 screenUV;
    half3 normalTS;
    float minReflection;
    float normalDistortion;
    float reflectionMultiplier;
    float reflectionPower;
};


void InitializePlanarReflData(InputData inputData, SurfaceDescription surfaceDescription, out PlanarReflInfo planarReflInfo)
{
    float4 positionCS = TransformWorldToHClip(inputData.positionWS);
    float2 normPosCS = positionCS.xy / positionCS.w;
    normPosCS.y = -normPosCS.y;
    planarReflInfo.screenUV = 0.5 * (normPosCS + float2(1, 1));
    
#if _NORMAL_DROPOFF_TS
    planarReflInfo.normalTS = TransformTangentToWorld(surfaceDescription.NormalTS, inputData.tangentToWorld);
#else
    planarReflInfo.normalTS = half3(0, 0, 1);
#endif

    planarReflInfo.minReflection = surfaceDescription.MinPlanarReflection;
    planarReflInfo.normalDistortion = surfaceDescription.NormalReflectionDistortion;
    planarReflInfo.reflectionMultiplier = surfaceDescription.ReflectionMultiplier;
    planarReflInfo.reflectionPower = surfaceDescription.ReflectionPower;
}

void CalculateRoughnessFactor(float roughnessNorm, float threshold, out float progressA, out float progressB)
{
    float a = 6.0 * roughnessNorm - threshold;
    float b = a - 1.0;
    float a0 = saturate(1000.0 * a);
    float b0 = saturate(1000.0 * b);
    float multiplier = a0 - b0;
    
    progressA = multiplier * a;
    progressB = multiplier * (1.0 - a);
}

half3 SampleReflections(half3 normalTS, half2 screenUV, half2 normalDistortion, half roughness)
{
    half3 reflection = 0;

    float2 reflectionUV = screenUV + normalTS.xz * normalDistortion;
    float progress5A, progress5B;
    float progress4A, progress4B;
    float progress3A, progress3B;
    float progress2A, progress2B;
    float progress1A, progress1B;
    float progress0A, progress0B;
    
    CalculateRoughnessFactor(roughness, 5.0, progress5A, progress5B);
    CalculateRoughnessFactor(roughness, 4.0, progress4A, progress4B);
    CalculateRoughnessFactor(roughness, 3.0, progress3A, progress3B);
    CalculateRoughnessFactor(roughness, 2.0, progress2A, progress2B);
    CalculateRoughnessFactor(roughness, 1.0, progress1A, progress1B);
    CalculateRoughnessFactor(roughness, 0.0, progress0A, progress0B);
    
    float progress5 = progress5A;
    float progress4 = progress4A + progress5B;
    float progress3 = progress3A + progress4B;
    float progress2 = progress2A + progress3B;
    float progress1 = progress1A + progress2B;
    float progress0 = progress0A + progress0B + progress1B;
    
    reflection += progress5 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture5, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;
    reflection += progress4 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture4, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;
    reflection += progress3 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture3, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;
    reflection += progress2 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture2, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;
    reflection += progress1 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture1, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;
    reflection += progress0 * SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_ScreenTextures_linear_clamp, reflectionUV).rgb;

    return reflection;
}

half3 GlossyEnvironmentPlanarReflection(half3 normalTS, half2 screenUV, half2 normalDistortion, half roughness, float reflMultiplier, float reflPower)
{
    half3 reflCol = SampleReflections(normalTS, screenUV, normalDistortion, roughness);
    
    reflCol = pow(abs(reflCol), reflPower) * reflMultiplier;
    
    return reflCol;
}

half3 PlanarReflGlobalIllumination(BRDFData brdfData, BRDFData brdfDataClearCoat, float clearCoatMask,
                                   half3 bakedGI, half occlusion, float3 positionWS,
                                   half3 normalWS, half3 viewDirectionWS, //float2 normalizedScreenSpaceUV,
                                   PlanarReflInfo planarReflInfo)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

    half3 indirectDiffuse = bakedGI;
    half3 indirectSpecular = GlossyEnvironmentPlanarReflection(planarReflInfo.normalTS, planarReflInfo.screenUV, planarReflInfo.normalDistortion.xx, 
                                                               brdfData.perceptualRoughness, planarReflInfo.reflectionMultiplier, planarReflInfo.reflectionPower);
    //half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h, normalizedScreenSpaceUV);

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    if (IsOnlyAOLightingFeatureEnabled())
    {
        color = half3(1, 1, 1); // "Base white" for AO debug lighting mode
    }
    
#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfDataClearCoat.perceptualRoughness, 1.0h, normalizedScreenSpaceUV);
    // TODO: "grazing term" causes problems on full roughness
    half3 coatColor = EnvironmentBRDFClearCoat(brdfDataClearCoat, clearCoatMask, coatIndirectSpecular, fresnelTerm);

    // Blend with base layer using khronos glTF recommended way using NoV
    // Smooth surface & "ambiguous" lighting
    // NOTE: fresnelTerm (above) is pow4 instead of pow5, but should be ok as blend weight.
    half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * fresnelTerm;
    return (color * (1.0 - coatFresnel * clearCoatMask) + coatColor) * occlusion;
#else
    return color * occlusion;
#endif
    
}

half3 PlanarReflGlobalIllumination(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, PlanarReflInfo planarReflInfo)
{
    const BRDFData noClearCoat = (BRDFData) 0;
    return PlanarReflGlobalIllumination(brdfData, noClearCoat, 0.0, bakedGI, occlusion, positionWS, normalWS, viewDirectionWS, planarReflInfo);
}

#endif // __PLANARREFLCOMMON_HLSL__