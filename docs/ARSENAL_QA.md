# IRON YARD — final arsenal integration QA

## Changes actually implemented

- New **AR-24 assault rifle**, server-side spread and `0.115s` rate limit, automatic fire on held PC/mobile input.
- New **B-8 tactical shotgun**, eight raycasts per shot, server-only circular pellet dispersion, range attenuation and aggregated damage for each combatant hit. Headshots are counted by actual Roblox body hitbox.
- Five original procedural first-person weapon models and five weapon-select buttons on mobile.
- Fully server-owned magazines, reload tokens, death/respawn reset and fresh ammo at the start of each round.
- `R` keyboard / `RLD` touch reload; visible weapon/ammo state in the HUD, including empty and reloading states.
- Sniper optical scope maintained; AR, pistol and shotgun can aim using iron sights with interpolated gun position and a narrower FOV. Knife cannot ADS.
- Bot rifles now fire with limited magazines and mandatory reload pauses.
- Cosmetic weapon feedback: slight red-tinted damage flash, clear touch selected-gun state.

## Mandatory acceptance in Roblox Studio (not yet performed)

1. Start a FFA round on desktop. Shoot each firearm and inspect model, muzzle flash, audio, recoil and server hit markers. Knife should retain projectile flight.
2. Hold mouse fire with AR-24: continuous shooting until magazine reaches zero, followed by no shots until reload. Verify semi-auto weapons require repeated clicks.
3. Fire six shotgun rounds; inspect pellet hit grouping and damage against two nearby combatants separated by cover, including headshots and a partly occluded target.
4. Initiate reload and switch weapons before it ends. Switching must cancel the previous reload, not produce a free filled magazine. Die during reload; no stale refill should occur on respawn.
5. Finish a round with an empty magazine and confirm all participants return with full ammo next round.
6. Check that bots stop firing during their reload and resume only when finished.
7. On Android, tap each of the five weapon buttons. The selected slot changes color. AIM must narrow FOV for AR, pistol, shotgun and sniper, but never for the knife.
8. Swipe to aim while holding fire on a phone; camera rotation must work. Try a second finger while holding FIRE and ensure it does not release the trigger.
9. Test on a narrow landscape display to ensure the ammo indicator and RLD button do not collide with critical movement controls.
10. Check 10+ minutes continuous rifle combat with several bots on a low-memory phone: memory use, FPS, firing sounds and effect lifetimes. Verify camera rig body transparency across respawns.

## Limits

GitHub Actions compiles Luau, runs static cross-file checks, then serializes the
Roblox place. It cannot actually run Humanoid animations, GUI touch simulation,
network lag or the Roblox device profiler. Imported VANGUARD PBR meshes remain
unpublished in the Roblox place. Neither production readiness nor AAA quality
has been independently established.

## Source scope

All weapon shapes, scripts and balancing values are original assets developed
for IRON YARD. No copyrighted source assets from RIVALS or Arsenal were cloned.

## Server-verified spectator tracers and light material impacts (29 October 2026)

- Every accepted **human hitscan shot** broadcasts one trace from its actual server raycast. A shotgun emits only a representative trace for eight server-computed pellets; damage remains computed independently per pellet.
- The firing client predicts its own tracer immediately and excludes its own replicated trace; local tracers now stop at the first world collision rather than continuing through containers.
- Bot tracers and remote-player tracers include authoritative impact normals and material names when hitting world cover. Metal, wood and concrete produce small short-lived chips; humanoid impacts do not create wall sparks.
- Android clients use at most two chips at 100 studs; desktop clients use up to four at 185 studs. All effects are non-colliding, non-queryable, non-touching and Debris-cleaned; no extra gameplay network remotes.
- **Studio acceptance:** test 2 humans + 4 bots, automatic fire against steel/concrete/wood, shotgun traffic, spectator view, first-person wall occlusion, and mobile frame pacing. Predictions do not establish server damage authority. The Rojo/Luau CI is not a runtime playtest.
