# IRON YARD — Combat and navigation validation

## Implemented
1. Navigation is server-controlled in `BotNavigation.luau`. Unobstructed horizontal ground routes issue `Humanoid:MoveTo` directly. Blocked, steep or elevated destinations use async `PathfindingService:ComputeAsync`. Bots follow their old waypoints while a new path is being computed.
2. Every async computation stores a per-bot revision. A new target, a stuck recovery or a round reset invalidates old results. Navigation never teleports bots through cover.
3. Dynamic spawn points are selected by `SpawnService` against occupied geometry and living combatants. Server-only temporary spawn shields apply to humans and AI; firing cancels protection.
4. `AlignOrientation` makes bots face visible targets while navigating, instead of rotating their full body with instantaneous position edits. When there is no target or at round end, ordinary `Humanoid.AutoRotate` resumes.
5. Dead bot geometry disables collision/raycast querying at the `Humanoid.Died` signal. Elimination graphics remain briefly, without corpse-based invisible cover.
6. Round starts recreate defeated AI instead of retaining their dead body. Retired bot slots no longer count as ghost leaders when more humans join.
7. The projectile knife traces the server's initial two-stud muzzle path and cannot appear beyond close cover.
8. Mobile LOD refreshes when detailed models stream in and keeps fine decoration invisible at long range.
9. Bot target selection checks real head/torso sightlines, prioritizes visible opponents, and chases only the last observed position after cover is entered. No hidden live-coordinate chasing.
10. `BotTactics.luau` samples four short retreat destinations (terrain slope/cover/route scoring) when wounded or reloading and computes bounded flank points. Cover searches are throttled and run only on the server.
11. Walking routes use five waist/shoulder capsule-edge probes; the same RaycastParams is reused for all probes. Stale asynchronous paths cannot override newer decisions, and compute attempts are rate-limited.
12. Empty AI magazines reload even without sight of an enemy; the tactical retreat cannot deadlock reloading.
13. Bot animation strides advance with real horizontal travel rather than wall clock, with smoothed jump/reload/aim poses; no external asset IDs.
14. Knife projectiles are invalidated when a round resets, the shooter respawns, or the phase leaves LIVE.
15. Confirmed combat damage stamps server-owned source position attributes on damaged human characters; a lightweight client-side directional indicator gives mobile/desktop feedback. Score/damage stay server-authoritative.
16. During the mission briefing, the left-side standings automatically hide so mobile portrait UI does not overlap.

## Required real-device scenarios — not yet performed
- Navigate with four bots through warehouse walls, low stacked pallets, forklift silhouettes, catwalk steps, and high platforms. Observe path failures and stuck recovery.
- Check the new `AlignOrientation` setup while bots run, aim, jump, die and respawn. Inspect for overspinning or unphysical slides; tune torque/response from an actual Studio test.
- Shoot at human and bot targets just after respawn. Confirm visible protection status, no damage while protected, and immediate loss of protection after shooting.
- Eliminate a bot and fire through its remains. Confirm the ray hits the next live fighter or the level's hard cover.
- Throw the knife toward a wall directly in front of the camera, and toward another fighter at very short range. Neither shot should clip through solid cover.
- Join and leave mid-round. The top-three panel must no longer feature retired AI scores.
- Let the round finish while a bot is dead, then confirm all intended bot slots return in the next round.
- Fight a bot through a warehouse corner with the head hidden but torso visible; ensure it detects/shoots only with a true muzzle ray to the target. Hide for over 2.2s: it must not follow your current unseen position.
- Injure a bot below 55% HP; verify it takes cover when recently hit. Empty its magazine while hidden: verify reload completes after ~1.85s even without line of sight.
- Verify all five direct-route capsule probes reject corners too narrow for the bot (container corners, pallets, catwalk access). No repeated sliding into walls.
- Fire a knife at the very end of a round, then start a new one. Confirm no knife damage or delayed miss notification carries into the next round.
- Get shot from front/side/rear as a player on Android portrait and desktop. The brief directional chevron must point toward the shot origin and disappear quickly.
- Test onboarding in portrait: while the mission briefing is visible, the top-three scoreboard must not overlap it and should return when the briefing closes.
- On Android, test 20+ minutes at multiple graphics qualities. Record frame pacing, memory and thermal behavior.

## Verification boundary
GitHub Actions compiles Luau and serializes the Rojo place; it does not run Roblox Humanoid physics, render imported MeshParts or measure mobile performance. Real Roblox Studio and Android playtests are still mandatory.

## Reference
AI/mode structure remains informed by the REA run against a legally accessible MIT-licensed FPS, never by copying a proprietary Roblox experience. Roblox Creator Hub documents `PathfindingService`, `Humanoid` and the one-attachment `AlignOrientation` used here.
