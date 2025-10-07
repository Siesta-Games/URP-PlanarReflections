#if ENABLE_PLANAR_REFLECTIONS_IN_SHADERGRAPH

using System;
using UnityEditor.ShaderGraph;
using UnityEngine.Rendering;


namespace UnityEditor.Rendering.Universal.ShaderGraph
{
    static class CreatePlanarReflLitShaderGraph
    {
        [MenuItem("Assets/Create/Shader Graph/URP/Planar Reflections Lit Shader Graph", priority = CoreUtils.Priorities.assetsCreateShaderMenuPriority)]
        public static void CreateLitGraph()
        {
            var target = (UniversalTarget)Activator.CreateInstance(typeof(UniversalTarget));
            target.TrySetActiveSubTarget(typeof(UniversalLitSubTarget));

            var blockDescriptors = new[]
            {
                BlockFields.VertexDescription.Position,
                BlockFields.VertexDescription.Normal,
                BlockFields.VertexDescription.Tangent,
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.NormalTS,
                BlockFields.SurfaceDescription.Metallic,
                BlockFields.SurfaceDescription.Smoothness,
                BlockFields.SurfaceDescription.Emission,
                BlockFields.SurfaceDescription.Occlusion,
                PlanarReflBlockFields.SurfaceDescription.MinPlanarReflection,
                PlanarReflBlockFields.SurfaceDescription.NormalReflectionDistortion,
                PlanarReflBlockFields.SurfaceDescription.ReflectionMultiplier,
                PlanarReflBlockFields.SurfaceDescription.ReflectionPower,
            };

            GraphUtil.CreateNewGraphWithOutputs(new[] { target }, blockDescriptors);
        }
    }
}

#endif
