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


## Bot streamed-cosmetic LOD cache (9 November 2026)

On Android with four bots, keep moving across ECO/BALANCED/QUALITY detail-visibility thresholds. Core body silhouettes, helmets, rifles and real R6 hitbox parts must stay visible and functional, while only tier=Detail armor fades out at distance. Kill and respawn bots, switch graphics presets, and join mid-round with streamed-in models to verify no detail flashes, stale hidden parts or accumulated cache connections. The client builds a bot's detail inventory once, listens to new/removed descendants and late tier attributes, and does not do a full GetDescendants scan each second. Measure real device frame times and memory; CI verifies invariants, not observed Android FPS.


## Incremental streamed arena art LOD — 9 November 2026

Move rapidly through the warehouse entrance, container lanes, and catwalks on ECO, BALANCED, and QUALITY Android. Stream models in/out, replace arena art after the round if possible, and verify that distant Detail pieces never flash before hiding. Core signs, structural silhouettes, hitboxes, moving gantries and walkable surfaces must remain unaffected. Runtime should register each folder's detail inventory once, maintain 48-stud sectors incrementally and recompute only the sector from which Parts stream out. On a graphics change the old thresholds and 8-stud motion padding still apply. Measure actual mobile frame time / hitching and memory under asset replication rather than claiming synthetic Luau inventory tests prove frame-rate gains.


## Adaptive gantry animation LOD — 9 November 2026

With all four overhead gantries visible, test ECO, BALANCED and QUALITY on Android and PC. Close-range motion must retain 15Hz mobile / 24Hz desktop sampling and the original 5.6-stud travel and 0.7-stud lift. At medium and far visible distances, sampling falls to 9/5Hz on mobile and 12/8Hz on desktop; distant motion may look less smooth but should not jitter badly. Changing to ECO or walking beyond 185 studs (BALANCED) / 285 studs (QUALITY) should return cranes to their unshifted starting positions once; returning in range should resume phase-correct animation without a jump in drift. Warning beacons should still pulse, but Android QUALITY must not create extra PointLights. Desktop QUALITY may use a point light only inside 150 studs. With streamed-out beacons/models, confirm no stale lights or warnings. Record actual Android frame timings and battery/thermal impact before asserting performance gains.


## Rapid streamed gantry beacon replacement (9 November 2026)

With StreamingEnabled and camera near all four gantries, remove and recreate a crane's beacon Part within one animation interval while leaving its Model in the arena. Confirm the new beacon immediately takes over animation/light ownership (without waiting for another full model stream), and that a missing beacon never leaves a stale PointLight. Toggle Mover off/on and change GantryIndex while a crane is in motion: the model must return to its original pivot without accumulating a shift, then register cleanly. Repeat in ECO (no motion) and desktop QUALITY (local point light), as well as Android QUALITY (no dynamic light). These checks require Studio or a real game session; CI proves the helper and source integration only.


## Idle transient-combat-FX slot retirement (9 November 2026)

On low-end Android, fire continuously with four active bots until the 48-slot BALANCED or 72-slot QUALITY transient visual pool has filled. Stop firing and confirm all impacts, tracers and muzzle flashes disappear after their 0.5-second maximum lifetime without persistent world Parts or PointLights. The index-tracked RenderStepped updater should perform no pooled visual-Part iteration after all effects expire. Fire again to verify immediate reuse and own muzzle flash priority. While firing, switch QUALITY → ECO → BALANCED and check expired or over-cap Parts never remain parented. Compare true device idle/combat frametime, P95/P99 stutter, and memory against the previous build. CI verifies slot reuse and state transitions, not actual Android frame rates.


## Boost HUD Tween throttling — 9 November 2026

While sprinting, airborne boosting and recharging fuel on a real Android device, check that the fuel bar remains smooth (0.08-second tweens capped to 10Hz in steady operation), changes amber/red precisely around 25% and 12% and snaps promptly to 0%/100%. Leave the meter full for 10 seconds: no new Tween instances should be created by the repeated RenderStepped fuel reports. Check that rapid red-zone changes cancel any previous tween. This is entirely client cosmetic; movement, charge amount, and server anti-cheat remain unchanged. Use the Roblox MicroProfiler for actual evidence; the 3601-frame pure policy test proves only bounded admission.


## First-person weapon scope visibility and mechanism cost — 9 November 2026

With all five weapons, verify their first-person models still move smoothly during recoil, movement, sprint and reload. Non-sniper ADS must preserve the complete weapon model. Enter the sniper scope and ensure the first-person weapon disappears once; exit and ensure all Parts, including semi-transparent lens/glass and attachments, return to their exact pre-scope opacity. Change weapon rapidly while scoped and shoot with four bots nearby. Opacity updates occur only on equip / scope state changes, not 60 times per second, and only the equipped weapon's firing mechanism is sampled. These pure/source checks do not substitute for a real Roblox Android FPS and visual test.


## First-person character streaming and accessory removal — 10 November 2026

Join with a local character that has layered accessories and first-person arms. Stream several accessories in/out repeatedly while moving, switching weapons, wall-running and boosting; confirm no invisible face/arms reappear to obstruct the camera and that the visible body remains correctly drawn. Remove an entire Accessory/Model from the local character, then re-add it: no duplicate Part entries should remain in the active per-frame body cache. Repeat respawn 100 times in test automation or an equivalent stress setup. Character Model is scanned once per respawn, not on each RenderStepped. Measure real memory and frame-time in Studio/MicroProfiler; the Luau cache test is only an in-memory regression.


## Private Android P95/P99 frame timing — 10 November 2026

In a Studio session or the Roblox creator's live account, open PERF and record FPS, frame P95/P99, worst frame, and count above 33.3ms over the latest 240 frames. Compare three equivalent one-minute routes under four fighting bots (ECO, BALANCED, QUALITY), including weapon swap, sniper ADS, boost and streamed arena entry. Turn PERF off/on between runs to reset the 240-frame history; public players must not receive this diagnostic display or the optional per-frame sampling. The rolling percentile window indicates stutter on the client; it is not a GPU-specific profiler or a measured FPS improvement from CI. After respawning or changing the camera, rotate the phone and confirm the sector compass repositions and tracks the new camera viewport.


## Four-bot tactical/pose phase staggering — 10 November 2026

With the creator's PERF overlay or Studio MicroProfiler, compare the last validated build against the staggered-scheduler build under the same 4-bot firefight and same graphics preset. Observe the server bot thinkMs and poseMs mean/peaks, client FPS/P95/P99, and pathfinding request rates; do not infer GPU gains from a server scheduling test. Confirm all four bots continue to acquire opponents, chase remembered sightings, fire and reload on their ordinary intervals, and visibly animate. The 5Hz decision workload now uses separate 50ms dispatcher slots instead of a shared 200ms burst, and the 8Hz/15Hz poses have per-bot phase offsets. During severe lag, a late bot update must not immediately repeat within a few milliseconds. Repeat after a round reset and a bot rebuild, and confirm no bot starves or double-fires. Full automated Luau/CI checks exercise the policies outside Roblox; a live gameplay test is still required.


## High-speed mobile streaming and bounded art LOD — 10 November 2026

On an Android device, first enter a freight sector with four active bots and the camera facing away from its large detail pieces; boost or sprint at high speed to the next sector, rapidly turn around and repeat while detail Parts are streaming in. Close decorative meshes should not remain invisible due to a 1-second stale camera position. Repeat with ECO, BALANCED, QUALITY and rapid preset changes, including a respawn or camera replacement. Check Core silhouettes, cover collision and bot hitboxes are unchanged. At a stationary viewpoint, the art sector visibility pass should not repeatedly visit unchanged sectors. During a fast camera displacement of 20+ studs since the previous sample, early refreshes are capped at four per second; the bot LOD scan remains once per second. Use the owner-only PERF panel to record actual FPS, P95, P99 and slow-frame counts: the 60-second deterministic scheduler test proves only the bounded policy, not improved GPU performance.


## Pooled confirmed hits and allocation-free bot pose signals — 10 November 2026

On a real Android client with four shooting bots, trigger repeated body hits, headshots and eliminations at near and medium range. Confirm the server-confirmed central orb and matching spark colors remain visible, grow and fade smoothly, and still prioritize lethal feedback when closely following a body shot. Change between ECO/BALANCED/QUALITY while fighting and watch for missing central confirmations under saturation; nonessential sparks may be dropped first. All confirmed local hit visuals now reuse existing pooled Parts, do not start Tweens or schedule Debris; only spatial audio retains a Debris lifetime. Measure real client P95/P99 and server bot pose timing under equivalent load and compare against the previous build. Repeat bot turns and reversed strafes to verify those poses remain visually and mechanically unchanged following the scalar-validation change. Automated 5,400-hit pool stress and 50,000 motion-signal calculations are functional regressions, not actual on-device performance benchmarks.


## Recycled rooftop exhaust vapor — 10 November 2026

With four bots shooting in an industrial arena, approach the roof vents and compare ECO (no smoke), BALANCED (one nearest active vent on Android) and QUALITY (up to two nearby vents on Android). Vapor should keep the original pale haze, steady Quad.Out drift above the duct and natural fade without visual popping from pool reuse. Rotate the camera and move through the 95/128-stud mobile source limits, then switch QUALITY → ECO while multiple wisps are live; the smoke should retire without leaving invisible Part leaks or accumulating objects in Workspace. Repeat after a respawn and a streamed-out/reappearing roof vent. The local pool caps are 0/2/5 Android and 5/11 desktop, and no emission creates Tween/Debris jobs. The smoke pose is refreshed at most 30Hz; use PERF P95/P99 and the Roblox MicroProfiler to compare actual time under combat load, not just the Luau stress-test results.


## Recycled bot-death dust under four-bot combat — 10 November 2026

With four active AI on a real Android device, defeat one and then several bots in rapid succession on solid warehouse asphalt, next to a catwalk, and above an open void. Verify that the settled R6 death pose still triggers floor-contact dust after 0.64 seconds only when a real collidable surface is hit. The fragments must expand, drift laterally and fade in 0.36 seconds with the original Quad.Out shape; they must not interfere with bullets, movement, collisions or bot navigation. Repeat while switching ECO/BALANCED/QUALITY mid-effect and after streaming/rebuilding bots. Observe stable reuse under saturation: at most 4/8/12 simultaneous local Parts on Android (16 on desktop QUALITY); missed cosmetic particles may be skipped instead of prematurely removing an active one. Repeated deaths must not accumulate TweenService jobs, Debris entries, or abandoned Workspace Parts. The dust renderer has one shared 30Hz capped update and does no per-fragment work while idle. Compare actual PERF FPS/P95/P99 and use Studio MicroProfiler under equivalent combat conditions; offline stress tests do not prove an on-device FPS gain.


## Bot death lifecycle across round resets, streaming and reparenting — 10 November 2026

In a Roblox Studio multiplayer session and then on Android, repeatedly defeat a bot just before the round resets (within its 0.64-second settled-death dust delay). The destroyed or streamed-out bot must not emit dust after leaving `NeonStrikeBots`, and a replacement with the same bot slot must bind to its own Humanoid exactly once. Repeat with all four bots, 20+ round resets, and delayed/streamed replication of `IsArenaBot` and Humanoid when feasible. Confirm the delayed dust effect still appears normally for real eliminations on nearby solid floors. Repeated streaming must not accumulate `Humanoid.Died` listeners or retain obsolete bot Models. Use Studio memory/connection instrumentation and the owner's PERF P95/P99 overlay to compare long sessions. The pure 10,000-callback test validates identity invalidation only; it does not replace real engine lifecycle tests.


## Full arena/decor reconstruction and long-session visual lifecycle — 10 November 2026

In Roblox Studio, with a client running all three visual controllers and four bots, record active `NeonStrikeDecor` fixture/vent/gantry counts, PERF P95/P99 and memory. Temporarily remove the old `NeonStrikeDecor` folder and replace it with an equivalent freshly created server decor folder; also test replacing `NeonStrikeArena` itself. Confirm: (1) old local `IronYardLocalSpot` lights are destroyed; (2) active rooftop `IronYardExhaustWisp` particles disappear without orphans, and new vents emit immediately from recycled Parts; (3) old moving gantries reset their local pivots when possible and their pending attribute/beacon subscriptions are disconnected; (4) the new decor reindexes lamps, vents and gantries and their effects resume. Repeat 20 consecutive swaps, including a period of more than 45 seconds with no optional decor at game start, and switch ECO/BALANCED/QUALITY after each swap. Check for cumulative client connections, Part counts, local PointLight/SpotLight counts and frame-time spikes. Validate a full round and respawn after swapping. These are manual Roblox engine tests: the static CI contracts and the simulated 1,000 rapid vapor resets validate wiring/bounds, not actual FPS or memory use in Roblox.


## Combat HUD listener lifecycle over 20 rounds — 10 November 2026

In a Roblox Studio multiplayer playtest, complete at least 20 rounds with repeated deaths, camera recreation and graphics changes, then repeat a shorter session on Android. During each respawn, the kill feed must remain appropriately sized on the active camera without listeners retained on old Cameras; the incoming-damage arrow must clear when the character is removed, show fresh damage from only the new character, and never vanish due to an old delayed fade. When server `leaderstats` is replaced or its `Eliminations`/`Deaths` values appear asynchronously, the results card must show the active values, never update from removed IntValues, and release old listeners. At LocalScript teardown, the three controllers must release their own GUI and relevant event connections. Compare Studio connection counts and memory before/after 20 rounds, while checking PERF FPS/P95/P99 on Android. Automated CI checks verify Luau compilation and source contracts, not Roblox engine connection counts or actual on-device performance.


## Server death scoring, delayed Humanoid and thrown knife owner exit — 10 November 2026

Run a Roblox Studio multiplayer test with at least two humans and four bots. Kill the same player repeatedly across 20+ rounds, including during the final second before RESULTS, while a new character is spawning, and with a `Humanoid` arriving after `CharacterAdded`. Every legitimate death during LIVE must increment the *current* leaderstats exactly once; old Humanoid.Died signals after respawn/round reset, and any death while WAITING/COUNTDOWN/RESULTS, must not increment a new round. Remove/re-add `leaderstats` in Studio and confirm the current active container receives the next valid increment. Disconnect a player with an active projectile knife and verify the projectile is destroyed on the next Heartbeat and cannot apply late damage. Disconnect/reconnect users to verify no stale score listeners or per-player records accumulate. These runtime checks complement the 30,000-generation Luau regression; CI validates control flow and compilation but not real network latency or Roblox engine timing.


## Combined shot sound/tracer remote traffic — 10 November 2026

In Roblox Studio with two human operators and four active bots, fire automatic rifle, pistol, sniper and shotgun at a solid wall, an AI combatant and a human combatant. Verify each remotely observed accepted shot produces exactly one spatial gunshot sound plus its optional quality-budgeted muzzle flash/tracer, with no second local sound for the firing operator. Move the observer beyond the ECO/BALANCED tracer distance: visual trails should be culled by the existing client policy, while any audio permitted by `WeaponAudio.select` should still play. Verify bot audio remains audible even when remote tracer slots are saturated, and verify headshots, kills, ammunition, pellets, reload and bot sound-investigation behavior remain unchanged. Throw a knife into clear space and directly at nearby cover: `FireSound` must still be delivered for those projectile-only shots. Compare network profiling under the same repeated-fire workload: hitscan and bot shots should produce one `WeaponFx` broadcast instead of two, but serialized byte reduction depends on packet metadata and number of connected players. Automated CI validates wiring and builds, not real latency or acoustic synchrony.


## Server-filtered distant shot FX with guaranteed local/observer delivery — 10 November 2026

Run a Roblox Studio multiplayer test with two to eight human players and four bots, then simulate a busier lobby if available. Position one shooter and three other players within 100 studs, with additional *living* players at 260+ studs from the muzzle. Verify close listeners still hear each accepted rifle, shotgun, pistol, sniper, thrown-knife and bot shot and see tracer/impact effects according to their current graphics preset. Move a listener just inside and outside the 256-stud server bound (the separate client sound/graphics bounds are lower), including vertical separation. Repeat after deaths and respawns, and watch from any available spectator camera: those with no healthy/known character must not lose relevant shot FX. The firing player must retain their own shotgun pellet impact evidence even if their local camera is displaced. Check that an off-map listener no longer receives cosmetic `WeaponFx` payloads, but still receives global `KillFeed` and trusted private `WeaponFeedback`. In a lobby where all characters are close, `CombatFxRelay` should take its `FireAllClients` path rather than issuing separate `FireClient` calls. Record real network packet/byte rates and server processing time for repeated fire before/after at the same player count; the test suite's 50,000 eligibility decisions are a deterministic logic simulation, not measured Roblox bandwidth.


## Burst-fire server CPU, raycast filters and live-safe audience cache — 10 November 2026

In Roblox Studio, test AssaultRifle, Pistol, Sniper and Shotgun fire with 2, then 8 human players and four bots during repeated rounds. Check rays still ignore the current character and hit opposing characters, terrain and cover; repeated automatic fire must not create new RaycastParams each time. Change character/respawn between shots, then throw a knife to ensure its separate projectile filter also excludes the knife and shooter. Verify zero/near-zero, non-finite and oversized direction values are still rejected by the server without consuming accepted weapon hit registration. For the remote-FX audience, move an observing player across the 256-stud boundary, kill/respawn them and replace their HumanoidRootPart if possible: live position and health must be respected every shot, while replaced/missing references fail open until the next <=150ms roster snapshot. Add or remove players during continuous shooting to verify immediate cache invalidation. Compare server MicroProfiler CPU, memory allocations/GC and network message counters to the preceding build at identical fire rates, over 20 rounds. The deterministic tests exercise 50,000 vector checks and 6,001 simulated 10ms audience cadence checks; they are not real engine CPU benchmarks.
