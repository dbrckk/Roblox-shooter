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

## New engagement movement — 6 November 2026

Visible-duel movement uses a server-chosen 1.65-second goal anchor rather than recomputing a moving lateral endpoint every 0.2s. Three candidate lanes are grounded at the bot's level and rejected if their approach intersects freight geometry or a void. Distant fighters advance toward useful range, close fighters back away and mid-range fighters strafe on alternating sides. Replans are rate-limited even when the observed enemy moves more than 14 studs; failure is cached too. This works with existing defensive cover, last-seen memory and asynchronous navigation. Shooting additionally requires sufficient alignment between the smoothed aim vector and the current verified target direction, with stricter accuracy at long distance.

Studio/Android validation remains necessary: compare movement oscillations in container corridors, close-quarter duels, distant fights and pathfinding load; check that bots don't become passive or too inaccurate. Luau regression and successful Rojo build are not a substitute for physical simulation.

## Cible IA vérifiée et usage des soins — 6 novembre 2026

La sélection de cible retourne un couple indissociable (modèle, dernière position vérifiée par rayon du serveur). Aucune position d'un autre adversaire examiné ni les coordonnées actuelles d'une cible cachée ne sont transmises à la poursuite. Mémoire d'une cible invisible limitée à 2,2 s, avec tests de régression. Les bots blessés à 48 % de vie ou moins peuvent choisir une station publique disponible dans un rayon de 65 studs au même niveau. Ils s'y rendent seulement en l'absence de ligne de tir directe, après priorité à leur couverture défensive. À portée de 7,5 studs et à travers une ligne sans mur, un bot utilise la même recharge de 24 s et les mêmes 40 PV que les joueurs. Le FFA reste chacun pour soi. Tests Studio et Android nécessaires pour l'équilibre et la navigation réelle.


## Recovery from unreachable medical objectives — November 2026

Wounded AI commit to a selected medical goal for 2 seconds instead of switching every 0.2-second update. Stations are ranked by health-availability, distance and danger from a *previously verified* sighting only. An actually stuck bot excludes the failed station for 14 seconds and can seek an alternative. The navigation path is invalidated when switching between combat and medical intent. The objective history is cleared at round reset. No client-controlled health, teleport or ability to track hidden enemy positions was added.

Studio/Android acceptance is still required: approach/blocked freight passages, contested medical sites, priority when shot, movement transitions and cooldown fairness.


## 6 novembre 2026 — défense derrière couverture et récupération des coins

Les bots blessés, sous suppression ou en rechargement évaluent désormais six directions bornées (au lieu de quatre), avec priorité forte à une vraie couverture de tir solide. Les raycasts de navigation et de couverture respectent les pièces physiques `CanCollide`, et trois échantillons intermédiaires de sol rejettent les trajectoires passant par des vides/passerelles. Lorsqu'un déplacement tactique échoue réellement et que la récupération de blocage est déclenchée, la dernière couverture infranchissable est exclue pendant huit secondes. Une issue de repli alternative reste possible sans redémarrer tout le comportement d'un bot. La navigation directe anticipe désormais le sol jusqu'à 30 studs devant le bot (quatre sondes plafonnées), sans scan intégral de la carte et sans nouvelle API externe. La sélection et le délai de rejet sont vérifiés par un script Luau pur dans la CI.

A confirmer dans Roblox Studio : mouvements autour des conteneurs et forklifts, passerelles élevées, couverture lors du rechargement, fuite hors des coins, consommation de raycasts et absence de passivité excessive. Le succès du build ne confirme pas la physique Roblox sur Android.
