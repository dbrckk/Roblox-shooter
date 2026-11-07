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


## 7 novembre 2026 — mesure de progression réelle des déplacements IA

Les bots ne sont plus déclarés « mobiles » parce qu'ils glissent de 0,3 stud entre deux calculs de combat : chaque objectif **réel** de MoveTo (waypoint PathfindingService, détour sécurisé, point direct ou destination WAIT bloquée) est transmis au moniteur de progression. Le bot dispose de 2,8 s pour réduire la distance au waypoint d'au moins 1,15 stud ; la mesure est réinitialisée dès que le prochain waypoint change de plus de 3,5 studs, quand la destination est atteinte ou à la nouvelle manche. Une génération asynchrone de chemin en cours est protégée contre les interruptions artificielles ; le mode WAIT conserve 4,5 s de grâce pour laisser le navmesh répondre. Un blocage réellement persistant déclenche les mécanismes existants de replanification, d'exclusion temporaire des bornes médicales et des couvertures, sans téléportation. Le saut n'est envisagé que sur des routes précédemment jugées directes.

Vérifications à faire en simulation Studio : déplacement latéral sans progression réelle, proximité des conteneurs, alternance de waypoints, timeout ComputeAsync, WAIT prolongé, rechargement au contact d'un abri, et aucun effet inattendu sur les animations. Le test de logique pure est exécuté par la CI ; aucune mesure de physique mobile ne peut être déduite du build.


## 7 novembre 2026 — les bots enquêtent sur les tirs entendus

Les bruits d'armes générés par **des tirs acceptés côté serveur** (humains et bots) sont enregistrés dans une mémoire plafonnée à douze événements de 5,4 secondes, sans nouveau RemoteEvent ni service distant. Le fusil de précision porte jusqu'à 155 studs, le shotgun 125, le fusil 110, le pistolet 65 et le couteau seulement 24. Les rafales d'un même tireur sont fusionnées pour limiter les allocations. Un bot qui ne voit aucun adversaire peut explorer **une zone quantifiée à 12 studs**, avec léger décalage par bot ; il n'acquiert jamais le personnage tireur, ses coordonnées live, sa hitbox ou le droit de tirer à partir du son. La cible visuellement confirmée, le souvenir de vision et les soins prioritaires sont conservés. La visée garde un rayon direct jusqu'au joueur. La recherche sonore s'arrête naturellement quand les événements expirent ou que le bot arrive, avec stabilité de 1,8 seconde de la destination pour éviter l'oscillation. Les sons mémorisés sont effacés entre manches et les objectifs de chaque IA sont réinitialisés.

À tester dans Roblox Studio et Android : tir de pistolet derrière conteneur vs sniper distant, bruit des autres bots en FFA, recherche sans omniscience, acquisition visuelle, réaction à tirs en rafale, consommation CPU et absence de ciblage par le son à travers un mur. Les tests Luau valident la logique, pas la simulation audio Roblox.


## 7 novembre 2026 — enquête sonore multi-étapes, sans connaissance cachée

Après avoir entendu un tir accepté par le serveur, un bot n'essaye plus uniquement d'atteindre un point pendant les 5,4 secondes de mémoire du coup de feu. La mémoire d'événement reste courte, mais l'**enquête déjà déclenchée** peut durer au maximum 17 secondes : approche d'une cellule sonore approximative, inspection d'un flanc, puis de l'autre. Chaque étape est stable (temps limites 7 s, 4,5 s, 4,5 s), possède trois alternatives de sol étudiées **une seule fois à l'entrée de l'étape**, et utilise le PathfindingService existant pour contourner les obstacles. Si la géométrie est invalide, le bot saute l'étape plutôt que d'errer sans fin. Un vrai blocage détecté par le moniteur de waypoints fait progresser l'enquête à l'étape suivante. La dernière ID sonore traitée empêche de recommencer sur le même événement ; de nouveaux tirs reconnus par le serveur peuvent déclencher une nouvelle enquête. L'acquisition d'une cible combat interrompt l'enquête immédiatement ; le début d'une nouvelle manche l'efface.

Le centre sonore est quantifié (12 studs) puis décalé par bot : aucune information exacte sur le tireur n'est conservée pour l'enquête. Ce système ne peut pas créer une cible de tir, et les anciennes protections de vision directe restent obligatoires pour causer des dégâts.

Tests Studio/Android obligatoires : sonar éloigné (bot ne doit pas abandonner trop tôt), plusieurs tirs, arrivée à la cellule centrale, obstacles de l'entrepôt, recherche des deux flancs, vraie ligne de visée avant de tirer, temps CPU des quatre bots et retour à la patrouille après 17 s.


## 7 novembre 2026 — cibles visibles, distance fiable et riposte

Correction de l'omniscience indirecte : la distance actuelle d'une cible derrière un mur n'entre plus dans le score de sélection. Seule une **position précédemment confirmée par rayon serveur**, mémorisée pour 2,2 s, peut conserver une cible cachée. Un nouveau tir exige toujours un rayon direct vers le personnage et un alignement suffisamment stable de l'arme. Après avoir subi un dégât réel, le bot tient compte pendant 2,8 s des adversaires **actuellement visibles** se trouvant à moins de 18 studs du point de tir serveur enregistré ; cela lui permet de privilégier l'agresseur probable dans une mêlée, sans identifier ou cibler magiquement un attaquant invisible. La réaction naturelle du bot, les erreurs de visée et les cadences d'arme restent en place.

QA Studio : tirer dans le dos du bot depuis une position visible, puis se cacher derrière un conteneur, changer plusieurs fois de cible, vérifier qu'il ne suit pas la distance du personnage caché, comparer les quatre niveaux de difficulté et confirmer que les bots ne tirent jamais à travers le décor. Les tests Luau couvrent les candidats masqués, le classement du tireur visible, les positions associées et la durée des souvenirs.
