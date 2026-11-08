# IRON YARD — Audit global du produit et du dépôt
Date : 8 novembre 2026
Dépôt : dbrckk/Roblox-shooter — branche main
Révision inspectée : 195a8f033a5f3277f39757eb60165585ed540e46
Dernière CI verte inspectée : https://github.com/dbrckk/Roblox-shooter/actions/runs/42498725872

## Méthode et limites

Audit du code et des configurations réellement présents sur GitHub. Inventaire complet : 172 fichiers versionnés (hors répertoires), 123 fichiers Luau, 33 modules serveur, 19 modules client, 37 modules partagés, 34 suites de tests Luau, 8 workflows Actions, 7 contrôles Python ciblés. Inspection approfondie des chemins de tir et de mouvement, bots, manches, progression, HUD, art, assets, autorisation, pipelines et livraison.

Le retour de l'utilisateur indique que les fonctionnalités existantes fonctionnent. Ce retour est retenu comme validation fonctionnelle de référence, sans annoncer de métriques non mesurées. Le dernier workflow Rojo a compilé les sources, exécuté ses tests et généré un fichier rbxlx, mais ne mesure pas les FPS, la latence, l'équilibrage, l'ergonomie ou les DataStores en session Roblox réelle.

Les constats sont classés : **confirmé dans le dépôt**, **risque technique démontrable par le code**, **non vérifiable sans exécution Roblox**, **écart de produit**. Les mentions de qualité/AAA sont des objectifs, pas des résultats certifiés.

## Synthèse exécutive

Le jeu ne doit plus être traité comme une expérimentation à fonctionnalités multiples. Un FPS de base jouable existe : cinq armes, serveur autoritaire pour dégâts et munitions, déplacements rapides, manches FFA, bots tactiques, soins, réapparitions, progression, retours de combat, HUD tactile, décors industriels et outils de performance.

La feuille de route ancienne dépasse 60 Ko de notes chronologiques, mêle décisions passées, expérimentations et conditions de livraison. Cette accumulation rend la priorité réelle peu lisible. La nouvelle feuille de route est désormais docs/ROADMAP_V2_PUBLIC.md, qui doit rester la source priorisée et vérifiable.

Les cinq axes à plus fort effet client sont :
1. Livraison réellement déployée, sûre et reproductible.
2. Vraies silhouettes/meshes et matériaux premium activés dans l'expérience.
3. Première minute de jeu et clarté des objectifs, des combats et des commandes.
4. Identité sonore, animations et sensations des armes/bots.
5. Rétention et nouvelle boucle multijoueur, seulement après stabilisation du FFA.

## Audit par domaine

### 1. Combat et arsenal — socle solide, finition à approfondir

Confirmé : src/shared/WeaponConfig.luau déclare cinq armes (fusil automatique, pistolet, shotgun 8 pellets, sniper, couteau projectile). src/server/WeaponService.luau impose cadence, munitions, rechargement, validations de vecteur, protection au spawn, dégâts, pellets et manche LIVE. src/client/WeaponVisuals.luau fournit modèles en première personne, recul, flash, trace, impacts et feedback.

Écarts : pas de budget de TTK et répartition des armes mesuré ; le pistolet a 100 dégâts en headshot, le sniper 150 et le couteau 100, ce qui appelle un équilibre par distance/skill. Sonorités encore construites autour de fichiers Roblox internes génériques snap/bass/electronicpingshort. Les modèles d'armes restent essentiellement en Parts originales ; il faut un gain visuel franc, pas seulement des accessoires.

Amélioration : test d'équilibrage par scénarios (corps, tête, couvertures, 20/50/100 studs), animations mécaniques cohérentes et mixage original licencié. Ne pas ajouter une sixième arme tant que le noyau n'est pas calibré.

### 2. Déplacements — riche, potentiellement exigeant à maîtriser

Confirmé : sprint, glissade, impulsions, saut de glissade, boost, wallrun, mantle, contrôles PC/mobile, code serveur src/server/MovementService.luau et règles src/shared/MovementConfig.luau. Le serveur limite plusieurs actions par cooldown, géométrie et états.

Écarts : accumulation d'actions avancées difficile à apprendre pour une première partie Android ; absence de parcours de maîtrise progressif clairement matérialisé. La boucle Heartbeat traite mouvement et régénération, avec notifications au client ; sous montée de joueurs, limiter allocations et publications redondantes.

Amélioration : onboarding bref intégré au gameplay, réglages de commandes tactiles, gestion prioritaire des inputs, tests de transitions boost-wallrun-mantle. Pas de changement des physiques fondamentales sans preuve de régression.

### 3. IA et navigation — système avancé, surveillance de coût nécessaire

Confirmé : src/server/BotService.luau, BotNavigation, BotTactics, BotHearingService, BotAnimation, BotPerfService. Reconnaissance de cibles par raycasts, mémoire des adversaires vus, gestion du couvert, comportement aux blessures, recharge, recherche sonore, déblocage, sorties de pathfinding asynchrones, animations R6 15/8 Hz. Quatre bots au maximum, décision tactique 5 Hz.

Risque technique : BotPathBudget libère automatiquement les réservations après 5,8 s, même si un ComputeAsync sous-jacent n'a pas encore terminé. La garantie affichée « deux calculs actifs maximum » est donc une limite de tickets en cours, pas une preuve de stricte limite de requêtes moteur simultanées après expiration. Traiter les tâches orphelines et la replanification avec une politique explicite de dégradation et de métrique réelle.

Écart produit : les quatre bots améliorent le solo et les petites sessions mais ne remplacent pas une vraie population de joueurs ni l'équité de matchmaking. Les bots doivent être identifiés comme bots.

### 4. Manches, modes et multijoueur — plus grand écart gameplay

Confirmé : src/server/MatchService.luau ne contient qu'une boucle FFA, avec COUNTDOWN 6 secondes, LIVE 240 secondes, RESULTS 12 secondes, victoire à 15 éliminations. BotConfig limite à quatre bots et six combattants au total. Score, podium et rematch automatique existent.

Absent dans le code actuel : vrais salons de duels, équipes, 1v1 à 5v5, matchmaking, spectateur complet et transition de mode explicite. La vision game/VISION.md annonce ces modes ; il s'agit donc d'objectifs non livrés, pas de bugs de FFA.

Amélioration : garantir d'abord une boucle FFA excellente et reproductible, ensuite développer un **seul mode de duel 1v1** original avec séparation stricte de l'état de match et du score. Les formats 2v2–5v5 suivent seulement après validation de 1v1.

### 5. Progression et fidélisation — logique sérieuse, produit incomplet

Confirmé : ProgressionService et ProgressionLedger utilisent UpdateAsync, jetons de session, bail, autosave 45 s, retry, retrait en sortie, inventaire XP/headshots/victoires. Les fichiers docs/PROGRESSION_PERSISTENCE.md explicitent la distinction entre session et sauvegarde persistante.

Limite : les tests automatisés vérifient le Ledger pur et les contrats source, pas un aller-retour DataStore Roblox en serveur publié. Pas de rétention long terme par objectifs quotidiens, contrats de maîtrise d'armes, collection cosmétique cohérente ni télémétrie d'abandon.

Amélioration : conserver le stockage déjà conçu, assurer la migration/sécurité des enregistrements, puis ajouter des objectifs non pay-to-win et des skins déverrouillables sans toucher aux dégâts.

### 6. Interface et onboarding — riches, mais trop fragmentés

Confirmé : 19 modules/scripts côté client, Briefing, MatchHud, TacticalHud, HudController, ProgressionHud, RoundResults, DefeatScreen, KillFeed, DamageDirection, MedicalFeedback, PerfOverlay et autres. Le briefing indique « first to 15 ». Sur mobile le tableau des trois premiers est masqué, car il occupait trop l'écran.

Écarts : interface repartie dans plusieurs ScreenGui et contrôleurs, avec risques de collisions de positions selon ratios 16:9, 20:9, petits écrans et encoches. Le briefing est bref, pas un vrai apprentissage en 45–60 secondes. Le panneau PERF est correctement réservé au diagnostic et ne doit jamais devenir un élément public.

Amélioration : hiérarchie HUD unique, disposition dynamique à petite résolution, retour clair après mort, aide de déplacement non intrusive, commandes repositionnables, bascule accessibilité, états de chargement/sauvegarde compréhensibles.

### 7. Carte, architecture et lisibilité — beaucoup de travail natif

Confirmé : MapService (arène 356x356), ArenaArt et modules dédiés (WarehouseCladding, CatwalkDeckArt, CoverArt, FreightSurfaceArt, ForkliftDetailArt, YardWayfindingArt). Signaux de secteur, plateformes, palettes, contenants et chariots. Art procédural non-collisionnel avec différents tiers LOD ; le gameplay conserve ses propres colliders.

Écart : beaucoup de micro-Part natives et de matériaux sans vrai relief PBR. L'art est plus varié qu'au début du projet, mais la silhouette et l'identité premium dépendent de véritables modèles optimisés et de leur rendu réel. Prioriser une correction par grand élément perçu (entrepôt, opérateur, arme, surface de sol), pas par nouveaux petits rivets.

### 8. Pipeline 3D/PBR — production solide, intégration finale bloquée

Confirmé : workflows Blender/assetforge, contrôles des GLB et PNG, archives GitHub Releases, 4 palettes VANGUARD et 3 matériaux PBR à quatre canaux, résolutions 1K, rapport qualité des textures.

Confirmé : src/shared/VanguardAssetIds.luau contient quatre ID à 0 ; src/shared/WorldPbrAssetIds.luau contient douze ID à 0. La scène Rojo ne peut donc pas afficher le kit final sans import et validation propriétaire. Le fallback visuel garantit la jouabilité.

Amélioration : terminer un seul parcours d'import propriétaire, approbation/mise en ligne, activation validée, fallback sûr et calibration des tailles, UV, normales, textures et performance Android. Ne pas continuer à produire de nouvelles dizaines d'assets non activés.

### 9. Éclairage, effets et audio — visuel fonctionnel, signature limitée

Confirmé : EnvironmentLighting, CombatVfxProfile, WeaponVisuals, ExhaustAmbient, IndustrialMotion et effets de marqueurs/tirs. Les effets de tirs éloignés sont restreints selon ECO/BALANCED/QUALITY.

Écarts : absence d'une preuve visuelle standardisée des trois profils sur le jeu publié ; effets limités par allocation répétée de Parts/Tweens durant les combats ; sons d'armes majoritairement génériques. Aucune mesure objective du rendu sous plusieurs expositions, contrejours et densités de tir.

Amélioration : construire un ensemble cohérent d'effets matériels et de sons originaux légalement utilisables, puis mesurer allocations/latence mémoire à quatre bots en combat.

### 10. Performances — outils présents, objectifs non quantifiés

Confirmé : ArtLODPolicy cellules 48 studs, RenderStepped local, budgets CombatVfxProfile, BotPathBudget, BotPerfProfile et bouton PERF propriétaire/Studio. Les compteurs se regroupent en 5 secondes.

Limite : les fenêtres de 5 s et les calculs locaux de FPS ne sont pas des mesures externes du CPU total ni du GPU Roblox. Le temps ComputeAsync reporté mesure l'attente écoulée, non l'occupation CPU. Aucune campagne reproductible de bas/moyen de gamme Android et PC n'est archivée dans le dépôt.

Amélioration : créer une procédure automatique de collecte reproductible, 4 scénarios (repos, 4 bots, tir dense, déplacement rapide), seuils FPS/stabilité et comparaison avant/après avec même matériel.

### 11. Sécurité et réseau — bonne approche serveur, durcissement à faire

Confirmé : décisions de dégâts, rechargement, progression, récompenses, soins et trajectoires de bots côté serveur ; contrôle de vecteurs finis, états de manche, protections anti-spawn-kill, restrictions d'assets propriétaire et panneau de performance autorisé par créateur.

À auditer et renforcer : les handlers d'équipement et SetSprinting peuvent recevoir de nombreux événements de clients et republier des états sans frein indépendant par origine. Les autres remotes de mouvements doivent être vérifiés pour quotas et rafales de payloads. Ce n'est pas une vulnérabilité exploitée démontrée ; c'est un risque de saturation/abus à éliminer avant promotion publique.

Amélioration : budgets de fréquence par RemoteEvent et joueur, validation stricte des états, journal limité d'anomalies, aucune confiance accordée aux dommages, points de tir ou captures du client.

### 12. Qualité et intégration continue — forte pour Luau statique

Confirmé : 34 tests Luau dans scripts, vérifications Python, compilation de toutes les sources, tests d'assets PBR et build Rojo sur push/PR. Le run 42498725872 est vert et conserve iron-yard.rbxlx en artifact GitHub 14 jours.

Limite : absence de test moteur Roblox en CI ; aucune capture golden visuelle de l'UI ou analyse de physique/réplicas réelles. Plusieurs vérifications source s'appuient sur des recherches de chaînes sensibles au refactoring. Les docs/ROADMAP.md enregistrent chronologiquement beaucoup de travaux déjà finis et ne forment pas un plan de livraison actif.

Amélioration : conserver ces tests, remplacer progressivement les contrôles fragiles par tests comportements exécutables, ajouter un protocole Studio reproductible et mesurer erreurs serveur/client après publication.

### 13. Publication et découvrabilité — blocage opérationnel visible

Confirmé : seul le build Rojo est automatique. Le workflow publish-roblox-private.yml autorise un upload MANUEL dans une expérience privée IRON YARD déjà créée, sans mise en visibilité publique. Le dernier run CI a affiché :
- Open Cloud authorization : NOT CONFIGURED ;
- IRON YARD universe destination : NOT CONFIGURED ;
- IRON YARD starting place : NOT CONFIGURED.

Aucun run manuel de publication n'était listé dans l'historique interrogé. Ne pas présenter les fichiers rbxlx ou les GitHub Releases d'assets comme une publication de l'expérience.

Écarts : packaging public (icône, vignettes Roblox, description, mots clés, capture mobile, page de bienvenue, contrôle d'âge/contenu), canal distinct de staging et de production, processus de rollback propriétaire et contrôle postpublication. Aucun fichier créatif prêt à publier n'apparaît dans le dépôt actuel.

### 14. Maintenabilité, identité et licences

Points positifs : configuration Rojo explicite, logique pure Luau extractible, fichiers dédiés par service, test CI, licence MIT existante et preuve de l'analyse REA d'un FPS open source autorisé. Les décors et armes sont décrits comme originaux.

Faiblesses : src/client/init.client.luau dépasse 1 300 lignes, BotService approche 1 000 lignes, MovementService 745 lignes, WeaponService 619 lignes, WeaponVisuals plus de 800 lignes. Les noms internes NeonStrike historiques subsistent pour compatibilité. Ces tailles compliquent l'évolution des modes et des contrôles, mais ne justifient pas une réécriture aveugle.

Le document docs/REFERENCE_ANALYSIS.md contient encore une direction science-fiction/néon devenue obsolète : normaliser la documentation vivante, sans casser les chemins historiques du code.

## Comparaison de positionnement (principes, non clonage)

- RIVALS official : https://www.roblox.com/games/17625359962/RIVALS — duels 1v1–5v5, premier à cinq manches, contrats, récompenses, classements et déblocages. IRON YARD ne dispose pas de ces modes, mais a son propre FFA et ses bots.
- Arsenal official : https://www.roblox.com/games/286090429/Arsenal — identité arcade centrée sur des changements d'armes, le rythme et les cosmétiques. IRON YARD doit approfondir sa propre identité industrielle plutôt que copier ces contenus.

Ce benchmark indique qu'un nouvel FPS ne gagne pas seulement par le nombre de pièces 3D : lisibilité de l'objectif, retour à l'action, maîtrise des armes, rendez-vous multijoueur et progression perçue sont essentiels.

## Arbitrages

- Ne pas réécrire la physique, le FFA, l'IA ou la sauvegarde déjà en place sans défaut démontré.
- Ne pas générer de nouveaux packs avant d'importer les packs VANGUARD/PBR déjà validés.
- Ne pas empiler 2v2–5v5 avant un 1v1 fini et une architecture de score adaptée aux équipes.
- Ne pas intégrer de Robux, de marketplace ou de battle pass avant stabilité, lisibilité et rétention sans paiement.
- Ne pas appeler le build une publication ; ne pas annoncer 60 FPS ou qualité AAA sans mesures et captures moteur.

## Décision finale

PASS pour poursuivre le développement sur main et conserver le FFA existant.
NON VÉRIFIÉ pour métriques Android/PC, vrai Roblox DataStore et rendu des assets importés.
NON LIVRÉ pour publication de l'expérience et modes de duel/équipe.
PROCHAINE SOURCE DE VÉRITÉ : docs/ROADMAP_V2_PUBLIC.md.


## Complément d'audit — 8 novembre 2026, durcissement exécuté

L0.1 de la roadmap V2 a été implémenté dans les handlers WeaponService, MovementService et BotPerfService. Le module serveur RemoteGuard applique des limites par joueur et type d'événement avec un algorithme token-bucket pur (RemoteRatePolicy). Les requêtes de visée, tirs et mouvement conservent leur validation serveur existante. Les commandes d'arrêt de boost/wallrun disposent d'un budget de priorité séparé ; l'actualisation de direction est soumise à un sous-budget et les répétitions de sprint n'entraînent plus de réplication de l'état. Le panneau PERF conserve sa vérification d'identité propriétaire.

Régressions ajoutées en CI : test Luau des quotas et de leur rétablissement, contrôle d'intégration Python des différents RemoteEvents et des refus précoces. Les nouveaux budgets ne remplacent pas la vérification physique dans Roblox Studio sous charge, nécessaire avant d'annoncer l'audit sécurité terminé sur réseau réel. Prochain lot L0.2 : traiter les vrais ComputeAsync orphelins après expiration, actuellement seulement libérés au niveau logique.
