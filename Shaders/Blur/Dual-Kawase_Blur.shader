Shader "Blur/Dual-Kawase Blur"
{   
	Properties
	{
        _Offset("Offset", Range(0.0, 1.0)) = 1.0
        _MaxValue("Max (Color) Value", Float) = 5.0
	}

    SubShader
    {
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        uniform float _Offset;
        uniform float _MaxValue;

        struct BlurAttributes
        {
			float4 positionOS   : POSITION;
            float2 uv           : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct BlurVaryings
        {
            float4 positionCS   : SV_POSITION;
            float2 uv           : TEXCOORD0;
            UNITY_VERTEX_OUTPUT_STEREO
        };


        float2 GetBlitTexelSize()
        {
            return _BlitTexture_TexelSize.xy;
        }

        BlurVaryings BlurVert(BlurAttributes input)
        {
            BlurVaryings output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
            output.positionCS = vertexInput.positionCS;
            output.uv = input.uv;

            return output;
        }

        ENDHLSL

        Tags { "RenderType"="Opaque" "RenderTexture"="True" }
        LOD 100
        Pass        // Pass 0: down sample
        {
            Name "Dual-Kawase Blur Down"
            ZWrite Off Cull Off
            Fog { Mode off }

            HLSLPROGRAM
            
            #pragma vertex BlurVert
            #pragma fragment FragDown

            float4 FragDown (BlurVaryings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.uv;

                // calculate the offset to apply to the UVs
                float2 halfPixel = 0.5 * GetBlitTexelSize();
                float2 o = halfPixel * _Offset;

                // sample the center with 4x weight
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv) * 4.0;

                // sample the 4 diagonal corners
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-o.x, -o.y));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( o.x, -o.y));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-o.x,  o.y));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( o.x,  o.y));

                // normalize
                color *= (1.0 / 8.0);

                return color;
            }
            
            ENDHLSL
        }

        Pass        // Pass 1: up sample
        {
            Name "Dual-Kawase Blur Up"
            ZWrite Off Cull Off
            Fog { Mode off }

            HLSLPROGRAM
            
            #pragma vertex BlurVert
            #pragma fragment FragUp

            float4 FragUp (BlurVaryings input) : SV_Target
            {
                float2 uv = input.uv;

                // calculate the offset to apply to the UVs
                float2 halfPixel = 0.5 * GetBlitTexelSize();
                float2 o = halfPixel * _Offset;

                // we'll return a float4 color that we reset to 0
                float4 color = float4(0.0, 0.0, 0.0, 0.0);

                // sample 4 edge centers with weight 1x each
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-2.0 * o.x, 0.0));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( 2.0 * o.x, 0.0));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(0.0, -2.0 * o.y));
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(0.0,  2.0 * o.y));

                // sample the 4 diagonal corners with weight 2x each
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-o.x, -o.y)) * 2.0;
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( o.x, -o.y)) * 2.0;
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-o.x,  o.y)) * 2.0;
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( o.x,  o.y)) * 2.0;

                // normalize
                color *= (1.0 / 12.0);

                return color;
            }
            
            ENDHLSL
        }

        Pass        //< Pass 2: Simple pass to limit the value of pixels
        {
            Name "Limit Color Values"
            ZWrite Off Cull Off
            Fog { Mode off }

            HLSLPROGRAM
            
            #pragma vertex BlurVert
            #pragma fragment FragLimitValue

            float4 FragLimitValue (BlurVaryings input) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.uv);

                color.r = clamp(color.r, 0.0, _MaxValue);
                color.g = clamp(color.g, 0.0, _MaxValue);
                color.b = clamp(color.b, 0.0, _MaxValue);

                return color;
            }
            
            ENDHLSL
        }
    }
}
