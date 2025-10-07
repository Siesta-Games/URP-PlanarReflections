using System;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Profiling;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


namespace SiestaGames.PlanarReflections
{

    /// <summary>
    /// Class to configure the rendering of planar reflections for a plane at the position of the object and with the normal of the plane its
    /// forward vector
    /// 
    /// This class is mostly copied from the one with the same name in the BoatAttack project
    /// </summary>
    [ExecuteInEditMode]
	public class PlanarReflections : MonoBehaviour
	{
        #region Typedefs

        /// <summary>
        /// Resolution multiplier to use when calculating the size of the texture for the reflection texture
        /// </summary>
        [Serializable]
        public enum ResolutionMulltiplier
        {
            Full,
            Half,
            Third,
            Quarter
        }

        /// <summary>
        /// Settings used to render the planar reflection camera
        /// </summary>
        [Serializable]
        public class PlanarReflectionSettings
        {
            public ResolutionMulltiplier resolutionMultiplier = ResolutionMulltiplier.Quarter;
            public float clipPlaneOffset = 0.07f;
            public LayerMask reflectLayers = -1;
            public bool shadows = false;
        }


        /// <summary>
        /// Data for the planar reflections
        /// </summary>
        class PlanarReflectionSettingData
        {
            private readonly bool fog;
            private readonly int maxLoD;
            private readonly float lodBias;

            public PlanarReflectionSettingData()
            {
                fog = RenderSettings.fog;
                maxLoD = QualitySettings.maximumLODLevel;
                lodBias = QualitySettings.lodBias;
            }

            public void Set()
            {
                GL.invertCulling = true;
                RenderSettings.fog = false; // disable fog for now as it's incorrect with projection
                QualitySettings.maximumLODLevel = 1;
                QualitySettings.lodBias = lodBias * 0.5f;
            }

            public void Restore()
            {
                GL.invertCulling = false;
                RenderSettings.fog = fog;
                QualitySettings.maximumLODLevel = maxLoD;
                QualitySettings.lodBias = lodBias;
            }
        }

        #endregion

        #region Public Attributes

        public const float GizmoSize = 10.0f;
        private readonly int PlanarReflectionTextureId = Shader.PropertyToID("_PlanarReflectionTexture");
        private readonly int PlanarReflectionTexture1Id = Shader.PropertyToID("_PlanarReflectionTexture1");
        private readonly int PlanarReflectionTexture2Id = Shader.PropertyToID("_PlanarReflectionTexture2");
        private readonly int PlanarReflectionTexture3Id = Shader.PropertyToID("_PlanarReflectionTexture3");
        private readonly int PlanarReflectionTexture4Id = Shader.PropertyToID("_PlanarReflectionTexture4");
        private readonly int PlanarReflectionTexture5Id = Shader.PropertyToID("_PlanarReflectionTexture5");

        public PlanarReflectionSettings settings = new PlanarReflectionSettings();

        public int urpCamRendererIndex = -1;
        public float planeOffset = 0.01f;

        public Shader dualKawaseBlurShader;
        public bool blurFinalRT = true;
        public float blurOffset = 1.0f;
        public bool limitValue = true;
        public float maxColorValue = 5.0f;

        #endregion

        #region Private Attributes

        // NOTE: [Barkley] Sometimes it's useful to see the textures in the editor
        /*[SerializeField]*/
        private RenderTexture reflectionTexture = null;
        /*[SerializeField]*/ private RenderTexture[] reflTexBlur = null;

        private static Camera reflectionCamera;
        private static bool renderingPlanarReflections = false;
        private Vector2Int oldReflectionTextureSize = new Vector2Int(0, 0);
        private Material dualKawaseBlurMat;

        #endregion

        #region Properties

        public static bool RenderingPlanarReflections { get { return renderingPlanarReflections; } }

        #endregion

        #region MonoBehaviour Methods

        private void OnEnable()
        {
            RenderPipelineManager.beginCameraRendering += OnExecutePlanarReflections;
            RenderPipelineManager.endCameraRendering += OnFinishedRenderingCamera;

            if (dualKawaseBlurShader == null)
                dualKawaseBlurShader = Shader.Find("Custom/Dual-Kawase Blur");
            dualKawaseBlurMat = new Material(dualKawaseBlurShader);
        }

        // Cleanup all the objects we possibly have created
        private void OnDisable()
        {
            Cleanup();
        }

        private void OnDestroy()
        {
            Cleanup();
            dualKawaseBlurMat = null;
        }

        private void Update()
        {
            RequestReflectionCameraRender();
        }

        private void OnDrawGizmos()
        {
            // draw a quad showing the plane of the mirror
            Gizmos.color = new Color(1.0f, 1.0f, 1.0f);
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.DrawLine(new Vector3(GizmoSize, GizmoSize, 0.0f), new Vector3(-GizmoSize, GizmoSize, 0.0f));
            Gizmos.DrawLine(new Vector3(-GizmoSize, GizmoSize, 0.0f), new Vector3(-GizmoSize, -GizmoSize, 0.0f));
            Gizmos.DrawLine(new Vector3(-GizmoSize, -GizmoSize, 0.0f), new Vector3(GizmoSize, -GizmoSize, 0.0f));
            Gizmos.DrawLine(new Vector3(GizmoSize, -GizmoSize, 0.0f), new Vector3(GizmoSize, GizmoSize, 0.0f));

            // draw an arrow showing the normal
            Gizmos.color = new Color(0.0f, 0.0f, 1.0f);
            Gizmos.DrawLine(new Vector3(0.0f, 0.0f, 0.0f), new Vector3(0.0f, 0.0f, GizmoSize));

            // restore the matrix to identity
            Gizmos.matrix = Matrix4x4.identity;
        }

        #endregion

        #region Events

        /// <summary>
        /// Event triggered when the planar reflection starts
        /// </summary>
        public static event Action<Camera> BeginPlanarReflections;

        #endregion

        #region Methods

        /// <summary>
        /// Destroys an object either using Destroy or DestroyImmediate depending on whether we're in the editor or not
        /// </summary>
        /// <param name="obj"></param>
        private static void SafeDestroy(UnityEngine.Object obj)
        {
            if (Application.isEditor)
            {
                DestroyImmediate(obj);
            }
            else
            {
                Destroy(obj);
            }
        }

        /// <summary>
        /// Clean up method 
        /// </summary>
        private void Cleanup()
        {
            RenderPipelineManager.beginCameraRendering -= OnExecutePlanarReflections;
            RenderPipelineManager.endCameraRendering -= OnFinishedRenderingCamera;

            if (reflectionCamera != null)
            {
                reflectionCamera.targetTexture = null;
                SafeDestroy(reflectionCamera.gameObject);
            }
            if (reflectionTexture != null)
            {
                //RenderTexture.ReleaseTemporary(reflectionTexture);
                reflectionTexture.DiscardContents();
                reflectionTexture.Release();
                reflectionTexture = null;
            }
            if (reflTexBlur != null)
            {
                for (int i = 0; i < reflTexBlur.Length; ++i)
                {
                    reflTexBlur[i].DiscardContents();
                    reflTexBlur[i].Release();
                    reflTexBlur[i] = null;
                }
                reflTexBlur = null;
            }
        }

        /// <summary>
        /// Requests 
        /// </summary>
        private void RequestReflectionCameraRender()
        {
            if (reflectionCamera == null)
                return;

            Profiler.BeginSample("Render Planar Reflections");

            //UpdateReflectionCamera(camera);     // create or update reflected camera
            //PlanarReflectionTexture(camera);    // create and assign RenderTexture

            var data = new PlanarReflectionSettingData(); // save quality settings and lower them for the planar reflections
            data.Set(); // set quality settings

            renderingPlanarReflections = true;
            if (BeginPlanarReflections != null)
                BeginPlanarReflections(reflectionCamera);                  // callback Action for PlanarReflection

            UniversalRenderPipeline.SingleCameraRequest requestData = new UniversalRenderPipeline.SingleCameraRequest();
            requestData.destination = reflectionTexture;
            Assert.IsTrue(UniversalRenderPipeline.SupportsRenderRequest<UniversalRenderPipeline.SingleCameraRequest>(reflectionCamera, requestData), "Error! The system doesn't support the render request of another camera?!");
            UniversalRenderPipeline.SubmitRenderRequest(reflectionCamera, requestData);

            renderingPlanarReflections = false;

            data.Restore(); // restore the quality settings
            Shader.SetGlobalTexture(PlanarReflectionTextureId, reflectionTexture);  // Assign texture to water shader

            Profiler.EndSample();
        }

        #endregion

        #region Reflection Math Methods

        /// <summary>
        /// Calculates the reflection matrix around the given plane
        /// </summary>
        /// <param name="reflectionMat"></param>
        /// <param name="plane"></param>
        private static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMat, Vector4 plane)
        {
            reflectionMat.m00 = (1.0f - 2.0f * plane[0] * plane[0]);
            reflectionMat.m01 = (-2.0f * plane[0] * plane[1]);
            reflectionMat.m02 = (-2.0f * plane[0] * plane[2]);
            reflectionMat.m03 = (-2.0f * plane[3] * plane[0]);

            reflectionMat.m10 = (-2.0f * plane[1] * plane[0]);
            reflectionMat.m11 = (1.0f - 2.0f * plane[1] * plane[1]);
            reflectionMat.m12 = (-2.0f * plane[1] * plane[2]);
            reflectionMat.m13 = (-2.0f * plane[3] * plane[1]);

            reflectionMat.m20 = (-2.0f * plane[2] * plane[0]);
            reflectionMat.m21 = (-2.0f * plane[2] * plane[1]);
            reflectionMat.m22 = (1.0f - 2.0f * plane[2] * plane[2]);
            reflectionMat.m23 = (-2.0f * plane[3] * plane[2]);

            reflectionMat.m30 = 0.0f;
            reflectionMat.m31 = 0.0f;
            reflectionMat.m32 = 0.0f;
            reflectionMat.m33 = 1.0f;
        }

        /// <summary>
        /// Given position/normal of the plane, calculates plane in camera space.
        /// </summary>
        /// <param name="cam"></param>
        /// <param name="pos"></param>
        /// <param name="normal"></param>
        /// <param name="sideSign"></param>
        /// <returns></returns>
        private Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
        {
            Vector3 offsetPos = pos + normal * settings.clipPlaneOffset;
            Matrix4x4 m = cam.worldToCameraMatrix;
            Vector3 cameraPosition = m.MultiplyPoint(offsetPos);
            Vector3 cameraNormal = m.MultiplyVector(normal).normalized * sideSign;

            return new Vector4(cameraNormal.x, cameraNormal.y, cameraNormal.z, -Vector3.Dot(cameraPosition, cameraNormal));
        }

        /// <summary>
        /// Compares the 2 vectors returning true if they have the same values
        /// </summary>
        /// <param name="a"></param>
        /// <param name="b"></param>
        /// <returns></returns>
        private static bool Int2Compare(Vector2Int a, Vector2Int b)
        {
            return (a.x == b.x) && (a.y == b.y);
        }

        #endregion

        #region Camera Methods

        /// <summary>
        /// Copies the source camera in the destination camera and updates the render shadows with the info in the settings
        /// </summary>
        /// <param name="src"></param>
        /// <param name="dest"></param>
        private void UpdateCamera(Camera src, Camera dest)
        {
            if (dest == null) 
                return;

            dest.CopyFrom(src);
            dest.useOcclusionCulling = false;
            if (dest.gameObject.TryGetComponent(out UniversalAdditionalCameraData camData))
            {
                camData.renderShadows = settings.shadows; // turn off shadows for the reflection camera
                camData.renderPostProcessing = false;
            }
        }

        /// <summary>
        /// Returns the reflected position over the plane Y = 0
        /// </summary>
        /// <param name="pos"></param>
        /// <returns></returns>
        private static Vector3 ReflectPosition(Vector3 pos)
        {
            var newPos = new Vector3(pos.x, -pos.y, pos.z);
            return newPos;
        }

        /// <summary>
        /// Updates or creates the reflection camera
        /// </summary>
        /// <param name="realCamera"></param>
        private void UpdateReflectionCamera(Camera realCamera)
        {
            if (reflectionCamera == null)
                reflectionCamera = CreatePlanarReflectionsCamera();

            // find out the reflection plane: position and normal in world space
            Vector3 pos = transform.position + Vector3.up * planeOffset;
            Vector3 normal = transform.forward;

            UpdateCamera(realCamera, reflectionCamera);

            // Render reflection
            // Reflect camera around reflection plane
            float d = -Vector3.Dot(normal, pos) - settings.clipPlaneOffset;
            Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d);

            var reflection = Matrix4x4.identity;
            reflection *= Matrix4x4.Scale(new Vector3(1, -1, 1));

            CalculateReflectionMatrix(ref reflection, reflectionPlane);
            Vector3 oldPosition = realCamera.transform.position - new Vector3(0, pos.y * 2, 0);
            Vector3 newPosition = ReflectPosition(oldPosition);
            reflectionCamera.transform.forward = Vector3.Scale(realCamera.transform.forward, new Vector3(1, -1, 1));
            reflectionCamera.worldToCameraMatrix = realCamera.worldToCameraMatrix * reflection;

            // Setup oblique projection matrix so that near plane is our reflection
            // plane. This way we clip everything below/above it for free.
            var clipPlane = CameraSpacePlane(reflectionCamera, pos - Vector3.up * 0.1f, normal, 1.0f);
            var projection = realCamera.CalculateObliqueMatrix(clipPlane);
            reflectionCamera.projectionMatrix = projection;
            reflectionCamera.cullingMask = settings.reflectLayers; // never render water layer
            reflectionCamera.transform.position = newPosition;
        }

        /// <summary>
        /// Creates the planar reflections camera object
        /// </summary>
        /// <returns></returns>
        private Camera CreatePlanarReflectionsCamera()
        {
            GameObject go = new GameObject("Planar Reflections", typeof(Camera));
            UniversalAdditionalCameraData cameraData = go.AddComponent(typeof(UniversalAdditionalCameraData)) as UniversalAdditionalCameraData;

            cameraData.requiresColorOption = CameraOverrideOption.Off;
            cameraData.requiresDepthOption = CameraOverrideOption.Off;
            if (urpCamRendererIndex >= 0)
                cameraData.SetRenderer(urpCamRendererIndex);

            Transform t = transform;
            Camera reflectionCamera = go.GetComponent<Camera>();
            reflectionCamera.transform.SetParent(t);
            reflectionCamera.transform.SetPositionAndRotation(t.position, t.rotation);
            reflectionCamera.depth = -10;
            reflectionCamera.enabled = false;
            go.hideFlags = HideFlags.HideAndDontSave;//HideFlags.DontSave;

            return reflectionCamera;
        }

        /// <summary>
        /// Returns the scale to use to the camera based on the settings
        /// </summary>
        /// <returns></returns>
        private float GetScaleValue()
        {
            switch (settings.resolutionMultiplier)
            {
                case ResolutionMulltiplier.Full:
                    return 1f;
                case ResolutionMulltiplier.Half:
                    return 0.5f;
                case ResolutionMulltiplier.Third:
                    return 0.33f;
                case ResolutionMulltiplier.Quarter:
                    return 0.25f;
                default:
                    return 0.5f; // default to half res
            }
        }

        /// <summary>
        /// Returns the resolution to use for the reflection texture
        /// </summary>
        /// <param name="cam"></param>
        /// <param name="scale"></param>
        /// <returns></returns>
        private Vector2Int ReflectionResolution(Camera cam, float scale)
        {
            int x = (int)(cam.pixelWidth * scale * GetScaleValue());
            int y = (int)(cam.pixelHeight * scale * GetScaleValue());

            return new Vector2Int(x, y);
        }

        /// <summary>
        /// Prepares the reflection texture for the planar reflections
        /// </summary>
        /// <param name="cam"></param>
        private void PlanarReflectionTexture(Camera cam)
        {
            // if the size changes release teh reflection texture
            Vector2Int res = ReflectionResolution(cam, UniversalRenderPipeline.asset.renderScale);
            if (reflectionTexture != null && (res.x != reflectionTexture.width || res.y != reflectionTexture.height))
            {
                //RenderTexture.ReleaseTemporary(reflectionTexture);
                reflectionTexture.DiscardContents();
                reflectionTexture.Release();
                reflectionTexture = null;

                for (int i = 0; i < reflTexBlur.Length; ++i)
                {
                    reflTexBlur[i].DiscardContents();
                    reflTexBlur[i].Release();
                    reflTexBlur[i] = null;
                }
                reflTexBlur = null;
            }

            if (reflectionTexture == null)
            {
                //reflectionTexture = RenderTexture.GetTemporary(res.x, res.y, 16,
                //    GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
                bool useHdr10 = RenderingUtils.SupportsRenderTextureFormat(RenderTextureFormat.RGB111110Float);
                RenderTextureFormat hdrFormat = useHdr10 ? RenderTextureFormat.RGB111110Float : RenderTextureFormat.DefaultHDR;
                reflectionTexture = new RenderTexture(res.x, res.y, 16,
                    GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
                reflectionTexture.name = "Planar Reflection RT";
                reflectionTexture.useMipMap = false;
                reflectionTexture.autoGenerateMips = false;

                reflTexBlur = new RenderTexture[5];
                for (int i = 0; i < reflTexBlur.Length; ++i)
                {
                    reflTexBlur[i] = new RenderTexture(res.x / 2, res.y / 2, 0, GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
                    reflTexBlur[i].name = $"Planar Reflection RT Blur {i + 1}";
                    reflTexBlur[i].useMipMap = false;
                    reflTexBlur[i].autoGenerateMips = false;
                }
            }
            reflectionCamera.targetTexture = reflectionTexture;
        }

        #endregion

        #region Callbacks

        /// <summary>
        /// Callback for when the rendering starts so that we can render the reflection camera before the normal rendering so that 
        /// we can use the reflection texture for the rendering of other objects
        /// </summary>
        /// <param name="context"></param>
        /// <param name="camera"></param>
        private void OnExecutePlanarReflections(ScriptableRenderContext context, Camera camera)
        {
            // we dont want to render planar reflections in reflections or previews
            if (camera.cameraType == CameraType.Reflection || camera.cameraType == CameraType.Preview || camera == reflectionCamera)
                return;

            // don't do reflections for the overlay cameras
            UniversalAdditionalCameraData camData = camera.GetComponent<UniversalAdditionalCameraData>();
            if (camData != null && camData.renderType == CameraRenderType.Overlay)
                return;

            // create or update the reflection camera to the given camera
            UpdateReflectionCamera(camera);     // create or update reflected camera
            PlanarReflectionTexture(camera);    // create and assign RenderTexture
        }

        private void OnFinishedRenderingCamera(ScriptableRenderContext context, Camera camera)
        {
            if (camera != reflectionCamera)
                return;

            if (limitValue)
            {
                Profiler.BeginSample("Limit Color Value");

                // limit the colors to a maximum value on the resulting render target
                BlurHelper.LimitColorValue(reflectionTexture, dualKawaseBlurMat, maxColorValue);

                Profiler.EndSample();
            }

            if (blurFinalRT)
            {
                Profiler.BeginSample("Reflection Blurring");

                // do the blurring for further roughness levels
                BlurHelper.DualKawaseBlur(reflectionTexture, ref reflTexBlur, dualKawaseBlurMat, 1.0f);

                // assign the blurred textures to the global shader parameters
                Shader.SetGlobalTexture(PlanarReflectionTexture1Id, reflTexBlur[0]);
                Shader.SetGlobalTexture(PlanarReflectionTexture2Id, reflTexBlur[1]);
                Shader.SetGlobalTexture(PlanarReflectionTexture3Id, reflTexBlur[2]);
                Shader.SetGlobalTexture(PlanarReflectionTexture4Id, reflTexBlur[3]);
                Shader.SetGlobalTexture(PlanarReflectionTexture5Id, reflTexBlur[4]);

                Profiler.EndSample();
            }
            else
            {
                // set the reflection texture to all levels of reflection texture
                Shader.SetGlobalTexture(PlanarReflectionTexture1Id, reflectionTexture);
                Shader.SetGlobalTexture(PlanarReflectionTexture2Id, reflectionTexture);
                Shader.SetGlobalTexture(PlanarReflectionTexture3Id, reflectionTexture);
                Shader.SetGlobalTexture(PlanarReflectionTexture4Id, reflectionTexture);
                Shader.SetGlobalTexture(PlanarReflectionTexture5Id, reflectionTexture);
            }
        }

        #endregion
    }

}
