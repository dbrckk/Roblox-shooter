# NEON STRIKE — Roblox Shooter

FPS Roblox indépendant, utilisant **RIVALS** (duels et progression), **Hypershot** (fluidité) et **Arsenal** (rythme) comme références de game design. Aucun script, asset, carte ni interface propriétaire de ces jeux n'a été copié.

## Base technique

Adaptation du moteur libre [roblox-precision-framework](https://github.com/lukas-mikalainis/roblox-precision-framework) par Lukas Mikalainis, sous **MIT**. La licence et attribution sont conservées dans [LICENSE](LICENSE). Code serveur/client et jeu de tirs intégrés, pas seulement des fichiers de documentation.

- Armes : pistolet, sniper et couteau à lancer ; tir et dégâts calculés côté serveur.
- Déplacements : sprint, slide, saut, boost, wallrun et mantle.
- HUD, réticule, recul, impacts, sons Roblox internes, mannequins de tir.
- Contrôles PC + boutons tactiles Android/iOS ajoutés.
- Projet Rojo + CI Github Actions build Roblox.
- **Arène originale procédurale de 356 × 356 studs**, avec couverture tactique, verticalité, néons et spawn d'entraînement. La modélisation PBR et les assets premium restent à produire.

## Construire et jouer

**Roblox Studio sur Windows ou macOS est requis pour le playtest et la publication.**

1. Installer [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) et Roblox Studio.
2. `git clone https://github.com/dbrckk/Roblox-shooter.git` puis `cd Roblox-shooter`.
3. `rojo build default.project.json -o neon-strike.rbxlx`.
4. Ouvrir `neon-strike.rbxlx` dans Studio, puis **Play**.
5. Édition en direct : `rojo plugin install` puis `rojo serve default.project.json`.

Le dépôt inclut désormais une simulation FFA avec jusqu'à quatre bots mobiles, avec IA serveur, victoire par éliminations et scoreboard. Il reste **non testé dans Studio depuis cette session**. Ne pas le considérer comme une version AAA ou publiée. La CI vérifiera seulement la génération du fichier, pas la qualité du gameplay.

## Télécharger le projet construit

Ouvrir [GitHub Actions → Rojo build](https://github.com/dbrckk/Roblox-shooter/actions/workflows/rojo-build.yml), choisir le dernier workflow vert, et télécharger l'archive `neon-strike-roblox-place`. Extraire `neon-strike.rbxlx` puis l'ouvrir dans Roblox Studio (PC). Le fichier n'est **pas** un jeu mobile autonome.

## Ressources

[star-list](https://github.com/dbrckk/star-list) propose notamment Roblox Studio MCP, Roblox Brain, modèles 3D sous licences vérifiables et audit des dépendances. Aucune extraction de propriété intellectuelle de RIVALS.

Voir [docs/ROADMAP.md](docs/ROADMAP.md) pour les éléments requis avant publication.
