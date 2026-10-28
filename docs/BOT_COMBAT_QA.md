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

## Required real-device scenarios — not yet performed
- Navigate with four bots through warehouse walls, low stacked pallets, forklift silhouettes, catwalk steps, and high platforms. Observe path failures and stuck recovery.
- Check the new `AlignOrientation` setup while bots run, aim, jump, die and respawn. Inspect for overspinning or unphysical slides; tune torque/response from an actual Studio test.
- Shoot at human and bot targets just after respawn. Confirm visible protection status, no damage while protected, and immediate loss of protection after shooting.
- Eliminate a bot and fire through its remains. Confirm the ray hits the next live fighter or the level's hard cover.
- Throw the knife toward a wall directly in front of the camera, and toward another fighter at very short range. Neither shot should clip through solid cover.
- Join and leave mid-round. The top-three panel must no longer feature retired AI scores.
- Let the round finish while a bot is dead, then confirm all intended bot slots return in the next round.
- On Android, test 20+ minutes at multiple graphics qualities. Record frame pacing, memory and thermal behavior.

## Verification boundary
GitHub Actions compiles Luau and serializes the Rojo place; it does not run Roblox Humanoid physics, render imported MeshParts or measure mobile performance. Real Roblox Studio and Android playtests are still mandatory.

## Reference
AI/mode structure remains informed by the REA run against a legally accessible MIT-licensed FPS, never by copying a proprietary Roblox experience. Roblox Creator Hub documents `PathfindingService`, `Humanoid` and the one-attachment `AlignOrientation` used here.
