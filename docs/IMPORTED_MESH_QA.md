# NEON STRIKE — imported mesh QA

**Important:** generated FBX/GLB assets are not automatically installed in Roblox.
The imported model path is enabled only when `ServerStorage/VanguardTemplates`
contains all seven correctly named MeshParts per color.

## Geometry validation
- Confirm every mesh pivot and size against its corresponding R6 body part.
- Verify rifle forward axis and muzzle attachment visually.
- Confirm normal, roughness and metallic maps in SurfaceAppearance.
- Confirm all cosmetics remain non-colliding and non-queryable.
- Confirm Humanoid head and torso raycasts still register.
- Confirm bot movement, animations and round scoring in Studio and Android.

## Build status
GitHub Actions validates source compilation and Rojo serialization, not rendering,
asset publishing, animation runtime or device frame rate. Do not infer AAA readiness.
