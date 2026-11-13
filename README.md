# IRON YARD — Roblox FPS tactique compétitif

## Pilotage du projet — feuille de route en vigueur

- **[Audit Android v60 — défauts visibles et critères de validation](docs/AUDIT_ANDROID_VISUAL_2026-11-13.md)** : problème du HUD et des étiquettes corrigés dans le code public, diagnostic PBR amélioré, validation de rendu et performance encore ouverte.
- **[Feuille de route V3 — finition production sans test Android immédiat](docs/ROADMAP_V3_SANS_TEST_ANDROID.md)** : backlog actif priorisé, étapes autonomes réalisables depuis GitHub, critères de sortie, blocages Roblox/Android et preuves attendues. **A1 et A2 disposent de régressions offline, A3 est en cours et les vérifications en moteur restent nécessaires.**
- **[Matrice d'acceptation des assets](docs/ASSET_ACCEPTANCE_MATRIX.md)** : état généré depuis les registres d'IDs — 26 IDs propriétaires consignés (10 armes, 4 opérateurs VANGUARD, 12 textures PBR du décor), prêts hors moteur ; le rendu Android reste à vérifier.
- **[Audit de l'écart avec RIVALS et TTK serveur](docs/AUDIT_ECART_RIVALS_2026-11-12.md)** : modèle de TTK vérifiable pour cinq armes, avec décroissance réelle des dégâts du B-8 et coûts de rechargement, sans modifier les règles de combat.
- [Feuille de route V2 — historique](docs/ROADMAP_V2_PUBLIC.md) : décisions et lots précédents, dont plusieurs statuts ne sont plus actuels.
- [Audit initial du produit — 8 novembre 2026](docs/AUDIT_GLOBAL_2026-11-08.md) : photographie datée, non représentative de toutes les fonctionnalités publiées ensuite.
- [Journal des changements](docs/ROADMAP.md) : archive chronologique, pas le backlog actif.

**État vérifié le 13 novembre 2026 :** **v60 publiée sur [IRON YARD public](https://www.roblox.com/games/99189039770065/IRON-YARD)** ([publication #43474268716](https://github.com/dbrckk/Roblox-shooter/actions/runs/43474268716)), **version de place Roblox 56**, source `e6b420b679bf8a8178bee5b2d125f86793c3b0eb`. CI du commit exact et garde-fous de destination réussis ; aucun nouvel asset téléversé. Les **26 IDs propriétaires** restent consignés (10 armes, 4 VANGUARD, 12 textures PBR du monde). V58 a ajouté les matériaux PBR côté client, v59 a sécurisé leur invalidation. **V60** publie la correction Android des tailles de contrôles et du nom d'arme, le respect de l'occlusion des étiquettes IA ([PR #91](https://github.com/dbrckk/Roblox-shooter/pull/91)), les reprises bornées des chargements de Models PBR et les états de diagnostic propriétaires en panneau PERF défilable ([PR #92](https://github.com/dbrckk/Roblox-shooter/pull/92)). Les deux captures Android d'avant v60 constituent un **retour visuel réel**, pas un test d'acceptation après correction : le chargement effectif des MeshParts, les FPS/P95 et les images PBR restent à vérifier dans Roblox.

Les premières protections serveur et la récupération de progression sont en place. Le projet maintient **une seule expérience publique**, sans phase privée : GitHub Actions construit une place testable. Un push ordinaire ne publie rien ; seul un commit comportant une autorisation unique, suivi de sa CI verte et des vérifications du propriétaire/de la destination publique, peut déclencher le workflow de publication. Un build GitHub n'est pas une publication Roblox.


FPS Roblox indépendant, utilisant **RIVALS** (duels et progression), **Hypershot** (fluidité) et **Arsenal** (rythme) comme références de game design. Aucun script, asset, carte ni interface propriétaire de ces jeux n'a été copié.

## Base technique

Adaptation du moteur libre [roblox-precision-framework](https://github.com/lukas-mikalainis/roblox-precision-framework) par Lukas Mikalainis, sous **MIT**. La licence et attribution sont conservées dans [LICENSE](LICENSE). Code serveur/client et jeu de tirs intégrés, pas seulement des fichiers de documentation.

- **Précision de visée caméra/tête (10 novembre 2026) :** la visée du joueur converge désormais vers le point visible depuis sa caméra, mais le rayon de dégâts reste lancé depuis la tête contrôlée par le serveur, sans tir à travers les couvertures. En cas de caméra trop éloignée ou masquée (latence/déplacement rapide), la trajectoire serveur existante reste utilisée. La validation Roblox Studio reste à effectuer.
- **Arsenal de cinq armes originales :** AR-24 automatique, B-8 à huit plombs, pistolet, sniper et couteau à lancer. Dégâts, dispersion, chargeurs, rechargements et cadence sont contrôlés par le serveur. Les armes disposent de modèles originaux à la première personne ; lunette sniper et visée à l'épaule/hausse pour les autres armes.
- **Munitions et confort de tir :** 30 balles AR-24, 14 pistolet, 6 pompe, 5 sniper ; couteaux sans chargeur. Rechargement par `R` sur PC ou bouton `RLD` sur Android ; nouvelles munitions en début de manche. Le HUD affiche la quantité réelle répliquée par le serveur.
- Déplacements : sprint, slide, saut, boost, wallrun et mantle. Depuis la **v55**, un mantle différé est rejeté si la phase, l'époque de combat, le personnage ou l'ancrage serveur a changé.
- HUD, réticule, recul, impacts, sons Roblox internes et fil d'éliminations serveur (les mannequins d'entraînement sont désactivés dans l'arène compétitive).
- **Contrôles PC + Android/iOS :** tir automatique par maintien, touches 1 à 5 pour l'arsenal, clic droit ou bouton AIM pour viser, choix d'arme mobile avec sélection visible et retour tactile de santé (flash discret).
- Classement FFA top 3 actualisé par le serveur : vrais joueurs et IA, orientation et secteur dans un HUD compact pour Android.
- **Duel 1v1** : série au premier à cinq victoires avec points de réapparition opposés. Depuis la v54, les six paires disponibles tournent toutes les deux manches, côtés inversés et fallback sur une paire entièrement libre. Les tests couvrent 49 152 sélections déterministes ; pas de preuve de gameplay moteur.
- Nouveaux repères de terrain : chariots élévateurs, palettes et couvertures industrielles avec collisions de jeu distinctes des détails graphiques.
- Projet Rojo + CI Github Actions build Roblox.
- **Arène originale de 356 × 356 studs**, couverture, verticalité, éclairage naturel, terminal de fret moderne avec conteneurs et grues industrielles, signalétique et décors à LOD dynamique ; les quatre modèles VANGUARD propriétaires sont présents dans le build public v56 avec LOD mobile et fallback ; leur rendu réel reste à valider ; les 12 textures PBR du décor sont approuvées et présentes dans la v59, avec application locale sûre, invalidation des variantes obsolètes et matériaux natifs en ECO (rendu et FPS à vérifier sur Android).
- **Combattants VANGUARD** : quatre opérateurs tactiques stylisés construits à partir d'armures modulaires (casques tactiques, visières non émissives, protections balistiques, sac dorsal et fusils). Animations procédurales synchronisées avec la distance parcourue : marche, saut, rechargement, visée et recul. Les détails lointains sont masqués localement sur Android.
- **IA tactique serveur** : recherche de cibles avec lignes de vue vérifiées, dernière position observée, contournement, repli vers les couvertures lorsqu'un bot est blessé ou recharge, déplacements avec contrôle de largeur de passage. La recharge fonctionne même si la cible disparaît.
- **Lisibilité du combat** : indicateur bref de direction des tirs entrants après dégâts validés côté serveur. Le classement mobile se masque temporairement pendant le briefing initial pour ne pas le recouvrir.
- **Stations médicales interactives** : quatre bornes 3D utilisables sur PC et téléphone avec un ProximityPrompt Roblox. Soin de 40 PV, recharge de 24 secondes partagée par tous les joueurs, contrôles serveur de la distance, de la santé et de la manche, retour visuel et audio. Ni collision supplémentaire ni obstacle pour les tirs.
- **Élimination et réapparition** : une carte compacte affiche le tireur, l’arme, le headshot éventuel et le temps de réapparition après un kill confirmé par le serveur ; les morts environnementales restent non attribuées. Masquée dès la réapparition ou au podium. À tester sur Android et en Studio.
- **Récompenses de combat** : médailles de précision, enchaînements DOUBLE KILL / TRIPLE KILL et bonus de série, attribués par le serveur. Les XP de manche et de session restent visibles indépendamment de la carrière.
- **Carrière persistante côté serveur (nouveau)** : XP total, niveau, nombre de victimes, headshots et victoires stockés par UserId via Roblox DataStore `UpdateAsync`, avec verrou de session, sauvegarde régulière, fermeture sécurisée et signalement d'un échec de sauvegarde. **L'enregistrement sur un vrai serveur Roblox n'a pas encore été testé** : la CI ne valide pas l'accès aux services de Roblox. [Contrats et conditions de validation](docs/PROGRESSION_PERSISTENCE.md).
- **Architecture enrichie** : structure de l'entrepôt, portes de quai, conduits, garde-corps de passerelle et grues détaillées. Ces parties restent purement décoratives, sans nouvelles collisions.
- **Animations d'armes** : gants tactiques complets, mouvements cohérents pendant le rechargement, glissière du pistolet, pompe du fusil et verrou du sniper.


## Publication Roblox DIRECTEMENT PUBLIQUE

Le dépôt comprend un [workflow manuel de publication publique](https://github.com/dbrckk/Roblox-shooter/actions/workflows/publish-roblox-public.yml) qui refuse les univers privés, les mauvais propriétaires, la mauvaise place et tout commit dont la CI n'est pas verte. Aucune publication automatique n'est déclenchée par un push. La destination IRON YARD doit déjà être **publique** dans Roblox Creator Dashboard. Le build affiche son SHA Git sur les résultats de manche pour identifier la version ; un retour arrière est documenté. **La version v57 a bien été publiée sur l’expérience publique** le 13 novembre 2026 (place Roblox version 53, [preuve](https://github.com/dbrckk/Roblox-shooter/actions/runs/43415071087)). Les tests sur appareil et les performances réelles restent à valider. [Guide Android/PC de publication et de rollback](docs/PUBLIC_ROBLOX_PUBLISHING.md).

## Construire et jouer

**Roblox Studio sur Windows/macOS est utile pour les playtests en moteur ; la publication publique est autorisée et automatisée via GitHub Actions.**

1. Installer [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) et Roblox Studio.
2. `git clone https://github.com/dbrckk/Roblox-shooter.git` puis `cd Roblox-shooter`.
3. `rojo build default.project.json -o iron-yard.rbxlx`.
4. Ouvrir `iron-yard.rbxlx` dans Studio, puis **Play**.
5. Édition en direct : `rojo plugin install` puis `rojo serve default.project.json`.

**Robustesse des combats :** les bots continuent à marcher pendant le calcul d'itinéraires, recalculent leur trajet à proximité des obstacles bas et plateformes, tournent physiquement vers leurs cibles avec `AlignOrientation` et cessent de bloquer les tirs lorsqu'ils sont éliminés. Leur spawn est sélectionné loin des combattants, avec deux secondes de protection annoncées au-dessus du personnage. Les protections sont annulées lorsqu'un combattant tire. Le score des bots retirés (lorsqu'un joueur rejoint) ne peut plus remporter une manche ; les bots morts sont réinitialisés au début de la suivante. La vérification de navigation et de physique dans Studio reste nécessaire.

Le dépôt inclut un mode FFA avec jusqu'à quatre bots mobiles, IA serveur, victoire par éliminations, scoreboard et fil de tirs. Les joueurs disposent de réapparitions sélectionnées parmi des positions dégagées et éloignées des autres combattants, avec protection temporaire de 2,5 secondes annulée au premier tir. Le gameplay reste **non testé dans Studio depuis cette session**. La publication v56 est confirmée, mais la qualité AAA, le rendu PBR effectif et la fluidité Android ne sont pas validés par un build vert. La CI compile tous les fichiers Luau et génère le fichier Roblox Studio ; elle ne valide pas la qualité du gameplay ni les performances sur téléphone.

## Télécharger le projet construit

Ouvrir [GitHub Actions → Rojo build](https://github.com/dbrckk/Roblox-shooter/actions/workflows/rojo-build.yml), choisir le dernier workflow vert, et télécharger l'archive `iron-yard-roblox-place`. Extraire `iron-yard.rbxlx` puis l'ouvrir dans Roblox Studio (PC). Le fichier n'est **pas** un jeu mobile autonome.

## Ressources

[star-list](https://github.com/dbrckk/star-list) propose notamment Roblox Studio MCP, Roblox Brain, modèles 3D sous licences vérifiables et audit des dépendances. Aucune extraction de propriété intellectuelle de RIVALS.

Voir [docs/ROADMAP.md](docs/ROADMAP.md) pour les éléments requis avant publication.

## Blender : vrais modèles 3D et textures PBR

Le workflow [AssetForge VANGUARD](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml) produit les meshes externes FBX/GLB, cartes ColorMap/NormalMap/RoughnessMap/MetalnessMap et une prévisualisation. Le jeu utilise les `MeshParts` importés de `ServerStorage/VanguardTemplates` lorsqu'ils existent ; autrement, les armures procédurales restent actives. **Les 4 modèles VANGUARD ont été uploadés et leur approbation confirmée le 13 novembre ; les 12 canaux PBR du décor restent sans IDs, et le rendu des opérateurs dans l'expérience publique n'est pas encore vérifié**. [Guide d'intégration](docs/VANGUARD_ASSETS.md).

### Kits 3D/PBR vérifiés — IRON YARD

La [génération militaire IRON YARD du 29 octobre 2026](https://github.com/dbrckk/Roblox-shooter/actions/runs/40889978913) a réussi : **7 modèles rigides FBX**, **8 modèles GLB (4 tenues × 2 LOD)**, **32 cartes PBR 1 024 × 1 024**, scène Blender source et aperçu. Les quatre palettes actuelles sont **olive, sable, ardoise et rouille** ; les anciens coloris lumineux ne sont plus les modèles à importer.

Le kit complet est sauvegardé dans une [GitHub Release permanente d'assets](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-5cd834601f9e). Il s'agit d'une archive de création, **pas d'une publication de l'expérience Roblox**.

## Assets VANGUARD et textures PBR

Le kit 3D original a été généré une première fois avant le passage à la direction IRON YARD. Une nouvelle génération utilise désormais les palettes olive, sable, ardoise et rouille. Le lot de 7 pièces FBX, 4 palettes GLB LOD0/LOD1 et 32 cartes Color/Normal/Roughness/Metallic a été **généré et exporté** via [AssetForge GitHub Actions](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml). La [version IRON YARD actuelle](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-5cd834601f9e) comporte des normals dérivées d'une hauteur procédurale, des rainures et de l'usure. Un script `tools/studio/install_vanguard.lua` prépare 28 MeshParts une fois l'import effectué en Studio. **Les meshes ne sont pas encore présents dans la place Rojo et leur rendu Studio / Android reste non vérifié.**

## Direction artistique IRON YARD

La direction néon est abandonnée : carte industrielle **de jour**, lumière solaire, béton clair, tôles peintes, grues et containers. Quatre tenues militaires peintes (olive, sable, ardoise, rouille) remplacent les accents lumineux. Le système de tir et les mouvements rapides sont conservés. Les noms internes commençant par `Neon` sont maintenus uniquement par compatibilité avec les scripts déjà liés ; ils ne sont plus une identité publique. Les modèles Blender doivent être réimportés dans Studio après chaque génération de palette.

## Publication des quatre modèles PBR — IDs propriétaires approuvés

La génération haute résolution **1024 × 1024** compatible avec la limite d'import Roblox a été validée le 29 octobre 2026 : [Release VANGUARD 1K](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-5cd834601f9e). Le workflow [upload vers Roblox Open Cloud](https://github.com/dbrckk/Roblox-shooter/actions/workflows/upload-vanguard-opencloud.yml) prépare quatre modèles GLB LOD0, vérifie le propriétaire et les statuts de traitement, puis peut pousser leurs identifiants sur `main`. Sans secret `ROBLOX_OPEN_CLOUD_ASSETS_KEY`, les valeurs restent à zéro et les armures procédurales servent de fallback. Ce pipeline n'est **pas une preuve d'upload ou de rendu en jeu**. Voir [docs/VANGUARD_ASSETS.md](docs/VANGUARD_ASSETS.md).

### Fichiers PBR optimisés pour l’importation Roblox

La génération corrigée [AssetForge 40889978913](https://github.com/dbrckk/Roblox-shooter/actions/runs/40889978913) a confirmé les tailles des quatre GLB LOD0 (**olive 14,963 Mo ; sable 14,963 Mo ; ardoise 14,963 Mo ; rouille 14,963 Mo**, chacun sous la limite de 20 Mo). L'archive complète de création a été ramenée à **151,6 Mo**. La résolution source reste 1 024 × 1 024. Le lot actuel des quatre packages VANGUARD a reçu des IDs Roblox propriétaires approuvés ; la vérification visuelle du rendu et une publication du place restent nécessaires.
