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


## Staged NPC death poses and local dust — 7 November 2026

Bots now play a short three-stage non-ragdoll R6 defeat: impact reaction, folding fall, and final settle within 0.91 seconds. The model's overhead name/health plate is hidden at death. Before the sequence starts all body parts become non-colliding and non-queryable, and the dead root anchors in place until the existing 2.5-second despawn. Local client dust appears only after a one-time downcast finds actual nearby floor: ECO 1 puff, balanced touch 2, high touch 3, high desktop 4. Existing cosmetic and armor welds remain attached; no physics ragdolls, gameplay remotes or asset IDs are introduced.

Studio/Android acceptance: confirm all three poses render correctly on the R6 mesh/armor variants, with varying hit directions, elevated catwalks and absence of floor; verify no bullet/character collision with dead bots, that labels disappear immediately, and that old delayed pose stages do not run on new-round respawns. Test ECO/BAL/HIGH with 4 bots and record frame time before claiming production polish.


## Rooftop extractor ambience and fixture cleanup — 7 November 2026

Four slatted, non-colliding roof exhaust structures use a stable server-authored marker on each core duct. Local client software generates small pale rising vapor wisps from the nearest ducts. They are short-lived, semi-transparent, anchored, non-queryable, and never block bullets or NPC vision. The EnvironmentProfile caps the live emitter count to 0 ECO, 1 balanced mobile, 2 high mobile / balanced desktop and 4 high desktop. Each emitter has a preset-bound emission interval; no per-frame physics, replicated particles or uploaded image assets are needed. The existing local fixture list now prunes orphaned fixtures on streamed-out/rebuilt scenery.

Studio and Android acceptance: verify four physical extractors and moving vapor, a readable silhouette against bright daylight, no obstruction of targets from the roof/catwalk, correct LOD at 95/128/180 studs, switching between graphics presets during play, mobile frame time with four active bots, and absence of stale SpotLights on round changes.


## Warehouse interior material replacement & role lighting — 7 November 2026

Eight large stamped interior metal panels (four on each 72-stud warehouse wall) now have graphite uprights, pressed folds, low-opacity patina, rivets and kickplates. The existing solid walls retain all collision, bullets and wall-running; the added cladding is anchored, non-queryable, non-colliding, non-shadow-casting and Detail-tier-cullable where appropriate. The north bulkhead gains three clearly marked SEALED freight berths, never fake openings. Local ceiling SpotLights now distinguish warm warehouse task light from restrained cool catwalk light. Pure EnvironmentProfile clamps per-light strength and reach, with no lighting at ECO and fewer nearest lamps on mobile. Graphics changes retune live fixtures instead of spawning duplicates.

Studio / Android acceptance: inspect seams for clipping with main collider walls, support weld/texture variants, check wallrun/tap targets and bullet feedback against panel surfaces, ensure dock faces appear sealed, compare silhouettes and grade ECO/BAL/HIGH at noon, check performance with 4 bots and 568x320 viewport. These native Roblox materials are not a claim of imported PBR textures.


## Container side panels, casting corners and repaired asphalt — 7 November 2026

Eight MapService-matched freight container bodies gain painted side identification bands, bottom oxidation, dark ISO-inspired upper/lower corner fittings, DiamondPlate maintenance roof strips and safety markings on both doors. Twelve road-repair panels with shallow seams appear near lateral circulation routes. Everything uses original native Roblox materials; the existing collider bodies remain the only hit and player-motion surfaces. Cosmetic geometry shares the NeonStrikeDecor folder and detail-tier LOD. No external PBR asset IDs are assumed available.

Studio/Android acceptance: inspect eight box variants, verify the stripes and plates do not obscure serials, inspect roof lines from catwalks, confirm correct stopping points of bullets and navigation, and test 30/60 FPS Android in ECO/BAL/HIGH after switching preset mid-game.


## Physically grounded world texture bake & visual gate — 7 November 2026

Inspect the world source release preview.png (rows freight steel, warehouse steel, asphalt; columns ColorMap, NormalMap, RoughnessMap, MetalnessMap). Painted freight surfaces must look coated/matte rather than mirror-metallic. Scratches/chips should reveal isolated metallic substrate; warehouse sheets should read as steel, asphalt as matte aggregate. CI verifies original 1K 12-image PNG hashes, CRC, border continuity and physically distinct metallicity/roughness. After authorized Open Cloud image upload, validate actual Roblox MaterialVariants in Studio and Android for texture tiling, normal orientation, paint color and memory/performance. Do not label static-native fallback PBR.


## Pallet cargo visual variety — 8 November 2026

Five existing 9×3.7×9 physically authoritative pallet-stack colliders now own three distinguishable original visual treatments: cross-braced timber export crates, translucent shrink-wrapped sealed cargo, and olive/graphite steel cage equipment. Every stack includes a readable freight code. Source positions and orientations are computed directly from actual MapService colliders, never duplicated coordinates. Every new Part is anchored, CanCollide=false, CanTouch=false, CanQuery=false, tagged with Core/Detail and handled by existing client art LOD. No new cover, bullet blocks, remote events, game logic, external assets, paid resources or extra realtime loops. Studio/Android visual, obstacle and FPS verification is still required.


## Two distinct forklift mechanical variants — 8 November 2026

The freight/yardside forklifts now take their visual origin, paint, and fleet-marked orientation from the two actual MapService colliders rather than a second hardcoded position list. FREIGHT_LIFTER and YARD_HANDLER add original readable native metal mechanical features: anti-slip footwell, dashboards, cab guards, worklamp housings, and respectively a yellow hydraulic carriage with radiator fins, or olive counterweight with side engine louvers. All added geometry uses original native Roblox Parts, with CanCollide=false, CanQuery=false, CanTouch=false, CastShadow=false and existing Core/Detail client LOD. No new point lights, server animation, AI logic, or raycast geometry. Studio acceptance must check the still-coarse collider vs. visible front forks and cab; further gameplay cover changes need separate testing.


## Two production-metal elevated decks and ten access-step skins — 8 November 2026

Both real 64×3×52 loading-platform colliders now have six full-area native DiamondPlate deck sheets apiece, with drainage gaps aligned to the already-present grates. Side fascia, underside stiffeners, large yellow safety perimeter strips and top-face orientation labels distinguish WEST/LOADING 01 from EAST/LOADING 02. All ten original access stairs receive thin non-queryable DiamondPlate skins and yellow nosing. Visual pieces are derived directly from the real MapService collider CFrames and exact dimensions, never add physical steps or change gun hit-rules, and respect current Core/Detail Android distance culling. No external material asset IDs are required. Visually check rail/plate overlaps, metallic reflections, stair dimensions, platform readability, human/bot footsteps and frame pacing in real Roblox Studio/Android before accepting the live rendering.


## Readable cover silhouettes and authoritative whitelist — 8 November 2026

Exactly sixteen container concrete barriers, thirteen existing radial roadblocks and three warehouse/vault cover colliders may receive new facade pieces. The old prefix-only match was deliberately narrowed to actual MapService names and collider dimensions, refusing invalid/absent radial numbers and invalid sizes. Concrete gains expansion seams, metal roadblocks acquire DiamondPlate strike shields, and cargo covers receive three pressed steel shutter ribs. Sixteen strategically placed freight identity placards remain Core and readable on Android (one per freight cluster, five selected roadblocks, three central obstacles). Added surfaces are anchored, non-colliding, non-touching, non-queryable and cast no shadows; minor faces are LOD Detail and no new lights are allocated. Roblox Studio/Android acceptance must compare the true gameplay collider vs the visible armored face, confirm label orientation, mobile readability and four-bot frame pacing before calling the scene polished.


## Spatially grouped decoration LOD — 8 November 2026

The client now groups all Detail-tier Parts of the three existing decorative folders into fixed 48-stud horizontal cells. Conservative three-dimensional group bounds (with an 8-stud margin for locally animated gantry details) let the client hide/show all of a distant/near group only on its state transition; groups crossing the threshold still run precise per-part hysteresis based on squared distance. New or streamed-in parts trigger safe rebuild and reapplication. Previous ECO/BALANCED/QUALITY distances and every Core/hitbox part remain unchanged. Test in Android Studio live with four bots while moving quickly between the main warehouse, catwalks and corner gantries, switching presets while close to an LOD threshold. Monitor art pop-in, scan cadence, frame pacing and memory. No measured FPS improvement is claimed from CI alone.


## Four grounded sector markings — 8 November 2026

The exterior freight circulation lanes now feature exactly four broad paint stencils (sector 01–04) with readable east/west and north/south navigation labels. They use four thin Core parts with static top-face SurfaceGui, are permanently noncolliding, nonqueryable, non-touching and shadowless, and contain no gameplay objectives, real-time lights, new server movement or additional network traffic. Inspect from first-person camera across mobile ECO/BAL/QUALITY and desktop, check contrast and clipping at 568x320 and 915x412, and verify forklifts and containers do not obscure them. Floor stamping is not equivalent to published PBR assets.
