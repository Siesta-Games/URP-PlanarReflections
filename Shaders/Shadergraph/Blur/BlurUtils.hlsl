#ifndef BLUR_UTILITIES_INCLUDED
#define BLUR_UTILITIES_INCLUDED


void SimpleBlur_half(float2 uv, UnityTexture2D _texture, UnitySamplerState texSampler, half2 radius, out half3 color)
{
    color = SAMPLE_TEXTURE2D(_texture, texSampler, uv).rgb;
    
    float2 uvOffset = float2(-radius.x, 0.0);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(-0.7071 * radius.x, 0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.0, radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.7071 * radius.x, 0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(radius.x, 0.0);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.7071 * radius.x, -0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.0, -radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(-0.7071 * radius.x, -0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    
    color *= 1.0 / 9.0;
}

void SimpleBlur_float(float2 uv, UnityTexture2D _texture, UnitySamplerState texSampler, float2 radius, out float3 color)
{
    color = SAMPLE_TEXTURE2D(_texture, texSampler, uv).rgb;
    
    float2 uvOffset = float2(-radius.x, 0.0);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(-0.7071 * radius.x, 0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.0, radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.7071 * radius.x, 0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(radius.x, 0.0);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.7071 * radius.x, -0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(0.0, -radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    uvOffset = float2(-0.7071 * radius.x, -0.7071 * radius.y);
    color += SAMPLE_TEXTURE2D(_texture, texSampler, uv + uvOffset).rgb;
    
    color *= 1.0 / 9.0;
}


#endif // BLUR_UTILITIES_INCLUDED