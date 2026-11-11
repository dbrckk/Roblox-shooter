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

 
## Authoritative hit readout and protected respawns — 8 November 2026

- The shooter's existing WeaponFeedback RemoteEvent now displays an economical on-screen DAMAGE readout only for confirmed loss of server-side Humanoid health. Overkill is never exaggerated: a 24-damage shot against 9 HP reports 9 DMG. The same pure rule clamps invalid/huge values.
- A real collision with a player/bot still within the temporary 2.5-second server spawn shield produces SPAWN SHIELD instead of silently appearing to be a bad aim. This does not register a hit, score, leak opponent names/positions, or change damage. Protection notifications are capped at once per shooter per 0.45 s.
- Dead/missing/world impacts, protected defenders and other shots that do not apply damage no longer send unused Miss remotes. Existing tracer, ammo, hit, award and kill-feed remotes are unaffected.
- Shotgun pellets continue to aggregate damage per target on the server and send one confirmed Hit per damaged target. Existing priority gating prevents weaker same-volley hits from hiding a confirmed elimination; the HUD uses one reusable label, no per-shot GUI objects.
- Baseline theoretical 100-HP zero-spread body/headshots: AR-24 5/3, pistol 3/1, B-8 1/1 if all eight pellets land point-blank, sniper 2/1, knife 1/1. This is NOT a live TTK/playtest measurement; shotgun spread/falloff, reaction and reload matter.
- **Studio / mobile acceptance:** fire into cover, protected and unprotected players, bots, and empty space. Check shield text only on protected fighter contact; fire AR continuously and verify no non-damage remote flood. Confirm a 9-HP target displays 9 DMG on lethal AR shot. Confirm headshot, simultaneous shotgun multi-target kill, knife projectile, respawn and scoped sniper. Check readability and no input obstruction at 568x320 and 915x412. This change does not claim a Roblox engine test.


## Distinct weapon handling and bounded 3D gun sound (9 November 2026)

Five original viewmodels now use five cosmetic profiles rather than one generic recovery: per-weapon capped accumulated recoil, exponential settlement, transient fire rotations and distinct server-timed reload grips. Rifle charging handle, pistol slide, shotgun pump and sniper bolt move at their own mechanical timing. All hit detection, magazine and reload data remain server authoritative.

A pure audio admission policy keeps the shooter's own firing sound always audible and limits nonlocal emitter objects by distance, ECO/BALANCED/QUALITY device preset and active emitter count. At long range only the leading sound layer plays. Existing Roblox internal snap/bass/electronicpingshort samples remain interim: no claims of licensed custom gun recordings or finished premium audio.

**Studio acceptance:** rapid AR fire must visibly accumulate but cap recoil; sniper and shotgun should feel heavier than pistol; verify the pistol slide, AR charging handle, pump and bolt only travel after their respective shots; reload/swap/death cancels the visual handling without ammunition gain. Test scoped sniper, left-hand glove/parts coherence, local firing audible in dense four-bot firefights, remote distance falloff and no excessive Sound or Part allocations on mobile presets.

 
## Cover occlusion / spatial firearm audio — 9 November 2026

The client applies **at most one raycast per admitted remote firearm sound** when the distance is 12 studs or greater. The ray excludes player characters, bot models and the camera, and respects physically collidable cover. Obstructed shots use one layer at 40% of the normal mix; clear shots retain their original mix. Audio culling and per-device emitter caps run before the cast, and the local shooter's audio is never occlusion-tested. There is no new server message, new external audio or per-frame raycast.

**Manual Roblox acceptance:** put a second human or bot on the far side of a cargo container; the shot should be less sharp and quieter than a clear shot at the same distance. A non-collidable trim must not muffle the shot; a teammate standing between two clear positions must not simulate a wall. Repeat on Android ECO and QUALITY with 4 bots and check FPS + sound continuity. All bundled shot sounds are currently generic Roblox source assets, not final licensed premium foley.


## Correction du compteur de munitions après un tir refusé — 11 novembre 2026

Le client affiche immédiatement une balle consommée pour éviter une sensation
de latence lors du tir. En cas de différence entre les horloges client et
serveur, ou d'un changement d'arme pendant le délai de récupération, le
serveur peut **refuser** ce tir. Avant ce correctif, il ne renvoyait pas
toujours le chargeur réel. L'interface pouvait alors afficher un chargeur
trop vide, voire 0 balle alors que le serveur en possédait encore.

Le serveur renvoie maintenant un message `Ammo` **autoritaire** pour chaque
requête de tir parvenue jusqu'à `canFire` mais rejetée pour arme non équipée,
cadence de l'arme, cadence globale ou rechargement encore actif.
La vérification `RemoteGuard.allow(player, "FireWeapon")` reste préalable,
et le message ne déclenche ni dégâts, ni traceur, ni dépense de cartouche.
Une demande de rechargement non nécessaire (chargeur déjà plein ou
rechargement déjà actif) renvoie également le nombre réel de balles :
cela permet de réparer le HUD si le client pensait être à court de munitions.

**À contrôler dans Roblox Studio puis Android :** alterner rapidement pistolet
et fusil d'assaut, tirer près de la limite de cadence, interrompre un
rechargement et vérifier que le HUD ne reste pas bloqué à zéro après une
correction serveur. Confirmer qu'aucun tir refusé ne produit de dégâts ou
de récompenses et que le gameplay reste réactif sous latence simulée.
La CI vérifie le câblage et les conditions de resynchronisation ; elle ne
remplace pas un test multijoueur réel en réseau.


## Prise en charge manette FPS (PC, Xbox et Bluetooth Android) — 11 novembre 2026

La manette utilise la caméra, le déplacement et le saut natifs Roblox ;
le jeu route uniquement les actions FPS vers les mêmes chemins de
tir/rechargement/animation sécurisés que la souris et le tactile.

| Commande | Action |
| --- | --- |
| Gâchette droite (RT/R2) | Tir tenu pour le fusil automatique, appui individuel pour les armes semi-auto |
| Gâchette gauche (LT/L2) | Visée maintenue, relâchement = sortie de visée |
| X / Carré | Recharger |
| Y / Triangle | Arme suivante |
| LB / L1, croix gauche | Arme précédente |
| Croix droite | Arme suivante |
| Croix haut, croix bas | Fusil d'assaut, couteau |
| RB / R1 | Lancer rapide de couteau |
| B / Rond | Glissade |
| Clic stick gauche (L3) | Sprint maintenu |
| A / Croix | Saut natif, maintien aérien pour propulsion |
| Start/Options si non réservé par Roblox | Ouvrir les paramètres |

Les deux sources de tir, souris et RT, partagent **une seule** tâche
de tir automatique : aucun envoi en doublon lorsque les deux sont
enfoncées. Le changement de manette, la perte de focus et
l'ouverture des paramètres relâchent les commandes maintenues.
La croix et les boutons changent les armes via `WeaponConfig.Order`,
avec rebouclage de la dernière à la première arme.
Les transitions vers RESULTS, WAITING et les pauses de duel annulent
également les gâchettes maintenues pour éviter un tir automatique à la
reprise de la manche.

Pour les contrôleurs Bluetooth Android, le passage à la manette
masque les boutons tactiles ; le retour au tactile les fait réapparaître.
Cette bascule ne doit pas interrompre une visée ou un sprint à la
manette. Les commandes natives `Humanoid.MoveDirection` permettent
désormais d'utiliser le stick gauche (ou le joystick tactile) pour
l'air-control, le boost, la glissade et les wallruns.

**Vérification requise dans Roblox :** connecter une manette sur
Windows et une manette Bluetooth sur Android. Confirmer que le stick
droit oriente la caméra, les gâchettes tirent/visent sans entrée
fantôme, la combinaison souris + manette ne double pas les tirs,
les boutons Xbox et PlayStation affichent le bon sens,
le sprint/glissade fonctionnent, et la perte de focus/déconnexion
annule tir, visée et propulsion. Vérifier également que le menu Roblox
ne capture pas `ButtonStart` : si c'est le cas, la commande native
de menu doit primer. Les tests CI couvrent le routage et les contrats,
pas les événements matériels dans le moteur.


## Duels 1v1 : abandon et classement final — 11 novembre 2026

Un ancien défaut déclarait systématiquement **A** vainqueur lorsqu'il ne
restait qu'un joueur dans la session, puisque `a` et `b` étaient des
références Roblox sauvegardées et restaient non-nulles même si leurs
propriétaires avaient quitté le serveur.

La règle `DuelRules.forfeitSide` sélectionne désormais uniquement le
**joueur original qui est encore présent** : B gagne si A part, A gagne si
B part. Un serveur vide, un observateur remplaçant ou un troisième joueur
ne produisent jamais de victoire par abandon.

La carte de résultats affiche le survivant en premier et avec le rang 1,
même si ses victoires de manches sont inférieures à celles du joueur
déconnecté. Les comptes de manches réels ne sont pas artificiellement
modifiés. Une partie interrompue n'octroie **aucun XP de victoire** :
la récompense persistante reste réservée à une série remportée par
`SCORE_LIMIT`, sous contrôle du serveur.

Tests ajoutés : abandon de chaque participant, absence de joueurs, tiers
non autorisé, match annulé, score inférieur du survivant et égalité.
Pour valider visuellement : lancer un duel Studio deux joueurs, faire
quitter d'abord A puis B lors de manches séparées ; contrôler le libellé
du vainqueur et l'ordre du podium. Répéter avec l'arrivée d'un troisième
joueur, qui doit annuler sans attribuer de gagnant.


## Duels 1v1 : arbitrage de la limite de 24 manches — 11 novembre 2026

Un duel se termine dès que l'un des deux joueurs atteint **5 victoires
de manche**. Après de nombreuses manches nulles, la série est également
bornée à **24 manches résolues**, pour ne jamais bloquer un serveur.

**Correction :** lorsqu'aucun joueur n'a encore atteint cinq victoires
à la vingt-quatrième manche, celui qui possède **le plus de manches
gagnées remporte la série**. Une égalité parfaite reste un match nul.
Auparavant, tout duel arrivé à cette limite était marqué `DRAW`,
même sur un score tel que 4–2 ou 2–4.

L'arbitre `DuelRules.advance` produit maintenant un motif terminal :

- `SCORE_LIMIT` lorsqu'un combattant atteint cinq victoires, y compris
  à la vingt-quatrième manche ;
- `BOUT_LIMIT` lorsque la série s'arrête à 24 avec moins de cinq
  victoires de chaque côté.

Dans les deux cas, **seule une vraie victoire avec un leader unique**
accorde la récompense serveur habituelle. Les matchs nuls, abandons,
changements de lobby et échecs de réapparition restent sans prime
de victoire. Les scores et le classement publiés ne sont pas falsifiés.

L'arbitre rejette également toute tentative d'avancer après la fin de
série (5 victoires ou 24 manches) et les compteurs incohérents
(victoires totales supérieures au nombre de manches résolues).

**Vérifications CI :** 4–2, 2–4 et 3–3 à la 24ᵉ manche, cinquième
victoire exactement à la limite, série normale de 9 manches, match
nul après 24 égalités, appels répétés après clôture et états invalides.

**Validation en moteur requise :** jouer une série avec égalités
répétées, vérifier que la bannière de victoire, l'ordre du podium et
la prime de fin de série affichent le même gagnant. La CI ne reproduit
pas elle-même 24 manches en réseau Roblox.


## Cadence automatique harmonisée (souris, manette, tactile)

Le fusil d'assaut AR-24 utilise une cadence serveur de 0,115 s entre
deux tirs acceptés. Anciennement, les boucles d'entrée réveillaient
l'arme toutes les 40 % de cette durée, soit environ 21,7 réveils par
seconde, alors que le client rejette déjà les appels intervenant avant
la limite de 101,5 % de sa cadence. Les réveils inutiles ajoutaient du
travail client et pouvaient décaler le tir admis au réveil suivant.

Les trois entrées de tir maintenu utilisent maintenant la politique
pure AutomaticFireCadence : le délai automatique vaut 103,5 % du
fireCooldown, avec un minimum de 40 ms ; le bouton semi-automatique ne
répète jamais un tir sans nouvel appui. L'état maintenu reste actif
pendant un changement temporaire de sélection vers une arme
semi-automatique : revenir au fusil d'assaut ne nécessite plus de
relâcher/represser le bouton.

La souris et la manette continuent de partager une seule tâche de tir.
Le tactile applique la même cadence sans superposer ses boutons en
mode manette Bluetooth. Les garde-fous d'inventaire, de rechargement,
de phase de partie et de cadence serveur restent autoritaires.

**Validation requise sur Roblox :** maintenir le tir du fusil d'assaut
pendant un chargeur complet sur PC et Android ; vérifier le nombre de
munitions et l'intervalle entre coups audibles. Refaire le test avec
une manette, puis alterner fusil d'assaut, sniper et fusil d'assaut
en maintenant la gâchette : aucun tir semi-auto en boucle, aucune
panne de maintien après le retour sur l'arme automatique. Mesurer
le temps réel entre tirs avec les outils Studio pour confirmer
la régularité en présence de latence et de baisse de FPS.

La CI valide la politique et le câblage, pas des mesures de FPS ni
la sensation réelle à l'écran.
