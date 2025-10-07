namespace UnityEditor.Rendering.Universal.ShaderGraph
{
    public class PlanarReflectionConstants
    {
#if USE_LOCAL_PATH_TO_PLANAR_REFLECTION_HLSL
        public const string PathToHLSL = "Assets/Plugins/URP-PlanarReflections/Editor/ShaderGraph/Includes/";
#else
        public const string PathToHLSL = "Packages/com.siestagames.urpplanarreflections/Editor/ShaderGraph/Includes/";
#endif
    }
}
