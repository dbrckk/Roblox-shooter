# IRON YARD — production

## Référence
RIVALS pour la boucle d'affrontements, Hypershot pour la réactivité, Arsenal pour la variété d'armes. Recréation indépendante, pas de copie d'expérience Roblox.

## État
- [x] moteur Roblox FPS Luau licencié MIT
- [x] serveur : dégâts et cadence de tir
- [x] armes, caméra, animations procédurales, HUD
- [x] arsenal étendu : AR automatique, shotgun à 8 pellets avec raycasts serveur, 5 viewmodels, sélection PC/tactile, ADS avec animation de visée
- [x] chargeurs et rechargement contrôlés côté serveur, confirmation des munitions vers le HUD, rechargement PC/tactile, réinitialisation par manche
- [x] IA : chargeur limité et rechargement, son de fusil synchronisé, aucune victime NPC extérieure au combat
- [x] feedback : arme choisie signalée sur mobile, flash léger aux dégâts, cache des parties du corps pour éviter les traversées répétées de l'arbre de scène
- [x] entrées tactiles Android/iOS ajoutées
- [x] build CI Rojo
- [x] carte arène originale de 356 x 356 studs, couvertures et plateformes
- [x] statistiques de session (éliminations et morts, sans persistance)
- [x] moteur de carrière DataStore v1 : XP et rang, éliminations, tirs à la tête, victoires par UserId, verrou concurrent, autosave, BindToClose et reprise après erreur (implémenté et compilé, validation publiée encore requise)
- [ ] confirmer **en expérience Roblox publiée** la persistance après reconnexion, reprise des verrous et métriques de perte sous déconnexion serveur
- [x] Arena FFA : gestion serveur des phases countdown/live/résultats, objectif 15 éliminations et HUD (tests Studio requis)
- [ ] vrais duels 1v1 jusqu'à 5v5, équipes, spectateur et matchmaking
- [ ] tests réellement exécutés en Roblox Studio et sur Android
- [x] personnages IA mobiles : recherche de cible, navigation PathfindingService, tir et réaction variable (test Studio à réaliser)
- [x] armures tactiques VANGUARD originales sur R6, animation procédurale marche/visée/recul, fusils 3D, muzzle flash et traînées colorées (validation runtime requise)
- [x] thème IRON YARD : terminal industriel de jour, grues, containers, marquages routiers, signalétique, sans Bloom, LOD local Android
- [x] nouveaux meshes Blender PBR mats olive/sable/ardoise/rouille : 7 FBX, 8 GLB en 2 LOD, 32 cartes PBR 1 024×1 024 validées et archivées sur GitHub (quatre modèles LOD0 de 14,96 Mo, compatibles avec la limite d'upload Roblox) (upload Roblox encore à faire)
- [x] briefing de début de manche et réticule contrasté sur fond clair (validation en jeu requise)
- [x] classement des trois meilleurs combattants, secteur et direction en temps réel (tests en jeu nécessaires)
- [x] silhouettes industrielles, couvertures physiques et détails LOD optimisés sur mobile (tests Android nécessaires)
- [x] navigation bots asynchrone sans immobilisation : trajectoire directe sur terrain libre, vérification des obstacles bas, replanification, invalidation des chemins périmés
- [x] sécurité du round : bot éliminé non bloquant, score des bots retirés purgé, respawn adapté aux couvertures, protection temporaire commune aux joueurs et IA
- [x] orientation physique des bots face aux cibles visibles et animation de visée existante (à confirmer en Studio)
- [x] couteau : contrôle serveur du segment d'apparition pour éviter de traverser une couverture proche
- [x] LOD : prise en compte des modèles chargés après l'arrivée du client, cache de détails mis à jour à la réplication
- [x] IA tactique : préférence pour les adversaires visibles, mémoire uniquement de la dernière position observée, contournement de couvertures et recherche de repli quand blessé/en rechargement (validation Studio requise)
- [x] déplacement IA : collision testée sur cinq rayons de capsule, filtres réutilisés, limites de recalcul d'itinéraires
- [x] animations bot : cadence de pas liée à la distance parcourue, transition saut / rechargement / visée, sans AnimationId externe
- [x] feedback des tirs entrants : indicateur directionnel léger avec origine vérifiée côté serveur, compatibilité téléphone
- [x] correction UX mobile : classement caché pendant le briefing, puis rétabli
- [x] correctif combat : couteaux invalidés au changement de manche / réapparition du tireur ; recharge IA même sans cible visible
- [ ] importer/publiquer les MeshParts et SurfaceAppearance dans Roblox Studio, calibrer positions, FX, animation rigide et Android
- [ ] skinned meshes haut de gamme, animations professionnelles, mixage audio spatial, profils graphiques
- [ ] anti-triche et latence validées sous charge
- [ ] matchmaking, progression, sauvegardes et stabilité publication

## Catalogue star-list
Sources pertinentes: TabooHarmony/roblox-brain, Chrrxs/robloxstudio-mcp, Scenario Labs 3D Collection (CC BY 4.0 avec attribution et contrôle de provenance). Ressources à auditer avant exécution ou intégration.

## Livraison
Pas de publication sans Rojo build vert, playtest deux joueurs, contrôle tactile Android, mesure de performances et conformité licences.

## Combat feedback (29 October 2026)

Server-owned `CombatAwards` grants **session-only** XP (100 elimination + precision/multi-kill bonuses) and short-lived medals including DOUBLE KILL / TRIPLE KILL / RAMPAGE. The XP is visible locally but **is not persisted** between joins. Streaks reset on death and on new rounds, and never affect weapon damage, matchmaking or winner decisions. No virtual currency, purchases or reward claims are implemented. A reliable DataStore progression system would need save/retry/duplicate-session protection and actual published Roblox runtime tests before being called persistent.

The new industrial trusses, catwalk rails and gantry rigging are cosmetic only. Their physical fidelity and Android frame pacing still require Studio/device validation.

## 29 October 2026 — bot last-sighting investigations

Bots now **search a verified last-seen position for up to nine seconds** after target line-of-sight disappears, rather than immediately abandoning an opponent after a 2.2-second targeting timeout. The search pattern visits the last observation and then alternates two short lateral sweeps, testing for walkable ground and the same platform height. Dead enemies and stale sightings are discarded. Target position is never read through walls. Pathfinding and stuck recovery remain bounded. **Roblox Studio tactical playtest still required.**

## Five rank-based weapon finishes

The player unlocks matte, cosmetic-only finishes automatically at career ranks **1, 3, 6, 10 and 15**: FIELD ISSUE, DESERT PATROL, COLD STEEL, FOUNDRY and BLACK GRADE. The locally rendered weapon receiver, slide, grips, gloves and sleeves change as the authoritative server rank updates, while the career panel shows the current finish and next unlock. No real-money purchase, weapon buff, imported PBR claim or network hit authority is attached to this feature. Visual inspection on Studio and Android is still required.

## End-of-round retention and mobile presentation — 29 October 2026

A central, responsive **12-second results card** now displays the server-verified winner, personal eliminations/deaths, round XP, total career XP, next-rank progress and top-three leaderboard. The player receives a VICTORY headline only when `IronYardWinnerUserId` equals their immutable Roblox UserId; matching display names cannot spoof wins. It is display-only and automatically hides outside the RESULTS phase. Runtime screen-overlap/playtest remains to be completed in Studio and Android.

## 5 November 2026 — responsive mobile UX, priority: playability

- [x] Replace fixed pixel offsets for FIRE/ADS/SLIDE/RUN/RELOAD and all five weapons with an adaptive, viewport-safe layout; geometry is verified for 11 representative Android/tablet/desktop touch viewports.
- [x] Disable the whole touch surface during RESULTS and while Settings is open. Kill any held auto-fire loop when the touch controls become inactive, so a finger held across a round transition cannot shoot through UI.
- [x] Move the mobile killfeed to the top-left in a compact two-entry variant, hide it during onboarding and on very narrow portrait devices, while keeping the full desktop feed intact.
- [x] Remove redundant TOP 3 overlay from mobile gameplay (already displayed in the server-led RESULTS summary); show a small career rank panel instead of a large panel occupying the virtual joystick.
- [ ] Verify physical touch hitboxes, the native Roblox jump and thumbstick, notch insets and device rotation in a **published Android client**. Luau geometry tests and Rojo build cannot measure device screen occlusion or FPS.

- [x] Add client-side moving gantry trolleys and suspended spreaders at the four arena corners, using a deterministic finite motion budget; visual-only and graphics-preset-aware. Real Android scene profiling remains pending.

## Blocage de navigation IA — novembre 2026

L'IA utilise désormais une **navigation à quatre états** : DIRECT (couloir dégagé), PATH (points de passage calculés), AVOID (détour latéral/arriéré validé au sol) et WAIT (attente sans charger un obstacle). Chaque détournement examine au maximum six candidats proches, rejette les sorties de carte et les dénivelés, puis les vérifie avec cinq rayons de gabarit du humanoïde. Les calculs Roblox PathfindingService sont asynchrones et leur résultat périmé est ignoré ; un calcul qui dépasse cinq secondes est annulé logiquement et les nouvelles tentatives bénéficient d'un délai plafonné à 4,2 s. Les états sont visibles dans l'attribut de modèle `IronYardNavMode` pour diagnostic Studio.

Le détecteur de blocage attend qu'un véritable échec de mouvement persiste avant de recalculer. Il n'annule plus systématiquement les calculs simplement parce qu'un bot attend, et n'utilise un saut de récupération qu'occasionnellement en mode DIRECT. Un test Luau exécute la sélection des six directions de contournement et la temporisation ; la **validation physique et le framerate Android restent à effectuer dans Roblox Studio**.

Les contrôles de déplacement direct sondent aussi **la présence du sol à 7 et 14 studs devant le bot** : un corridor sans mur ne suffit pas si le chemin traverse le vide ou quitte une passerelle. Les nouveaux adversaires visibles réinitialisent les échecs de route précédents afin qu'un vieux blocage n'entraîne pas de retard artificiel au combat. La vérification physique Studio reste nécessaire.

## Combat IA — chemins dynamiques et couvertures atteignables (novembre 2026)

- [x] Suivi des chemins calculés par l'événement Roblox `Path.Blocked` : les obstacles apparus **devant** un bot invalident l'itinéraire, ceux derrière lui ne provoquent pas de recalcul.
- [x] Nettoyage des abonnements aux anciens chemins lors d'un changement de cible, d'une interruption, de l'arrivée au but ou d'une mort ; les réponses PathfindingService périmées ne sont pas réutilisées.
- [x] Abandon des chemins vers un adversaire ayant changé de position de plus de 20 studs, avec reprise par contournement local ou nouveau pathfinding.
- [x] Couverture défensive limitée aux positions réellement approchables par le gabarit du humanoïde et reliées par un sol, et mise en cache de 2,4 s **même en cas d'échec**, réduisant les sondages inutiles.
- [x] Réactivité à la pression : dès qu'un bot est blessé et descend sous 68 % de vie, il peut chercher un abri atteignable, indépendamment du rechargement.
- [ ] Vérification Studio/Android : blocages d'itinéraires en cours, passage des escaliers, angles de conteneurs, mouvement sous tirs, fréquence des PathfindingService `ComputeAsync`.

## Combat : cadence globale anti-rotation d'armes — novembre 2026

Le serveur conserve la date du prochain tir après chaque coup réellement accepté, selon le rechargement instantané de l'arme qui vient de tirer. Changer d'arme ne remet plus ce temps à zéro : un tir au fusil à pompe ou au sniper ne peut pas être suivi instantanément d'un autre tir via le pistolet ou un autre emplacement. Le client applique le même délai en prédiction locale afin de ne pas afficher de coups qui seraient refusés par le serveur. Le lancer rapide de couteau est ignoré si ce délai n'est pas écoulé. Les compteurs reviennent à zéro au début de la manche ; une réapparition en cours de manche ne réinitialise pas la protection. Test Luau `scripts/test_weapon_cadence.luau` et vérification du branchement dans le workflow Rojo.

## Fiabilité des commandes de déplacement — novembre 2026

Les directions de déplacement reçues des clients (glissade, boost, wall-run, escalade) sont validées par un module Luau pur `SafePlanarInput` avant toute conversion en vélocité : NaN, infini, valeur excessive ou magnitude horizontale quasi nulle sont rejetés. Une action exigeant une direction retombe sur l'orientation serveur, une mise à jour facultative est ignorée. La téléportation différée de l'escalade vérifie que le joueur possède encore le personnage initial ; un décès ou une réapparition intervenue entretemps annule ce déplacement. Ces protections ont des tests mathématiques exécutables Luau et des contrôles de branchement CI. Un essai physique sur Roblox Studio/Android reste requis.

## Résultats de manche immuables et classement public — novembre 2026

Le serveur produit maintenant un snapshot complet `IronYardFinalStandings` avant d'annoncer `RESULTS`. Les kills, morts, égalités de rang, identifiants joueurs et vainqueur sont déterminés une fois pour toutes. Le HUD des résultats affiche la **place finale du joueur** ; un spectateur arrivé après le dénouement ne reçoit pas faussement des statistiques à zéro. Le top 3 reste identique si quelqu'un quitte ou rejoint le serveur durant la cérémonie. Les homonymes sont distingués par ID et une égalité d'éliminations ne déclenche aucune récompense de victoire, même avec un nombre de morts différent. Un module Luau pur teste ces invariants ; confirmation visuelle Studio/Android nécessaire avant sortie publique.

## Impacts directionnels et réactions au tir — novembre 2026

Les tirs réellement validés sur le serveur (raycast, grenaille et tirs des bots) enregistrent désormais leur origine pour les combattants humains **et** IA. Un bot touché oriente son animation de recul selon le côté de l'impact et perd brièvement la stabilité de sa visée. Il est temporairement incité à chercher une couverture navigable, y compris si le tireur n'est pas visible : la position du tir sert exclusivement à la retraite, jamais à viser à travers des murs. La suppression expire (2,3 s ou 3,2 s si santé critique). Côté client, les traceurs des bots hors portée d'affichage ne créent plus d'objets visuels superflus. Validation physique et esthétique en Roblox Studio toujours indispensable.

## Animation tactique IA — cadence indépendante — 6 novembre 2026

Le squelette R6 des bots est animé sur une boucle cosmétique indépendante du cycle de décision IA (5 Hz). Les adversaires proches d'un joueur reçoivent des poses de combat jusqu'à **15 Hz**, les adversaires lointains **8 Hz**, sans requêtes supplémentaires de pathfinding ou de tirs. Le mouvement avant, arrière et latéral pilote les jambes, les épaules, l'inclinaison du corps et le freinage selon la vitesse *réellement parcourue* ; les bots immobiles derrière un obstacle ne simulent plus une course sur place. Les phases du pas avancent avec la distance, les transitions de visée/rechargement/suppression utilisent un amortissement exponentiel et les éliminations produisent un bref mouvement d'effondrement avant le nettoyage du modèle. Le calcul de profil est testé sous Luau. **Les fréquences sont des objectifs d'actualisation serveur, pas une mesure de FPS Android** ; tester la fluidité, la bande passante des Motor6D et la pose avec meshes PBR dans Roblox Studio avant déploiement.

## Qualité des impacts et du tir — novembre 2026

Les anciens traceurs rectilignes statiques deviennent des **segments courts qui traversent la trajectoire** (durée maximale 0,15 s), pour éviter les barres lumineuses de plusieurs centaines de studs. Les impacts validés ou prédits localement s'adaptent à la matière : étincelles métalliques, éclats de verre, échardes de bois, poussière de béton/terre. Les surfaces conservent une marque circulaire discrète, éphémère et non interactive. Les inventaires de marques sont plafonnés à 10 en ECO, 16 sur Android en mode normal, 22 en qualité Android et 36 sur desktop haute qualité, avec élimination des plus anciennes. Chaque effet utilise des instances locales non collidables/non-queryables et des temporisations courtes. Les éclairs de bouche utilisent le point réel du modèle de l'arme en première personne, sauf lorsque la lunette de sniper masque l'arme ; la direction du tir oriente ceux des autres combattants. Aucune texture payante ou service externe n'est nécessaire. Le profil pur `CombatVfxProfile` est testé dans le CI ; l'apparence, la visibilité et la charge GPU restent à valider en Roblox Studio et sur Android.
