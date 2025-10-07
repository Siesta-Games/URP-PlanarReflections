namespace UnityEditor.ShaderGraph
{

	internal static class PlanarReflBlockFields
	{
        [GenerateBlocks]
        public struct SurfaceDescription
        {
            public static string name = "SurfaceDescription";
            public static BlockFieldDescriptor MinPlanarReflection = new BlockFieldDescriptor(SurfaceDescription.name, "MinPlanarReflection", "SURFACEDESCRIPTION_MINPLANARREFLECTION",
                new FloatControl(0.0f), ShaderStage.Fragment);
            public static BlockFieldDescriptor NormalReflectionDistortion = new BlockFieldDescriptor(SurfaceDescription.name, "NormalReflectionDistortion", "SURFACEDESCRIPTION_NORMALREFLECTIONDISTORTION",
                new FloatControl(0.0f), ShaderStage.Fragment);
            public static BlockFieldDescriptor ReflectionMultiplier = new BlockFieldDescriptor(SurfaceDescription.name, "ReflectionMultiplier", "SURFACEDESCRIPTION_REFLECTIONMULTIPLIER",
                new FloatControl(1.0f), ShaderStage.Fragment);
            public static BlockFieldDescriptor ReflectionPower = new BlockFieldDescriptor(SurfaceDescription.name, "ReflectionPower", "SURFACEDESCRIPTION_REFLECTIONPOWER",
                new FloatControl(1.0f), ShaderStage.Fragment);
        }

    }

}
