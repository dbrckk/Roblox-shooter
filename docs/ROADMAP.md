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

## Environnement visuel : éclairage et usure industrielle — novembre 2026

Le terminal reçoit treize **luminaires industriels** (neuf dans la halle et quatre au-dessus des passerelles), avec corps en acier, diffuseurs en verre et cages de protection. Les sources lumineuses réelles sont **strictement locales au client** : au plus 0 spot en ECO, 2 sur Android équilibré, 4 sur Android qualité, et 8 sur PC qualité, sélectionnées selon la distance à la caméra et recalculées toutes les 1,2 s. Les luminaires n'ajoutent ni collision ni raycasts serveur. Le sol reçoit des marques de pneus et de poussière légères, composées de décors non queryables en catégorie `Detail`, donc masquées par le LOD existant à distance. La correction des couleurs et l'atmosphère sont ajustées sans cycle nocturne qui nuirait aux joueurs : lumière de jour, contraste préservé, brouillard limité et petit bloom uniquement sur PC qualité. Le module pur `EnvironmentProfile` fixe les budgets et est testé sous Luau ; le résultat perceptuel et la performance GPU doivent encore être validés dans Roblox Studio et sur Android avant publication.

## Géométrie visible sans importer de modèles — novembre 2026

La halle de combat ne se résume plus à des murs ouverts : deux pans de couverture inclinée à nervures métalliques encadrent des lanterneaux vitrés et cinq vitrages de toiture ; des gouttières et ventilateurs d'extraction complètent la silhouette. Le plafond est **un décor**, sans collision ni requête de tir, et sans ombre opaque dégradant la visibilité en combat. Les vingt bâtiments du skyline extérieur reçoivent des toitures, quais à rideaux métalliques, signalétiques et extracteurs intermittents. Les deux chariots élévateurs existants gagnent des vérins hydrauliques, fourches effilées en véritables `WedgePart`, rails, marchepieds, rétroviseurs, compteurs et reliefs de roues. Les accessoires décoratifs conservent `CanCollide=false`, `CanQuery=false` et un tier LOD adapté. **Ce sont des pièces 3D Roblox natives réellement intégrées au jeu**, pas de vrais MeshParts PBR : les cartes normales/rugosité des personnages VANGUARD restent inactives jusqu'à import autorisé des quatre modèles dont les identifiants sont toujours à zéro. Les contrôles statiques et la compilation attestent de l'assemblage source, pas du rendu en Studio/Android.

## Habillage premium des couvertures de combat — novembre 2026

Les 16 barrières de béton autour des conteneurs, les 16 roadblocks au centre, les protections d'entrepôt et la station de conditionnement utilisent maintenant des panneaux 3D à double face, montants métalliques, brides de pied, cornières supérieures et chevrons de sécurité à couleurs distinctes. Le module `CoverSurfacePlan` sélectionne les styles à partir des **volumes existants du gameplay**. `CoverArt` dessine uniquement des éléments ancrés avec `CanCollide=false`, `CanQuery=false` et `CanTouch=false`, sans modifier les hitboxes des protections ni les parcours bots. Les pièces `Detail` sont prises en charge par `BotLOD` sous le dossier `IronYardCoverSkins`, pour limiter leur coût sur mobile. La construction est protégée par un test Luau du plan de styles et des contrats Python CI. Ces pièces natives sont un remplacement visuel immédiat, **pas** des MeshParts PBR importés. Les véritables modèles VANGUARD restent bloqués par l'absence d'asset IDs Roblox autorisés : le registre `VanguardAssetIds.luau` contient encore quatre zéros. Validation de rendu et de FPS dans Roblox Studio / Android nécessaire avant publication.

## Fiabilisation de l'activation PBR — novembre 2026

Les modèles importés sont maintenant vérifiés par `VanguardMeshPolicy` : sept noms exacts par coloris, MeshId réel et quatre cartes PBR non vides sur chacune des 28 pièces. `VanguardMeshKit` nettoie **tous les descendants non autorisés** des MeshParts clonés afin d'empêcher l'introduction de scripts ou de composants étrangers dans les bots. Les chemins d'import automatique via InsertService, de pose sur les personnages et d'installation manuelle dans Studio utilisent le même niveau de validation. Le kit déjà présent n'est remplacé par la commande Studio que si tous les 28 composants ont validé leurs textures. Les anciens bots procéduraux restent actifs en cas d'asset inaccessible ou incomplet. La production du GLB 1K est prête, mais **les quatre IDs du registre sont encore à zéro** ; Open Cloud + permissions créateur et vérification Roblox restent indispensables pour que les MeshParts apparaissent en partie.


## 6 novembre 2026 — présentation de la mort et du redéploiement

- [x] Source des éliminations humaines écrite côté serveur après dégâts létaux confirmés : tirs raycast, grenaille, couteaux et bots. Aucune autorité client sur la cause de la mort.
- [x] Carte PC/Android de défaite avec tireur, arme, headshot et compte à rebours de redéploiement ; causes environnementales sans faux tireur ; réception tardive des attributs prise en charge.
- [x] Carte cachée à la réapparition et durant le podium officiel. Nettoyage des abonnements entre personnages.
- [ ] Vérifier dans Roblox Studio et sur Android : affichage lors de morts rapides, temps de retour Roblox réel, chevauchements du HUD et latence réseau. La CI ne peut pas certifier le rendu en jeu.


## 6 novembre 2026 — réapparitions tactiques protégées

- [x] Un choix de réapparition évalue désormais la **distance réelle aux combattants** et leur **ligne de tir non masquée** ; le décor sans collision n'est pas considéré comme un abri.
- [x] Un candidat libre derrière une couverture solide est favorisé par rapport à une position exposée de distance comparable. Un ennemi à proximité immédiate reste fortement pénalisé, même si la position est cachée.
- [x] Les 12 points de réapparition existants restent prioritaires, sans modifier la géométrie de l'arène ; un point central validé sert de secours lorsqu'ils sont tous bloqués.
- [x] Les calculs de visibilité sont effectués **uniquement au spawn**, limités aux combattants situés à moins de 165 studs. Aucun raycast supplémentaire sur les boucles IA/HUD.
- [x] Scoring testable sous Luau dans la CI ; la protection temporaire de 2,5 secondes et son annulation au tir sont préservées.
- [ ] Vérifier les spawns physiques depuis Studio sur PC et Android, notamment plusieurs morts simultanées, coins de conteneurs et nouveaux MeshParts.


## 6 novembre 2026 — stations médicales tactiques interactives

- [x] Quatre bornes médicales 3D aux abords des couloirs nord et sud, utilisant une interaction native Roblox accessible au clavier et sur mobile.
- [x] Soin jusqu'à 40 PV, uniquement pendant LIVE, sur joueur vivant et réellement blessé, avec contrôle de distance et cooldown partagés par station côté serveur.
- [x] Indicateurs READY/RECHARGING répliqués, audio localisé, confirmation HUD individuelle, remise à disponibilité en début de manche avec protection contre les anciens temporisateurs.
- [x] Aucune collision, aucun CanQuery et aucun nouveau raycast pour les bornes, afin de ne pas modifier les tirs, les couvertures ou le pathfinding.
- [x] Règles pures vérifiables avec script Luau dans la CI, compilation Rojo complète.
- [ ] Vérification réelle Roblox Studio et Android : accessibilité tactile, lisibilité à plusieurs distances, placement, rythme de soin et coût GPU/CPU.


## 6 novembre 2026 — IA de duel moins mécanique

- [x] Points de déplacement de combat stabilisés 1,65 s : flancs/repli/avance choisis sur le sol et au niveau du bot, jamais par simple changement continuel de cible de MoveTo.
- [x] Trois directions candidates au maximum par calcul ; cache des recherches infructueuses, cadence de replanification plafonnée à 0,7 s lorsque la position adverse vérifiée évolue rapidement.
- [x] Le comportement dépend de la distance (approche à longue portée, strafing à mi-distance, recul au contact) et du côté de déplacement ; l'IA conserve son comportement défensif prioritaire lors de dommages/recharge.
- [x] Le serveur n'ouvre le feu que lorsque la visée interpolée correspond suffisamment à la cible visible, avec exigence accrue à longue distance ; cadence et dégâts restent inchangés.
- [x] Tests exécutables sur les règles sans services Roblox, reliés à la CI Luau/Rojo.
- [ ] Validation Studio/Android avec plusieurs combattants : mouvements de côté, conteneurs, coins de couverture, précision, temps d'engagement, coûts de pathfinding et animations en situation.


## 6 novembre 2026 — IA : mémoire correcte et stations contestées

- [x] Attribution atomique de la cible et de sa dernière position réellement visible, contre les poursuites d'un adversaire différent.
- [x] Les cibles cachées ne livrent plus leur position courante ; ancienne observation conservée au plus 2,2 s.
- [x] Bots blessés (≤ 48 % HP) attirés par les stations de soin disponibles à courte distance lorsque l'ennemi n'est plus visible ; couverture tactique prioritaire.
- [x] Réserve de soin serveur partagée entre humains et IA, distance réduite et rayon contre le soin à travers les murs pour les bots ; pas de magie ni de collaboration FFA.
- [x] Régressions Luau du choix de cible, de la mémoire visuelle et des seuils de soin branchées dans GitHub Actions.
- [ ] Vérifier en Roblox Studio et sur Android : concurrence aux stations, poursuite en entrepôt, tirs visibles, risque de camping, équilibre des soins et navigation.


## 6 novembre 2026 — récupération IA aux stations de soins

- [x] Sélection d'objectif médical stabilisée 2 secondes (réduit les oscillations entre deux stations).
- [x] Échec de mouvement : exclusion temporaire (14 s) de la borne inaccessible, puis possibilité d'un autre itinéraire.
- [x] Prise en compte des positions adverses **déjà vues** pour éviter les bornes dangereuses ; aucune lecture de position de joueur caché.
- [x] Abandon du chemin de soin lors du retour au combat et réinitialisation des objectifs au début de manche.
- [x] Règles pures et scénarios d'échec intégrés à GitHub Actions.
- [ ] À vérifier dans Roblox Studio et sur Android : bots bloqués autour des conteneurs, temps d'accès, choix alternatif, priorité des cibles et performance.


## 6 novembre 2026 — combat défensif contre les obstacles

- [x] Retraites IA parmi six positions validées, priorité à une couverture solide au lieu d'une exposition inutile.
- [x] Exclusion temporaire (8 s) d'une couverture ayant réellement bloqué le bot ; nouvelle tentative sur un autre chemin.
- [x] Contrôles du sol sur trois portions de la trajectoire de couverture et quatre points d'anticipation de la marche directe, pour réduire les chutes aux passerelles.
- [x] Raycasts IA cohérents avec la géométrie physique (`RespectCanCollide`), sans intervention dans les hitboxes du FPS.
- [x] Tests de stratégie de repli et vérification complète Rojo/Luau dans la CI.
- [ ] Scénarios Studio et Android : coins de conteneur, couverture après blessure, comportement de rechargement et coût CPU de quatre bots.


## 7 novembre 2026 — déblocage fondé sur les vrais waypoints

- [x] Moniteur de progression relatif au point MoveTo effectivement commandé, pour détecter un bot qui glisse latéralement le long d'un mur sans avancer vers son objectif.
- [x] Critère de déblocage : progression minimale 1,15 stud sur 2,8 s, avec réinitialisation sur changement de waypoint/arrivée.
- [x] Protection du calcul de chemin asynchrone et fenêtre de grâce de 4,5 s dans l'état WAIT ; conservation des exclusions de couverture et de station médicale quand le blocage est réel.
- [x] Régression Luau exécutable et adaptation des contrats statiques de navigation intégrées à GitHub Actions.
- [ ] Mesures Roblox Studio/Android à obtenir : taux de bots coincés, fréquence des changements PATH/WAIT/AVOID, coûts serveur et fluidité du déplacement physique.


## 7 novembre 2026 — recherche des tirs entendus

- [x] Détection des seuls tirs réellement validés par le serveur ; aucun événement de perception émis directement par les clients.
- [x] Enquête des bots sur une zone **approximative** quand aucune cible n'est visible et qu'une ancienne piste visuelle n'est plus pertinente.
- [x] Portées différenciées par arme, mémoire sonore de 5,4 s plafonnée à 12 événements, fusion des rafales pour éviter la croissance CPU/mémoire.
- [x] Stabilisation du déplacement sonore sur 1,8 s, respect de la navigation serveur, mémoire réinitialisée à la nouvelle manche.
- [x] Tir strictement interdit sans observation visuelle : aucun tir ni dégât issu du son seul. Règles de sélection testées en Luau et branchées sur le build.
- [ ] Tester en session multijoueur Studio/Android : bruit derrière couverture, réponses à la distance, FFA bots contre bots, durée de recherche et équilibrage.


## 7 novembre 2026 — recherche sonore autour de la dernière zone entendue

- [x] Enquête en trois étapes : zone sonore approximative, flanc gauche, flanc droit, avec destinations validées au sol et navigation serveur.
- [x] Poursuite d'une enquête déjà ouverte malgré l'expiration des événements sonores, limitée globalement à 17 s ; chaque étape possède un délai strict.
- [x] Véritable blocage de waypoint : passage à l'étape suivante ; dernière ID événementielle ignorée pour empêcher les boucles sans nouvelles preuves.
- [x] Annulation immédiate de l'enquête à l'acquisition d'un adversaire et remise à zéro entre manches ; aucun ciblage à partir du bruit seul.
- [x] Régressions Luau de phase/durée/expiration intégrées à GitHub Actions et documentation QA ajoutée.
- [ ] Test en Roblox Studio et sur Android des chemins réels dans l'entrepôt, de la précision sonore, de l'équilibre FFA et de l'absence d'omniscience.


## 7 novembre 2026 — acquisition de cibles et réaction aux agressions

- [x] Les cibles non visibles ne sont plus évaluées à partir de leur distance actuelle cachée ; seule la dernière position serveur réellement observée est utilisable pendant 2,2 s.
- [x] Sur un tir reçu et confirmé, bonus temporaire (2,8 s) au candidat visible proche de l'origine du tir ; aucun bonus à une cible invisible.
- [x] Protection contre les faux couples cible/position : une cible dite visible doit porter sa position associée.
- [x] Régressions Luau et contrôle de contrat source dans le pipeline GitHub Actions.
- [ ] Mesurer en jeu la fréquence des changements de cible et la capacité de riposte dans le dos, et tester l'absence de pistage invisible sur Android/Studio.


## 7 novembre 2026 — duels FFA stables et repositionnement après rafale

- [x] Engagement minimal de 1,35 s sur une cible visuellement confirmée, avec marge de sélection pour limiter les oscillations toutes les 0,2 s.
- [x] Priorité immédiate conservée aux menaces urgentes visibles ; une cible cachée ne peut jamais exploiter le verrouillage.
- [x] Repositionnement tactique après trois tirs acceptés : maximum une fois par 2,8 s, si la distance, la santé et les possibilités de mouvement s'y prêtent.
- [x] Réutilisation des raycasts de navigation habituels ; pas de travail de physique supplémentaire par balle ni de trajet à travers la géométrie.
- [x] Tests Luau supplémentaires et vérifications des contrats de combat intégrés au build.
- [ ] Vérifier en Studio et Android l'efficacité des changements de cible, le mouvement entre les rafales et les animations physiques avant déploiement Roblox privé.


## 7 novembre 2026 — animation des rotations et inversions réelles

- [x] Torse, tête, épaules et jambes réagissent à une vraie rotation de chassis, même sans déplacement horizontal.
- [x] Inversion constatée dans la vitesse physique : freinage dynamique, amplitude de foulée réduite et pose des pieds plus cohérente.
- [x] Lissage des transitions compatible avec l'animation 15 Hz de proximité / 8 Hz distante, sans nouvelle animation importée ni Part réseau.
- [x] Nettoyage des impulsions de rotation à chaque nouvelle manche, sans inertie visuelle persistante après téléportation de spawn.
- [x] Tests Luau et contrats statiques adaptés, exécution automatique par GitHub Actions.
- [ ] Valider visuellement sous Studio/Android les accessoires soudés, les demis-tours et les rotations, puis calibrer les amplitudes selon la perception en jeu.


## 7 novembre 2026 — animation d'impacts et appui derrière couverture

- [x] Recul directionnel suivi d'un rebond opposé court (moins de 0,5 s), avec cohérence des épaules, du torse et de la tête.
- [x] Transition « low-ready » lors de l'approche physique d'une couverture et posture d'appui quand le bot s'est effectivement arrêté près de celle-ci.
- [x] Pas de hitbox réduite, d'effet de dégâts fictifs, de nouvelles Parts ni de requêtes physiques par image ; calculs dans la pose R6 existante.
- [x] Réinitialisation des nouveaux états d'animation entre manches, tests Luau étendus et contrôles statiques ajustés.
- [ ] Vérification Roblox Studio/Android impérative : perception visuelle des impacts et des couvertures, collisions des armures/accessoires, FPS sur mobile et équilibre du duel.


## 7 novembre 2026 — impacts confirmés et dispersion visuelle du shotgun

- [x] Éclat 3D local du contact uniquement pour le tireur, après réduction effective des points de vie vérifiée par le serveur ; variantes corps/tête/élimination.
- [x] Le shotgun affiche aussi un maximum de trois impacts supplémentaires sur le décor à partir de raycasts serveur réels : un effet en ECO, deux sur mobile BALANCED et trois en QUALITY.
- [x] Aucun nouvel événement réseau, aucune position d'adversaire caché diffusée, ni modification des dégâts, hitboxes ou cadence.
- [x] L'auteur d'un tir n'affiche pas deux fois son traceur central : prédiction locale conservée, confirmation serveur pour les impacts secondaires.
- [x] Tests des budgets VFX et contrats de gameplay étendus dans la CI.
- [ ] Vérifier dans Roblox Studio et Android : lisibilité des headshots, du shotgun sur métal/béton/bois, coûts GPU et durée des effets selon ECO/BAL/HIGH.


## 7 novembre 2026 — combat rapproché et éliminations lisibles

- [x] Traceurs à très courte distance : segment mobile sur 36 % du trajet au lieu d'une barre lumineuse immobile, longueur plafonnée à 29 studs.
- [x] Le filtre des confirmations d'impact privilégie les éliminations réellement vérifiées, même lorsqu'un projectile de shotgun a déclenché un éclat dans les 110 ms précédentes.
- [x] Réduction de l'échelle des éclats de touche à moins de 7 studs, avec un seul petit éclat au corps-à-corps.
- [x] Confirmation HUD sous le viseur pendant 0,85 s et marqueur central compact ; les impacts normaux ultérieurs ne masquent pas prématurément le sous-titre.
- [x] Régressions Luau sur distances, limites mobiles et priorité de confirmation, contrats de source et build Rojo.
- [ ] Contrôler dans Studio/Android la lisibilité à 568×320, les duels à bout portant et les collisions visuelles avec les médailles existantes.


## 7 novembre 2026 — séquence de mort premium des bots

- [x] Remplacement de la simple pose de recul par une chorégraphie R6 non physique en trois étapes : impact, affaissement, stabilisation (~0,91 s), orientée par la dernière direction du dégât confirmée.
- [x] Suppression immédiate de l'étiquette au-dessus des éliminés et des collisions/ray queries du modèle mort ; racine ancrée pendant l'animation et nettoyage à 2,5 secondes inchangé.
- [x] Petite poussière de contact créée exclusivement côté client, après vérification ponctuelle du sol ; 1 à 4 parts selon la qualité graphique et distance de visibilité limitée.
- [x] Gestion des changements de manche avec tâches temporisées qui refusent d'animer un modèle détruit ; aucune nouvelle remote ni modification de gameplay.
- [x] Tests de durée, direction, invalides, budget mobile et contrats d'intégration ajoutés à la CI.
- [ ] Valider l'effet dans Roblox Studio sur Android, notamment catwalks, armures R6, angle du corps, durée de visibilité et passage des tirs à travers un bot mort.


## 7 novembre 2026 — ambiance industrielle visible, contrôlée sur Android

- [x] Quatre groupes d'extraction sur le toit principal, avec des lames de ventilation métalliques réellement visibles ; toute la géométrie est décorative, sans raycast ni collision.
- [x] Marquage des bases d'extracteurs à l'aide d'un attribut serveur stable ; animation de vapeur émise exclusivement côté client, au-dessus des conduits, sans texture externe ni réseau supplémentaire.
- [x] Sélection des plus proches émissions selon les présélections graphiques : aucune en ECO, **1** en BALANCED mobile, **2** en QUALITY mobile, **2** sur PC BALANCED et **4** sur PC QUALITY.
- [x] Particules très transparentes et à vie courte (moins de 1,3 s), désactivées hors distance ; aucune modification des hitboxes, de la visibilité serveur, de la navigation ou des dégâts.
- [x] Nettoyage des anciens luminaires locaux lorsque leurs pièces sont supprimées ou remplacées, pour éviter l'accumulation après de longues sessions.
- [x] Régressions sur budgets, classement des sources, valeurs invalides et protections des éléments cosmétiques en CI.
- [ ] Validation visuelle dans Roblox Studio/Android : quatre vents, visibilité des joueurs en face de l'échappement, clipping des louvers, ECO/BAL/HIGH, 30/60 FPS et température du téléphone.


## 7 novembre 2026 — habillage métallique des murs et éclairage ciblé

- [x] Remplacement visuel des faces internes uniformes de l'entrepôt par **8 grandes plaques de métal embouti** avec plis, renforts verticaux, plinthes, rivets et patine légère, toutes positionnées à l'intérieur des murs de collision existants.
- [x] Façade de la cloison nord complétée avec **3 quais intérieurs clairement indiqués « SEALED »** ; aucune fausse ouverture, collision, cover ou chemin de navigation.
- [x] Nouvelles articulations des matériaux en métal zinc / acier graphite / oxydation contrôlée. Les éléments Core conservent les volumes principaux en ECO ; les détails mineurs profitent du LOD existant.
- [x] Luminaires de l'entrepôt plus chauds, éclairage des passerelles plus neutre/froid ; chaque rôle est piloté par un profil pure Luau, avec limites d'intensité et de portée, sans lampes supplémentaires.
- [x] Changement ECO/BAL/HIGH actualisant les paramètres sur les spots locaux existants, sans accumuler de nouvelles instances.
- [x] Tests des coordonnées face aux murs originaux, des niveaux d'éclairage et des budgets ; contrats de sécurité des géométries dans la CI.
- [ ] Vérification de rendu Roblox Studio/Android : façade intérieure sur les 2 côtés, lisibilité des trois quais, collision des projectiles sur les mêmes murs, angle des lights, 30/60 FPS et comportement LOD.


## 7 novembre 2026 — surfaces de conteneurs et asphalte, fidélité native

- [x] Habillage de **8 conteneurs existants** à partir des coordonnées exactes des collisions MapService ; bandes de sécurité peintes lisibles, oxydation translucide au bas des flancs et quatre coins renforcés haut/bas, sans ajouter de collision.
- [x] Ajout de bandes de maintenance métalliques DiamondPlate sur les toitures, visibles depuis les plateformes élevées, et de repères de sécurité sur les deux portes d'extrémité.
- [x] **12 réparations d'asphalte** dans les voies de circulation latérales, chacune bordée d'un joint discret ; matériaux Roblox natifs, aucune texture ni ID payant.
- [x] Réutilisation du dossier décor NeonStrikeDecor et du marquage NeonArtTier : sections principales en Core, usure, détails de toiture et patches en Detail, retirés localement à distance en ECO/mobile.
- [x] Aucun collider ni raycast serveur ajouté : tous les panneaux sont ancrés avec CanCollide=false, CanQuery=false, CanTouch=false, CastShadow=false ; tests de coordonnées, dimensions et intégration à la CI.
- [ ] Tester le rendu en Studio/Android : bandes visibles de 20–90 studs, décalage avec les nervures et portes, plaques sur toiture, patine sur les peintures existantes, patches près des obstacles et frame pacing avec 4 bots.
- [ ] Remplacer à terme les matériaux natifs par des textures PBR réellement publiées et configurées ; les cartes sources produites ne sont pas encore activées dans le jeu.


## 7 novembre 2026 — activation contrôlée des vrais matériaux PBR de l'arène

- [x] Infrastructure Roblox MaterialVariant : acier des conteneurs, métal de l'entrepôt et asphalte, chacun avec quatre cartes PBR 1K prévues.
- [x] Activation serveur uniquement quand les 12 images Roblox ont des IDs valides et un propriétaire vérifié ; le registre initial nul conserve les matériaux natifs.
- [x] Application ciblée aux huit vrais conteneurs, au sol et aux grandes tôles de l'entrepôt, sans nouvelle hitbox ni navigation.
- [ ] Générer et publier les images Roblox après autorisation Open Cloud, puis vérifier le chargement et les performances Android dans Studio.


### Chaîne PBR 1K de l'arène — génération et import contrôlé

- [x] Générateur Python déterministe : 12 PNG RGBA8 1K (3 matériaux × ColorMap/NormalMap/RoughnessMap/MetalnessMap), relief de tôles et grain d'asphalte, empreintes SHA256.
- [x] Workflow GitHub Actions indépendant produisant archive/artifact des textures à partir du dépôt, sans clé Roblox ni crédits externes.
- [x] Importeur Open Cloud Image : validation des CRC PNG et pixels RGBA8, 1024×1024, SHA256 et plafond 20 Mo ; uploads suivis par modération et propriétaire, checkpoint et activation seulement lorsque les 12 sont confirmés.
- [x] Workflow d'import sûr par défaut en dry-run. Le véritable upload nécessite le secret ROBLOX_OPEN_CLOUD_ASSETS_KEY et le choix explicite publish_assets.
- [x] Tests sur les images, les lots incomplets et la non-modification du registre en dry-run, intégrés au build Rojo.
- [ ] Assets non encore uploadés dans Roblox : IDs nuls. Après publication autorisée, vérifier la résolution des MaterialVariant, l'apparence et la performance dans Studio et Android.


## 7 novembre 2026 — continuité des textures PBR à répétition

- [x] Audit des douze cartes PBR de l'environnement : la première version utilisait des normales aux bords clampées et des grains aléatoires non raccordés, pouvant former des coutures visibles quand Roblox répète le matériau.
- [x] Réconciliation déterministe des deux bords de chaque carte Color/Roughness/Metalness et du relief avant calcul des normales ; normales calculées avec échantillonnage périodique, sans rupture artificielle sur les bords.
- [x] Vérification automatique des bords des 12 PNG réels (4 canaux × 3 matériaux) à petite résolution, en plus des hashes SHA-256 et de l'inspection PNG 1K existantes.
- [ ] La publication effective des 12 images nécessite la clé Open Cloud Assets du propriétaire et la modération Roblox ; aucune activation de PBR tant que les IDs approuvés ne sont pas enregistrés.


## 7 novembre 2026 — contrôle physique et aperçu inspectable des 12 cartes PBR

- [x] Correction de la métallisation de la peinture des conteneurs : la couche peinte est majoritairement **diélectrique** (non métallique) ; les rares rayures et éclats dévoilent une surface métallique sous-jacente, avec leur propre rugosité ; zones d'oxydation mates.
- [x] L'acier structurel reste métallique ; l'asphalte reste fortement rugueux et non métallique. Bords des textures raccordés et normales périodiques conservés.
- [x] Nouvel audit Python **sans dépendance externe**, décodant les douze PNG réels : vérification SHA-256, CRC, dimensions, coutures, contraste, métallicité et rugosité propres à chaque matériau.
- [x] Prévisualisation 4 colonnes × 3 lignes des cartes PBR sous forme d'un PNG inspectable dans chaque artifact et release GitHub, avec rapport JSON de métriques et convention de colonnes/lignes stable.
- [x] Contrôle de qualité intégré **avant** tout téléchargement/activation de textures Roblox via le workflow propriétaire ; image de peinture artificiellement métallique même avec manifeste resigné rejetée par régression.
- [ ] Le moteur Roblox n'appliquera les textures que lorsque le propriétaire aura réellement importé/modéré les 12 images et activé les ID sur le jeu publié ; validation Studio/Android non effectuée.


## 8 novembre 2026 — cinq palettes de fret : trois silhouettes 3D réellement distinctes

- [x] Remplacement du traitement visuel uniforme des cinq palettes de fret par trois familles à forte lisibilité : **caisses export en bois croisillonné**, **colis filmés/cerclés** et **module de fret en cage métallique**.
- [x] Les cinq groupes ne sont plus positionnés à partir d'une seconde liste de coordonnées figées : les décors sont créés directement depuis les **cinq colliders autoritaires** de MapService, en reprenant leur CFrame et dimensions.
- [x] Plaques d'identification visibles sur chaque cargo ; une silhouette Core persistante en ECO, et petits renforts/transparences de film supprimés à distance par le LOD Android existant.
- [x] Toute la géométrie additionnelle est ancrée, non traversante pour les raycasts, sans collision, touch ou nouvelle Remote ; aucun art ne peut changer les couvertures, le déplacement ou l'IA.
- [x] Tests Luau des cinq identifiants, trois styles, dimensions réelles de colliders, variantes invalides ; contrôle statique de l'intégration et build Rojo.
- [ ] Vérifier visuellement dans Roblox Studio/Android : silhouettes distinctes à 20-80 studs, faces de cargo, rotations, alignement de collision, ombres, contraste des labels et budget sur mobile.
- [ ] Les modèles 3D importés et textures PBR restent bloqués par les identifiants Roblox propriétaires, le rendu 3D natif est un fallback jouable et non un modèle importé.
