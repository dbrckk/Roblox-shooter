# NEON STRIKE — asset production and quality gate

## Implemented as actual in-game Roblox instances
- `src/server/BotVisuals.luau`: original segmented combat armor with 4 colorways and cosmetic rifle, welded to R6 Humanoid hitboxes. Fine cosmetic parts use `CanQuery=false` and `CanCollide=false`, preventing them from interfering with hit detection or navmesh.
- `src/server/BotAnimation.luau`: procedural 6-joint R6 combat gait, aim pose, head tracking, idle breathing and server-tracked recoil.
- `src/server/ArenaArt.luau`: industrial wall ribs, neon conduits, reactor pillars, floor markings, in-world branding and color-grade lighting.
- `src/client/BotLOD.client.luau`: distance-based local hiding of **visual-only** detail; core silhouette remains present at range. Android hides cosmetic details sooner than PC.
- `src/client/WeaponVisuals.luau`: bot muzzle flare and colored tracers; server is the authority for hits.
- No imported third-party art, non-free assets or asset IDs.

## Real PBR replacement path (not claimed finished)
The current Roblox Parts are tangible 3D geometry **not** textured skinned meshes. Premium results still require creating/importing authored meshes and PBR textures, using e.g. Blender or provenance-checked CC0/CC-BY assets. Candidate third-party asset sources in `star-list` require license checks per asset.

1. Author Blender rigged combatant at consistent R6 humanoid dimensions, with original geometry.
2. Separate UV maps for armor, helmet, fabric and rifle. Bake/alignment-check **ColorMap**, **NormalMap**, **RoughnessMap**, **MetalnessMap**; generate LOD levels.
3. Export Roblox-compatible geometry; import/publish approved assets using Roblox Studio, which needs a desktop environment and asset permissions. Record asset IDs in versioned configuration once actually uploaded.
4. Swap the cosmetic attachable parts for visual `MeshPart`/`SurfaceAppearance` or rigged `SkinnedMeshPart` assets, preserving server-controlled target hitboxes and movement.
5. Validate mobile FPS, memory, network traffic, occlusion and material readability on a real Android device, at high/low quality.

## Validation criteria (still required)
- Test 1 human + 4 bots, 2 humans + 4 bots, no players and bot respawns in Roblox Studio.
- Verify 4 bot skins, headshots, projectile paths, navigation around crates, score persistence across AI respawn, rounds and winners.
- Verify LOD changes no collision/damage, visible weapon recoil, and mobile touch controls.
- Verify Android battery/thermal load and frame pacing using in-game performance statistics.
- GitHub Actions Rojo build and Luau compile are **static/build checks**, not a playtest.

## REA evidence
The architecture was informed by an actual run of REA 6.8.0 against the MIT source of Arena FPS and careful inspection of its AI/mode files. See `docs/REA_RESULTS.md`. REA did not extract proprietary RIVALS content.
