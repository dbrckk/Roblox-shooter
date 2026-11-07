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

## Android touch control acceptance — 5 November 2026

The new `TouchLayout` operates on the actual safe-area GUI frame size, not hardcoded screen offsets. Run the experience on (at minimum) 568×320, 800×360, 915×412, and one high-DPI large phone/tablet. Verify all five weapons, FIRE hold/release, ADS toggle, RUN, SLIDE, RELOAD, and default Roblox jump + thumbstick remain independently touchable. Rotate the device; confirm no buttons overlap or escape the safe area. Enter RESULTS while holding FIRE; no further shots should be sent. Open Settings while holding FIRE; release auto-fire and hide tactical buttons. During LIVE the rank is compact, killfeed displays two items left of the touch controls, and the duplicate TOP 3 panel is hidden. On landscape devices shorter than 390px the location label is hidden so it does not overlap the thumbstick. Desktop TOP 3 and desktop killfeed remain unchanged.

## Dynamic industrial gantries — 5 November 2026

All four corner cranes have locally animated trolleys, suspended cables, load spreaders and an amber safety beacon. Geometry is *server-created but purely decorative*: `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. The shared `GantryMotion` is deterministic and limited to ±5.6 studs of trolley travel and ±0.7 studs of lift. The client updates 15 Hz on touch devices, 24 Hz on desktop. Motion is disabled in ECO and culled beyond 185 studs in BALANCED / 285 studs in HIGH. Tiny point lights exist **only locally** for HIGH-quality clients within 150 studs, so the server pays no animation/network cost.

**Verify in Studio/Android:** compare scene motion under ECO/BAL/HIGH; check frame pacing near all four cranes and from catwalks, correct crane/pulley/cable motion, restore to rest when out of range, and ensure tracer/damage/nav rays cross the invisible decorative parts as before. A successful Rojo build does not validate physics or the resulting composition visually.


## Confirmed damage VFX / shotgun pellets — 7 November 2026

After **actual server-authoritative damage**, only the attacker's client receives a short 3D impact glint at the confirmed contact point, differing for ordinary hits, headshots and eliminations. The shotgun sends up to three other *world surface only* contacts in the existing tracer event; ECO draws one tiny extra pellet flash, balanced mobile two, and quality up to three. No character impact coordinate goes to other clients through the pellet event. The shooter's immediate central tracer remains predicted and is not duplicated by the server's visual confirmation.

**Studio/Android acceptance:** shoot at concrete, metal, and wood from close/medium range in ECO, BAL, and HIGH; verify no hit confirmations on protected players or behind cover; compare headshots and eliminations; verify no floating glint around moving fighters; record performance with four bots shooting concurrently.


## Short-range combat clarity and elimination feedback — 7 November 2026

At point-blank range the tracer is a small moving segment occupying 36% of its path rather than a static full-distance laser. Confirmed hit glints below 7 studs use smaller geometry and one spark. Real fatal confirmations can supersede body-hit glints fired earlier in the same shotgun volley. The center marker no longer displays a giant K: a temporary ELIMINATED / HEADSHOT ELIMINATION subtitle appears below the aiming point. Ordinary hit feedback cannot clear it prematurely.

Live verification: shoot at 2–5 studs, repeat multi-target shotgun kills, check ECO/BAL/HIGH at 568×320 and 915×412, ensure medal/killfeed do not overlap, and measure mobile frame time with four bots. Effects remain local and non-queryable.
