using UnityEngine;


namespace SiestaGames.PlanarReflections
{

    public class BlurHelper
    {
        private static readonly int blitTextureId = Shader.PropertyToID("_BlitTexture");
        private static readonly int offsetId = Shader.PropertyToID("_Offset");

        /// <summary>
        /// Does and downsampling and upsampling using the given material that should have the Dual-Kawase Blur shader
        /// </summary>
        public static void DualKawaseBlur(RenderTexture orig, ref RenderTexture[] blurredTex, Material blurMat, float offset)
        {
            // TODO: [Barkley] Implement this with BlitMultiTap
            //Graphics.BlitMultiTap

            // Create temporary textures for all the render textures we'll use
            int numSteps = blurredTex.Length;
            RenderTexture[] subRTs = new RenderTexture[numSteps];
            RenderTextureDescriptor rtDesc = blurredTex[0].descriptor;
            int rtWidth = orig.width;
            int rtHeight = orig.height;
            for (int i = 0; i < numSteps; ++i)
            {
                rtWidth /= 2;
                rtHeight /= 2;
                rtDesc.width = rtWidth;
                rtDesc.height = rtHeight;
                subRTs[i] = RenderTexture.GetTemporary(rtDesc);
            }

            // configure the material
            blurMat.SetFloat(offsetId, offset);

            RenderTexture prevRT = orig;
            for (int i = 0; i < numSteps; ++i)
            {
                // down sample
                blurMat.SetTexture(blitTextureId, prevRT);
                Graphics.Blit(prevRT, subRTs[i], blurMat, 0);
                prevRT = subRTs[i];
            }

            for (int maxSteps = 1; maxSteps <= numSteps; ++maxSteps)
            {
                prevRT = subRTs[maxSteps - 1];
                for (int i = maxSteps - 2; i >= 0; --i)
                {
                    // up sample
                    blurMat.SetTexture(blitTextureId, prevRT);
                    Graphics.Blit(prevRT, subRTs[i], blurMat, 1);
                    prevRT = subRTs[i];
                }

                // set the final blurred texture
                blurMat.SetTexture(blitTextureId, subRTs[0]);
                Graphics.Blit(prevRT, blurredTex[maxSteps - 1], blurMat, 1);
            }

            // release the temporary render textures
            for (int i = 0; i < numSteps; ++i)
                RenderTexture.ReleaseTemporary(subRTs[i]);
            subRTs = null;
        }
    }

}
