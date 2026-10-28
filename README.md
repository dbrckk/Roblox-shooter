# IRON YARD — Roblox FPS tactique compétitif

FPS Roblox indépendant, utilisant **RIVALS** (duels et progression), **Hypershot** (fluidité) et **Arsenal** (rythme) comme références de game design. Aucun script, asset, carte ni interface propriétaire de ces jeux n'a été copié.

## Base technique

Adaptation du moteur libre [roblox-precision-framework](https://github.com/lukas-mikalainis/roblox-precision-framework) par Lukas Mikalainis, sous **MIT**. La licence et attribution sont conservées dans [LICENSE](LICENSE). Code serveur/client et jeu de tirs intégrés, pas seulement des fichiers de documentation.

- Armes : pistolet, sniper et couteau à lancer ; tir et dégâts calculés côté serveur.
- Déplacements : sprint, slide, saut, boost, wallrun et mantle.
- HUD, réticule, recul, impacts, sons Roblox internes et fil d'éliminations serveur (les mannequins d'entraînement sont désactivés dans l'arène compétitive).
- Contrôles PC + boutons tactiles Android/iOS ajoutés.
- Classement FFA top 3 actualisé par le serveur : vrais joueurs et IA, orientation et secteur dans un HUD compact pour Android.
- Nouveaux repères de terrain : chariots élévateurs, palettes et couvertures industrielles avec collisions de jeu distinctes des détails graphiques.
- Projet Rojo + CI Github Actions build Roblox.
- **Arène originale de 356 × 356 studs**, couverture, verticalité, éclairage naturel, terminal de fret moderne avec conteneurs et grues industrielles, signalétique et décors à LOD dynamique ; les vrais meshes PBR importés restent à produire.
- **Combattants VANGUARD** : quatre opérateurs tactiques stylisés construites à partir d'armures modulaires (casques tactiques, visières non émissives, protections balistiques, sac dorsal et fusils). Animations procédurales de marche, posture de visée, regard et recul. Leurs détails lointains sont masqués localement sur Android.

## Publier comme expérience Roblox PRIVÉE

Le dépôt dispose d'un [workflow GitHub Actions manuel](https://github.com/dbrckk/Roblox-shooter/actions/workflows/publish-roblox-private.yml) qui construit la dernière version et l'envoie dans une expérience **IRON YARD déjà créée et privée**. Il vérifie la visibilité avant et après la publication et refuse toute autre expérience. Il nécessite un `Universe ID`, un `Place ID` et le secret GitHub `ROBLOX_OPEN_CLOUD_API_KEY`. **La présence de ce workflow ne signifie pas que l'expérience a été publiée.** [Instructions Android et configuration des accès](docs/PRIVATE_ROBLOX_PUBLISHING.md).

## Construire et jouer

**Roblox Studio sur Windows ou macOS est requis pour le playtest et la publication.**

1. Installer [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) et Roblox Studio.
2. `git clone https://github.com/dbrckk/Roblox-shooter.git` puis `cd Roblox-shooter`.
3. `rojo build default.project.json -o iron-yard.rbxlx`.
4. Ouvrir `iron-yard.rbxlx` dans Studio, puis **Play**.
5. Édition en direct : `rojo plugin install` puis `rojo serve default.project.json`.

**Robustesse des combats :** les bots continuent à marcher pendant le calcul d'itinéraires, recalculent leur trajet à proximité des obstacles bas et plateformes, tournent physiquement vers leurs cibles avec `AlignOrientation` et cessent de bloquer les tirs lorsqu'ils sont éliminés. Leur spawn est sélectionné loin des combattants, avec deux secondes de protection annoncées au-dessus du personnage. Les protections sont annulées lorsqu'un combattant tire. Le score des bots retirés (lorsqu'un joueur rejoint) ne peut plus remporter une manche ; les bots morts sont réinitialisés au début de la suivante. La vérification de navigation et de physique dans Studio reste nécessaire.

Le dépôt inclut un mode FFA avec jusqu'à quatre bots mobiles, IA serveur, victoire par éliminations, scoreboard et fil de tirs. Les joueurs disposent de réapparitions sélectionnées parmi des positions dégagées et éloignées des autres combattants, avec protection temporaire de 2,5 secondes annulée au premier tir. Il reste **non testé dans Studio depuis cette session**. Ne pas le considérer comme une version AAA ou publiée. La CI compile tous les fichiers Luau et génère le fichier Roblox Studio ; elle ne valide pas la qualité du gameplay ni les performances sur téléphone.

## Télécharger le projet construit

Ouvrir [GitHub Actions → Rojo build](https://github.com/dbrckk/Roblox-shooter/actions/workflows/rojo-build.yml), choisir le dernier workflow vert, et télécharger l'archive `iron-yard-roblox-place`. Extraire `iron-yard.rbxlx` puis l'ouvrir dans Roblox Studio (PC). Le fichier n'est **pas** un jeu mobile autonome.

## Ressources

[star-list](https://github.com/dbrckk/star-list) propose notamment Roblox Studio MCP, Roblox Brain, modèles 3D sous licences vérifiables et audit des dépendances. Aucune extraction de propriété intellectuelle de RIVALS.

Voir [docs/ROADMAP.md](docs/ROADMAP.md) pour les éléments requis avant publication.

## Blender : vrais modèles 3D et textures PBR

Le workflow [AssetForge VANGUARD](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml) produit les meshes externes FBX/GLB, cartes ColorMap/NormalMap/RoughnessMap/MetalnessMap et une prévisualisation. Le jeu utilise les `MeshParts` importés de `ServerStorage/VanguardTemplates` lorsqu'ils existent ; autrement, les armures procédurales restent actives. **Les assets ne sont pas encore publiés automatiquement sur Roblox**. [Guide d'intégration](docs/VANGUARD_ASSETS.md).

### Kits 3D/PBR vérifiés — IRON YARD

La [génération militaire IRON YARD](https://github.com/dbrckk/Roblox-shooter/actions/runs/40760716987) a réussi : **7 modèles rigides FBX**, **8 modèles GLB (4 tenues × 2 LOD)**, **32 cartes PBR 512 × 512**, scène Blender source et aperçu. Les quatre palettes actuelles sont **olive, sable, ardoise et rouille** ; les anciens coloris lumineux ne sont plus les modèles à importer.

Le kit complet est sauvegardé dans une [GitHub Release permanente d'assets](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-f2066be670e7). Il s'agit d'une archive de création, **pas d'une publication de l'expérience Roblox**.

## Assets VANGUARD et textures PBR

Le kit 3D original a été généré une première fois avant le passage à la direction IRON YARD. Une nouvelle génération utilise désormais les palettes olive, sable, ardoise et rouille. Le lot de 7 pièces FBX, 4 palettes GLB LOD0/LOD1 et 32 cartes Color/Normal/Roughness/Metallic a été **généré et exporté** via [AssetForge GitHub Actions](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml). La [version IRON YARD actuelle](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-f2066be670e7) comporte des normals dérivées d'une hauteur procédurale, des rainures et de l'usure. Un script `tools/studio/install_vanguard.lua` prépare 28 MeshParts une fois l'import effectué en Studio. **Les meshes ne sont pas encore présents dans la place Rojo et leur rendu Studio / Android reste non vérifié.**

## Direction artistique IRON YARD

La direction néon est abandonnée : carte industrielle **de jour**, lumière solaire, béton clair, tôles peintes, grues et containers. Quatre tenues militaires peintes (olive, sable, ardoise, rouille) remplacent les accents lumineux. Le système de tir et les mouvements rapides sont conservés. Les noms internes commençant par `Neon` sont maintenus uniquement par compatibilité avec les scripts déjà liés ; ils ne sont plus une identité publique. Les modèles Blender doivent être réimportés dans Studio après chaque génération de palette.
