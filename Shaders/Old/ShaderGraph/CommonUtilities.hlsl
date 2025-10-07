#ifndef COMMON_UTILITIES_INCLUDED
#define COMMON_UTILITIES_INCLUDED


void CalcReflectionUV_half(half3 normalWS, half3 viewDirectionWS, half2 screenUV, out half2 reflectionUV)
{
    // get the perspective projection
    float2 p11_22 = float2(unity_CameraInvProjection._11, unity_CameraInvProjection._22) * 10;
    // conver the uvs into view space by "undoing" projection
    float3 viewDir = -(float3((screenUV * 2 - 1) / p11_22, -1));

    half3 viewNormal = mul(normalWS, (float3x3) GetWorldToViewMatrix()).xyz;
    half3 reflectVector = reflect(-viewDir, viewNormal);

    reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
}

void CalcReflectionUV_float(float3 normalWS, float3 viewDirectionWS, float2 screenUV, out float2 reflectionUV)
{
    // get the perspective projection
    float2 p11_22 = float2(unity_CameraInvProjection._11, unity_CameraInvProjection._22) * 10;
    // conver the uvs into view space by "undoing" projection
    float3 viewDir = -(float3((screenUV * 2 - 1) / p11_22, -1));

    float3 viewNormal = mul(normalWS, (float3x3) GetWorldToViewMatrix()).xyz;
    float3 reflectVector = reflect(-viewDir, viewNormal);

    reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
}




void ComputeScreenPos_float(float4 pos, float projectionSign, out float4 o)
{
    o = pos * 0.5f;
    o.xy = float2(o.x, o.y * projectionSign) + o.w;
    o.zw = pos.zw;
}


// Simple noise from thebookofshaders.com
// 2D Random
float2 random(float2 st) {
    st = float2(dot(st, float2(127.1, 311.7)), dot(st, float2(269.5, 183.3)));
    return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise(float2 st) {
    float2 i = floor(st);
    float2 f = frac(st);

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(lerp(dot(random(i), f),
        dot(random(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
        lerp(dot(random(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
            dot(random(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x), u.y);
}


#endif // COMMON_UTILITIES_INCLUDED