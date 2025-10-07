using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;


namespace SiestaGames.PlanarReflections
{

	[CustomEditor(typeof(PlanarReflections))]
	public class PlanarReflectionsEditor : Editor
	{
		#region Attributes

		private bool showPlanarReflTex = true;
        private bool showBlurredReflTex = true;
		private int selectedBlurredTex = 0;

		#endregion

		#region Properties
		#endregion

		#region Editor Methods

		// Renders the inspector for this object. Allows us to modify or add custom controls
		public override void OnInspectorGUI()
		{
			PlanarReflections planarRefl = target as PlanarReflections;
			if (planarRefl == null)
				return;

			// Show the default inspector
			base.OnInspectorGUI();

			EditorGUILayout.Separator();

			// show the reflection render texture if possible
			RenderTexture rt = planarRefl.ReflectionTexture;
			if (rt != null)
			{
				showPlanarReflTex = EditorGUILayout.BeginFoldoutHeaderGroup(showPlanarReflTex, "Reflection Texture");
				if (showPlanarReflTex)
				{
                    // allow selecting the object
                    Rect reflTexObjRect = EditorGUILayout.GetControlRect();
                    EditorGUI.ObjectField(reflTexObjRect, "Reflection Tex", rt, typeof(RenderTexture), false);
                    GUILayout.Space(5.0f);

                    // get the rect to show the texture
                    int width = Mathf.Min(400, rt.width);
					int height = (rt.height * width) / rt.width;
					Rect rect = GUILayoutUtility.GetRect(width, height);

					// show it
					float aspect = (float)width / (float)height;
					EditorGUI.DrawTextureTransparent(rect, rt, ScaleMode.ScaleToFit, aspect);
                }
                EditorGUILayout.EndFoldoutHeaderGroup();
			}

			// show the reflection render texture if possible
			var blurRTs = planarRefl.ReflectionTexsBlur;
            if (blurRTs != null && blurRTs.Count > 0)
            {
                showBlurredReflTex = EditorGUILayout.BeginFoldoutHeaderGroup(showBlurredReflTex, "Blurred Reflection Textures");
                if (showBlurredReflTex)
                {
					selectedBlurredTex = EditorGUILayout.IntSlider("Blurred Tex Index", selectedBlurredTex, 0, blurRTs.Count - 1);
					selectedBlurredTex = Mathf.Clamp(selectedBlurredTex, 0, blurRTs.Count - 1);
					RenderTexture blurRT = blurRTs[selectedBlurredTex];

                    // allow selecting the object
                    Rect reflTexObjRect = EditorGUILayout.GetControlRect();
                    EditorGUI.ObjectField(reflTexObjRect, "Reflection Tex", blurRT, typeof(RenderTexture), false);
                    GUILayout.Space(5.0f);

                    // get the rect to show the texture
                    int width = Mathf.Min(400, blurRT.width);
                    int height = (blurRT.height * width) / blurRT.width;
                    Rect rect = GUILayoutUtility.GetRect(width, height);

                    // show it
                    float aspect = (float)width / (float)height;
                    EditorGUI.DrawTextureTransparent(rect, blurRT, ScaleMode.ScaleToFit, aspect);

                }
                EditorGUILayout.EndFoldoutHeaderGroup();
            }
        }

        #endregion

        #region Methods
        #endregion
    }

}
