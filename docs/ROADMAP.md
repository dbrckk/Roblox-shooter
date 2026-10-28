# NEON STRIKE — production

## Référence
RIVALS pour la boucle d'affrontements, Hypershot pour la réactivité, Arsenal pour la variété d'armes. Recréation indépendante, pas de copie d'expérience Roblox.

## État
- [x] moteur Roblox FPS Luau licencié MIT
- [x] serveur : dégâts et cadence de tir
- [x] armes, caméra, animations procédurales, HUD
- [x] entrées tactiles Android/iOS ajoutées
- [x] build CI Rojo
- [x] carte arène originale de 356 x 356 studs, couvertures et plateformes
- [x] statistiques de session (éliminations et morts, sans persistance)
- [x] Arena FFA : gestion serveur des phases countdown/live/résultats, objectif 15 éliminations et HUD (tests Studio requis)
- [ ] vrais duels 1v1 jusqu'à 5v5, équipes, spectateur et matchmaking
- [ ] tests réellement exécutés en Roblox Studio et sur Android
- [x] personnages IA mobiles : recherche de cible, navigation PathfindingService, tir et réaction variable (test Studio à réaliser)
- [x] armures VANGUARD originales sur R6, animation procédurale marche/visée/recul, fusils 3D, muzzle flash et traînées colorées (validation runtime requise)
- [x] décor industriel original, signalétique, correction colorimétrique / Bloom, LOD local décor et armure Android
- [x] vrais meshes Blender originaux générés : 7 FBX, 8 GLB avec 2 LOD, 32 cartes PBR 512×512 et planche de contact validés en CI (upload Roblox encore à faire)
- [ ] importer/publiquer les MeshParts et SurfaceAppearance dans Roblox Studio, calibrer positions, FX, animation rigide et Android
- [ ] skinned meshes haut de gamme, animations professionnelles, mixage audio spatial, profils graphiques
- [ ] anti-triche et latence validées sous charge
- [ ] matchmaking, progression, sauvegardes et stabilité publication

## Catalogue star-list
Sources pertinentes: TabooHarmony/roblox-brain, Chrrxs/robloxstudio-mcp, Scenario Labs 3D Collection (CC BY 4.0 avec attribution et contrôle de provenance). Ressources à auditer avant exécution ou intégration.

## Livraison
Pas de publication sans Rojo build vert, playtest deux joueurs, contrôle tactile Android, mesure de performances et conformité licences.
