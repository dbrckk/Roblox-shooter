# NEON STRIKE — Roblox Shooter

FPS Roblox indépendant, utilisant **RIVALS** (duels et progression), **Hypershot** (fluidité) et **Arsenal** (rythme) comme références de game design. Aucun script, asset, carte ni interface propriétaire de ces jeux n'a été copié.

## Base technique

Adaptation du moteur libre [roblox-precision-framework](https://github.com/lukas-mikalainis/roblox-precision-framework) par Lukas Mikalainis, sous **MIT**. La licence et attribution sont conservées dans [LICENSE](LICENSE). Code serveur/client et jeu de tirs intégrés, pas seulement des fichiers de documentation.

- Armes : pistolet, sniper et couteau à lancer ; tir et dégâts calculés côté serveur.
- Déplacements : sprint, slide, saut, boost, wallrun et mantle.
- HUD, réticule, recul, impacts, sons Roblox internes, mannequins de tir.
- Contrôles PC + boutons tactiles Android/iOS ajoutés.
- Projet Rojo + CI Github Actions build Roblox.
- **Arène originale de 356 × 356 studs**, couverture, verticalité, éclairage colorimétrique, structures industrielles 3D, signalétique et décors à LOD dynamique ; les vrais meshes PBR importés restent à produire.
- **Combattants VANGUARD** : quatre silhouettes robotiques originales construites à partir d'armures modulaires (casques, visières lumineuses, protections, sac dorsal et fusils). Animations procédurales de marche, posture de visée, regard et recul. Leurs détails lointains sont masqués localement sur Android.

## Construire et jouer

**Roblox Studio sur Windows ou macOS est requis pour le playtest et la publication.**

1. Installer [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) et Roblox Studio.
2. `git clone https://github.com/dbrckk/Roblox-shooter.git` puis `cd Roblox-shooter`.
3. `rojo build default.project.json -o neon-strike.rbxlx`.
4. Ouvrir `neon-strike.rbxlx` dans Studio, puis **Play**.
5. Édition en direct : `rojo plugin install` puis `rojo serve default.project.json`.

Le dépôt inclut désormais une simulation FFA avec jusqu'à quatre bots mobiles, avec IA serveur, victoire par éliminations et scoreboard. Il reste **non testé dans Studio depuis cette session**. Ne pas le considérer comme une version AAA ou publiée. La CI compile tous les fichiers Luau et génère le fichier Roblox Studio ; elle ne valide pas la qualité du gameplay ni les performances sur téléphone.

## Télécharger le projet construit

Ouvrir [GitHub Actions → Rojo build](https://github.com/dbrckk/Roblox-shooter/actions/workflows/rojo-build.yml), choisir le dernier workflow vert, et télécharger l'archive `neon-strike-roblox-place`. Extraire `neon-strike.rbxlx` puis l'ouvrir dans Roblox Studio (PC). Le fichier n'est **pas** un jeu mobile autonome.

## Ressources

[star-list](https://github.com/dbrckk/star-list) propose notamment Roblox Studio MCP, Roblox Brain, modèles 3D sous licences vérifiables et audit des dépendances. Aucune extraction de propriété intellectuelle de RIVALS.

Voir [docs/ROADMAP.md](docs/ROADMAP.md) pour les éléments requis avant publication.

## Blender : vrais modèles 3D et textures PBR

Le workflow [AssetForge VANGUARD](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml) produit les meshes externes FBX/GLB, cartes ColorMap/NormalMap/RoughnessMap/MetalnessMap et une prévisualisation. Le jeu utilise les `MeshParts` importés de `ServerStorage/VanguardTemplates` lorsqu'ils existent ; autrement, les armures procédurales restent actives. **Les assets ne sont pas encore publiés automatiquement sur Roblox**. [Guide d'intégration](docs/VANGUARD_ASSETS.md).

### Résultat AssetForge vérifié (28 octobre 2026)

La [première génération intégrale](https://github.com/dbrckk/Roblox-shooter/actions/runs/40733818033) a réussi : **7 MeshParts rigides en FBX**, **8 modèles GLB (4 coloris × 2 LOD)**, **32 cartes PBR 512×512**, un `.blend` éditable et une planche d'aperçu. Le profil détaillé utilise **3 636 polygones** par coloris d'après le rapport Blender. Le lot fait 50,23 Mio non compressés et 46,47 Mo environ dans l'artifact ZIP. L'intégration en jeu dépend d'une importation Studio autorisée ; aucun mesh Roblox distant n'est prétendu publié.

Le workflow produit aussi une [GitHub Release permanente](https://github.com/dbrckk/Roblox-shooter/releases) marquée **prerelease d'assets uniquement**, pour ne pas dépendre de l'expiration des artifacts. La présence effective de cette Release doit être validée par le workflow.
