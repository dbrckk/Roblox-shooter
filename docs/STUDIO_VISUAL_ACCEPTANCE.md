# Studio visual acceptance checklist — VANGUARD

The 3D/PBR asset forge exports original assets; a successful export does **not** mean the game uses imported meshes yet.

## Runtime acceptance
- In Studio, import all seven pieces for each palette into `ServerStorage/VanguardTemplates/<palette>` with the exact names in `docs/VANGUARD_ASSETS.md`.
- Inspect that each imported piece is a `MeshPart`, UV/material maps are aligned, and `SurfaceAppearance` references real uploaded Roblox asset IDs.
- Start one client and confirm that the bots display their imported meshes rather than the procedural fallback.
- Confirm that no mesh affects player movement or projectile hit detection; verify the actual Humanoid hitbox and headshots.
- Verify muzzle flash/tracer alignment, weapon rotation, arm swing, head movement, death and respawn.
- Test on Android with graphics quality at minimum and maximum, with four bots visible simultaneously.
- Capture performance stats and compare before/after import. Do not mark AAA complete without these checks.

## Source provenance
REA was used for architecture analysis of an MIT-licensed FPS, not for copying proprietary RIVALS assets. Original assets are authored in Blender through the project AssetForge workflow.

## Graphics budget selector (29 October 2026)

The in-game Settings panel includes **GRAPHICS: ECO / BAL / HIGH**. BAL is the default on touch devices, HIGH on desktop. The menu uses a viewport-responsive scale. A local player attribute (`IronYardGraphicsPreset`) drives bot cosmetic distance and world decoration LOD, plus the maximum distance, count and rate of transient impact chips. Neither combat hitboxes nor authoritative damage can be changed by this client setting.

Check settings and LOD in both portrait-width and landscape mobile viewports; transition across the 12-16 stud hysteresis region in every preset; ensure all core silhouettes always remain visible; check mobile frame pacing and that the menu is fully accessible. Build success alone does not guarantee runtime fidelity.

## Additional live gameplay acceptance — October 2026

- Inspect warehouse roof trusses, wall shutter facades, 2 catwalk rail systems and 4 overhead gantry spreaders. No architectural decoration may stop a bullet, alter pathfinding or give an invulnerable cover exploit.
- From a catwalk, check the visual rail positions against actual collision and ensure the player can distinguish decorative rails from physical barriers.
- Verify the entire support glove (wrist/knuckles/sleeve) follows the rifle and sniper reloading hand. Check pistol slide, shotgun pump and sniper bolt movements during repeated fire.
- Verify human elimination awards and headshots are server-authored, do not trigger during RESULTS, reset streaks on death/new round and keep **session-only** XP on round transitions. They do not survive quitting.
- Test the medal overlay against Top 3, kill feed, scoreboard, mobile fire and reload controls at phone viewports. Record FPS and frametime on representative Android devices.
