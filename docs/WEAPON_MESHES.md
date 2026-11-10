# IRON YARD - original weapon mesh forge

Purpose: create real imported 3D geometry, not another cosmetic Roblox Part
collection. The first two weapons are the original Pistol and Knife.
They are modeled and exported with free Blender on GitHub Actions.

Workflow: https://github.com/dbrckk/Roblox-shooter/actions/workflows/weaponforge.yml

The job bakes original 512px ColorMap, NormalMap, RoughnessMap and MetalnessMap,
creates two genuine GLB mesh LODs per weapon, and preserves a Blender source.

- iron_yard_pistol_LOD0.glb: pistol frame and independently movable slide
- iron_yard_pistol_LOD1.glb: reduced gun geometry for mobile
- iron_yard_knife_LOD0.glb: ground blade, scaled handle and pins
- iron_yard_knife_LOD1.glb: reduced knife detail for mobile
- weapons_source.blend: editable original Blender source

The pistol GLBs contain two separate mesh nodes: IRONYARD_Pistol_Static and
IRONYARD_Pistol_Slide. The knife uses IRONYARD_Knife_Static. The structural
validator reads the actual GLB binary and verifies triangles, UVs and
embedded PBR textures instead of trusting filenames or extension alone.

IMPORTANT: No asset ID is created and no game is published by this forge.
The live FPS retains its functional procedural viewmodel until the owner
imports the meshes in Studio and confirms scale, pivots, animations and
Android rendering. A GitHub release is an asset source pack, NOT a Roblox
experience release.
