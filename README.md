# Requirements

Unity 6000.0, 6000.1, or 6000.2 along with its corresponding URP version.

# Features

* Allows adding materials that use planar reflections.
* Allows creating custom shaders in Shader Graph.
* Define the plane to be used for planar reflections
* Works in forward, deferred, forward+, and deferred+ paths.
* High quality blurring to support different levels of smoothness, seamlessly interpolated.

![Throneroom01](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Throneroom01.jpg)

# Installation

The recommended way to install the package is through the package manager in Unity (UPM).
Before installing, make sure that URP is installed and correctly set up in your project.
Then you can proceed to install this package:

1. Inside Unity, go to "Window"-> "Package Manager".
2. Once the window is opened, go to the "+" symbol at the top left corner, and select "Install package from git URL". See the image below.

![Install](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/UPM1.jpg)

3. Write the following URL: https://github.com/Siesta-Games/URP-PlanarReflections.git and click install.

# How to Add Planar Reflections to a Scene

1. Add a game object to your scene and add the PlanarReflections component to it.
2. Make sure the local Z direction of the object you just created is the normal of the plane you want to use for reflections
3. Also ensure the object is at the right position for the reflections (ie if the plane is horizontal to reflect the ground the object should be at ground level)
4. Create a new material that uses the Planar Reflections/BasePlanarReflections shader, configure it and assign it to the objects where you want planar reflections

The PlanarReflections component has various parameters that allow you to configure how planar reflections are rendered:

* The Settings configure the actual rendering of the camera that's used for planar reflections (the resolution of the RenderTexture where the camera is rendered with respect to the main camera, the clip plane offset for near objects, the layers to render and whether to render with shadows or not)
* URP Cam Renderer Index is useful to ensure the reflections camera is rendered before any other camera that may use its results (that shows objects with planar reflections)
* Plane Offset is basically a small bias used to lift the reflection plane
* Dual Kawase Blur shader is the shader used for the blurring. It's set automatically and you shouldn't change it unless you want to modify the blurring (and color limit)
* Blur Final RT determines whether to generate a set of textures blurred for the different levels of roughness of materials
* Blur Offset is the offset parameter used in the Dual-Kawase blur. By default is 1 and having higher values will make blur more intense but at the expense of some quality
* Limit Value is used to limit the maximum value colors may have in the rendered reflection texture. It's usually a good idea to have it marked to avoid flickering due to highlights
* Max Color Value is the maximum value the RGB components of the reflection texture may have. Usually values between 5 and 100 are reasonable. It depends on how you deal with HDR

On the shader there are some parameters that help configure how you see planar reflection materials. They are all at the end of the material:

![MaterialParameters](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/ShaderParameters.png)

* NormalReflectionDistortion: this is how much to move the reflection uv position based on the normal of the object at the point we're rendering. Usually values under 0.1 are ok (0.01 or 0.02 are usually fine)
* ReflectionMultiplier: the calculated reflection color is multiplied by this value. Thus if you want to make reflections more or less powerful you can change this value accordingly.
* ReflectionPower: the calculated reflection color is powered to this value. This means that if you use high values only colors that not close to 1 (in R, G or B) will be attenuated. Usually leaving it at 1 is a good idea but at some points you may want to play with it to exagerate some reflections while keeping others muted.

