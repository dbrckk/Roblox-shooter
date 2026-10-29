# IRON YARD — asset production and quality gate

## Implemented as actual in-game Roblox instances
- `src/server/BotVisuals.luau`: original segmented combat armor with 4 colorways and cosmetic rifle, welded to R6 Humanoid hitboxes. Fine cosmetic parts use `CanQuery=false` and `CanCollide=false`, preventing them from interfering with hit detection or navmesh.
- `src/server/BotAnimation.luau`: procedural 6-joint R6 combat gait, aim pose, head tracking, idle breathing and server-tracked recoil.
- `src/server/ArenaArt.luau`: industrial wall ribs, neon conduits, reactor pillars, floor markings, in-world branding and color-grade lighting.
- `src/client/BotLOD.client.luau`: distance-based local hiding of **visual-only** detail; core silhouette remains present at range. Android hides cosmetic details sooner than PC.
- `src/client/WeaponVisuals.luau`: bot muzzle flare and colored tracers; server is the authority for hits.
- No imported third-party art, non-free assets or asset IDs.

## Generated PBR mesh kit (verified)

A complete [AssetForge job](https://github.com/dbrckk/Roblox-shooter/actions/runs/40733818033) generated seven rigid R6-compatible FBX components, eight GLB variants (four colorways, two geometry LOD), 32 PBR texture maps at 512×512 and a rendered contact sheet. The four LOD0 variants contain 3,636 polygons each. The source file is a packed editable Blender scene. Validation checked actual FBX headers, GLB2 headers/lengths, map sizes and presence of preview.

The `BotVisuals.luau` template adapter clones seven imported Roblox MeshParts when present in `ServerStorage/VanguardTemplates/{olive,sand,slate,rust}`; it otherwise uses procedural Part armor. Those Roblox-imported assets **have not been uploaded or runtime-tested yet**. See `docs/VANGUARD_ASSETS.md`.

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

## Improved first-person equipment (29 October 2026)

All five native procedural weapons now show reinforced tactical gloves, matte fabric sleeves, wrist straps and knuckle guards instead of bare skin-coloured rectangular hands. These components are local-only viewmodel parts; they are never used as player hitboxes or projectiles. Materials use built-in Roblox Fabric/Metal/SmoothPlastic for immediate appearance without requiring imported asset IDs; this is **not** a claim of real imported PBR texture maps. Impact fragments and spectator tracers are lightweight and controlled separately by the new graphics settings. Verify the hands/weapon overlap while aiming, sprinting, reloading and firing on a phone and in Studio.

## 1K PBR source upgrade

AssetForge now produces original 1024×1024 albedo/normal/roughness/metalness textures (32 PNG maps, eight materials). The validator decompresses and checks actual PNG payloads as well as map dimensions; rigid LOD0/LOD1 geometry stays available. This is a Blender source and export upgrade only, not a claim of Roblox-hosted material IDs or runtime Android FPS.
