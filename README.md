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

# How to create a custom shader with planar reflections

You can create your own custom shaders with Shader Graph using planar reflections as the source of indirect specular global illumination contribution (instead of using the reflection probes). This can be used to create custom shaders for water, grounds with procedural elements, etc. 

It's very easy to create a new shader using planar reflections:

* Create a new shader graph
* In the Graph Inspector in the Universal properties the first one is Material which you have to change for Planar reflection
* You can add custom parameters for the 3 extra planar reflection parameters (NormalReflectionDistortion, ReflectionMultiplier, and ReflectionPower) or assign values however you want (just as with any other parameter for the shader such as the Metallic, Smoothness or Normal).

![ShaderCreation](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/ShaderGraphPlanarRefl.png)

# Limitations

* You can only have one PlanarReflections object per scene. This means you can only have planar reflections for 1 plane. This means you can't have a mirror and a reflective ground, for instance. 
* Obviously, this only works on planar surfaces (or something akin to it like big masses of water). You can't use this (reliably) to show reflections on arbitrary objects (such as characters, contraptions, terrains, etc.)
* Terrains in general can't use this technique but, since the plane the reflections are calculated with doesn't have to be static (it move and rotate freely), you could theoretically adapt it to the current terrain and as long as it doesn't change too abruptly, it could be used (ie in a racing game). Still probably other techinques like Screen Space Reflections may be better suited.

# Performance

The performance of this technique depends a lot on the complexity of the scene. Still, there are some obvious points that can help improve performance:

* Changing the resolution of the reflection texture has a big impact (half or quarter resolution textures may be good enough in most cases and improve performance by **a lot**).
* If shadows are not changing the look of the scene a lot you may want to disable shadow rendering.
* Of course, removing layers that you don't want to reflect also reduce the amount of stuff rendered.
* The blurring is very important for a good appearance for rough surfaces, but if you have mostly clear surfaces you may want to disable it to save the time it takes to create all the blurred textures.
* The limit value option shouldn't have a huge impact on performance but is passing a fullscreen shader on the render target, so disabling it when not necessary is a good idea.

# To do

* Implement a lightweight blurring option for the shader using the mipmaps of the original reflection texture.
* Add an option to select the number of blurred sub targets (this should come with extra info to allow blurring with more or less steps these subtargets).
* Haven't tested the technique in different platforms (mobile, WebGL, consoles,...) so it may need tweaking or changes to work there.

# Samples

The sample images here have been taken from *Empire in Decay*. It's a game developed by Siesta Games and should release sometime in Q1 or Q2 2026. If you find this project useful we ask you to take a look at the game:

(https://store.steampowered.com/app/3345260/Empire_in_Decay/)

If you like what you see we kindly ask you to wishlist the game, play the demo, and/or purchase the game (at the time of writing this that's not an option).

![Sewers01](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Sewers01.jpg)

![Sewers02](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Sewers02.jpg)

![Docks01](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Docks01.jpg)

![Docks02](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Docks02.jpg)

![Docks03](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Docks03.jpg)

![Cathedral01](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Cathedral01.jpg)

![Cathedral02](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Cathedral02.jpg)

![Throneroom02](https://github.com/Siesta-Games/ReadmeImages/blob/main/URP-PlanarReflections/Throneroom02.jpg)

# Attributions

This package has been developed by Eduardo Jimenez, CEO and Technical Director at Siesta Games. If you use this package in your game (or project) crediting me would be much appreciated. I also would love to hear from you and the project where this package has been used. You can contact me at: contact@siesta-games.com

![SiestaGamesLogo](https://github.com/Siesta-Games/ReadmeImages/blob/main/Logo1024.png)