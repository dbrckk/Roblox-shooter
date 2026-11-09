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


## Server bot navigation workload gate — 8 November 2026

With four real bots active, the server now permits at most two outstanding asynchronous PathfindingService ComputeAsync requests and staggers new starts by 0.18 s. Tokens are released by each completed callback, invalid or timed-out routes cannot replace newer goals, and hung tickets expire after 5.8 s. Existing 5 Hz bot decisions, movement collision capsule checks, ground and catwalk-edge probes, cover tactics and path-blocked listener remain authoritative. Stable Humanoid MoveTo destinations are coalesced and refreshed at most every 1.15 s; any large goal change or entry into WAIT still sends an immediate command. RaycastParams are reused within each single navigation decision.

Live Studio validation is required: test four bots pursuing crossing players, tight container corners, catwalk edges, blocked paths and successive target switching; confirm no starvation and no 'frozen in place' NPC under load. Inspect pathfinding/server frame-time and MoveTo calls, and capture mobile FPS with four bots firing. CI validates limits and integration, not real engine performance.


## Single-pass bot sighting/aim and remote bot FX budgets — 8 November 2026

The 5 Hz bot target acquisition now records the exact head/torso aim coordinate only when its own LOS ray actually intersects that enemy. Target selection returns the associated aim coordinate as a third, visibility-gated value, and the redundant second LOS sweep for the selected target is removed. Existing muzzle-to-target wall clearance and final server-authoritative randomized shot raycasts remain mandatory; hidden target memories still cannot authorize shots. Shot raycasts share their exclusion filter within the same firing attempt. Remote bot tracer/muzzle visuals are now gated by the existing local VFX distance budgets: ECO 70, mobile balanced 115, mobile quality 145, desktop balanced 160, desktop quality 195 studs. Local player prediction, gun damage, audio and server AI behavior remain unchanged. Validate head/torso behind freight, target switching, exposed cover edges, live fights with four bots, and close-range bot shots on Android. Compare real FPS and server raycast timings before claiming a measured improvement.


## Optional owner-only performance measurement — 8 November 2026

On a Roblox experience owned by a user, sign in as the actual experience creator and join on Android/PC. An unobtrusive top-left PERF button is shown only to this owner; in Roblox Studio, test participants can access it. Click once to activate per-bot server measurement and local RenderStepped FPS samples. Wait at least five seconds for the first server window, then take a screenshot with four active bots. The panel reports client frames/second and maximum frame time over the latest ~one second, per-second counts for bot targeting/navigation/tactics/firing raycasts, path computations initiated/deferred, MoveTo sends, poses and accepted bot shots, and average/peak elapsed times for bot think, pose and asynchronous ComputeAsync. Path time measures end-to-end elapsed ComputeAsync wait, **not CPU occupancy**; think/pose times are sampled function durations, not a total engine server frame time. Click CLOSE to disable profiling. Compare idle, live combat, blocked containers, catwalks and each graphics preset. Report actual numbers with screenshots. User-owned CreatorId verification and Studio-only bypass are enforced server-side; group-owned experiences need a separate explicit authorization mechanism. Neither diagnostic result nor private player position is persisted or broadcast. Ordinary public players never receive a PERF button, and the profiler remains off by default.


## Mobile HUD / touch-size accessibility — 8 November 2026

On Android, open SET at the upper-left (below the match header), choose BUTTON SIZE and cycle SMALL / MED / LARGE. Check that every weapon, fire/aim/reload/sprint/slide control remains fully inside the safe area and never collides with SET. The mission temporarily replaces the score banner at the top, and opening SET hides the briefing to keep the settings modal in front. Verify in Roblox Studio mobile emulator and an actual Android device that Roblox's native joystick/jump button do not overlap the custom cluster; the offline 36-layout test cannot prove native input geometry, notches, or thumb reach. Test a 568x320 landscape viewport, a 915x412 landscape viewport, and a narrow 320x280 edge case. Settings are session-local to the client; no DataStore or combat/network state is changed.


## Perimeter-wall visual rebuild — 9 November 2026

The four actual `BOUNDARY / east-west ±1` and `BOUNDARY / north-south ±1` collider parts now carry an independent decorative skin with seven 46-stud metal bays each. Gameplay geometry and physical surfaces remain unchanged. With ECO, BAL and HIGH selected, traverse the north, south, east and west sides and visually verify that the large steel plates, upper girders, amber plinths and 12 sector signs remain clear and do not obscure the terrain, threat silhouettes or catwalks. Check that smaller louvres and seams vanish beyond the existing LOD range on Android without hiding the primary wall silhouette.

From a spawn, shoot and wallrun along the whole perimeter, verifying that all hit detection, climbing and movement still use the original walls. Compare PERF FPS and frame times before and after on a low-end Android device with four bots active; a green Rojo build is not a GPU or memory benchmark. The previously generated 3D/PBR assets remain unactivated until official Roblox IDs are available.


## Warehouse entrance silhouette and genuine opening — 9 November 2026

The warehouse's south approach (near z=-25) now displays a major signed freight portal anchored to the existing physical east/west warehouse walls and north bulkhead. Check that the lintel and roof canopy do not suggest false bullet-proof cover, that the sign remains readable on a small Android viewport at street level, and that the three amber approach lanes point into the real open bay. Walk, slide, mantle and fire through the entrance with four bots active. Inspect from the side catwalks that the portal does not appear suspended or clipped through the pitched roof. Repeat ECO/BALANCED/QUALITY and note any shimmering on thin noncollidable floor markings. Validate client-side LOD and FPS with actual Roblox rendering; the Luau test only validates geometry policy.


## Remote combat FX flood control (9 November 2026)

With four bots constantly exchanging fire, capture Android frame-time and FPS on identical routes with ECO/BALANCED/QUALITY. Only remote tracer/flash/impact visual groups are throttled locally: ECO permits 4 BOT groups/s + a short 2-group burst, BALANCED 7 + 3, and QUALITY 11 + 4. Human remote visuals have a separate, higher bucket, and your own predicted shots and verified hit readouts are never throttled by this policy. Verify that reduced fire visuals do NOT change hit registration, bot attack rates, audio, damage, kill medals, weapon FX returned to the shooter, or proximity clarity. Compare a real Android PERF session with screenshots and real FPS/frame time before claiming performance gains.


## Persistent bullet-mark reuse — 9 November 2026

Fire a full magazine at concrete, steel, warehouse cladding, and cover; verify that surface impacts still follow the true raycast contact plane and fade smoothly for the final 1.1 seconds without disappearing instantly. Cycle ECO/BALANCED/QUALITY after sustained fire to verify correct 10/16/22 mobile and 26/36 desktop live-mark budgets. A client may keep a cache of at most 36 unparented Parts; it must not repeatedly create/destroy persistent marks or schedule a Tween/Debris cleanup for each impact. With four bots fighting, use Roblox MicroProfiler and memory statistics to measure actual object/GC reduction. Short transient sparks/confirmed hits deliberately continue to use their existing effect implementations.


## Pooled short-lived combat VFX (9 November 2026)

Under sustained rifle fire and four bots, check muzzle flashes, metal sparks, wood/concrete fragments, shotgun pellet glints, tracer travel and dust for correct shape, color and smooth fade. ECO Android may hold at most 24 transient visual Parts, BALANCED 48, QUALITY 72; PC BALANCED 80, PC QUALITY 96. Verify local muzzle flashes remain visible when incoming bot FX saturate the pool. Only desktop QUALITY enables the existing optional local point light: ensure it disables when its Part is reused for debris or after expiration. Quick-switch graphics preset during a firefight. Confirm no gameplay damage, ammo, sound, hit confirmation or server logic changes. Record actual device FPS, frame time and memory before interpreting this as proven performance improvement.
