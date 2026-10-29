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
- [x] Arena FFA : gestion serveur des phases countdown/live/résultats, objectif 15 éliminations et HUD (tests Studio requis)
- [ ] vrais duels 1v1 jusqu'à 5v5, équipes, spectateur et matchmaking
- [ ] tests réellement exécutés en Roblox Studio et sur Android
- [x] personnages IA mobiles : recherche de cible, navigation PathfindingService, tir et réaction variable (test Studio à réaliser)
- [x] armures tactiques VANGUARD originales sur R6, animation procédurale marche/visée/recul, fusils 3D, muzzle flash et traînées colorées (validation runtime requise)
- [x] thème IRON YARD : terminal industriel de jour, grues, containers, marquages routiers, signalétique, sans Bloom, LOD local Android
- [x] nouveaux meshes Blender PBR mats olive/sable/ardoise/rouille : 7 FBX, 8 GLB en 2 LOD, 32 cartes PBR 512×512 validés et archivés sur GitHub (upload Roblox encore à faire)
- [x] briefing de début de manche et réticule contrasté sur fond clair (validation en jeu requise)
- [x] classement des trois meilleurs combattants, secteur et direction en temps réel (tests en jeu nécessaires)
- [x] silhouettes industrielles, couvertures physiques et détails LOD optimisés sur mobile (tests Android nécessaires)
- [x] navigation bots asynchrone sans immobilisation : trajectoire directe sur terrain libre, vérification des obstacles bas, replanification, invalidation des chemins périmés
- [x] sécurité du round : bot éliminé non bloquant, score des bots retirés purgé, respawn adapté aux couvertures, protection temporaire commune aux joueurs et IA
- [x] orientation physique des bots face aux cibles visibles et animation de visée existante (à confirmer en Studio)
- [x] couteau : contrôle serveur du segment d'apparition pour éviter de traverser une couverture proche
- [x] LOD : prise en compte des modèles chargés après l'arrivée du client, cache de détails mis à jour à la réplication
- [ ] importer/publiquer les MeshParts et SurfaceAppearance dans Roblox Studio, calibrer positions, FX, animation rigide et Android
- [ ] skinned meshes haut de gamme, animations professionnelles, mixage audio spatial, profils graphiques
- [ ] anti-triche et latence validées sous charge
- [ ] matchmaking, progression, sauvegardes et stabilité publication

## Catalogue star-list
Sources pertinentes: TabooHarmony/roblox-brain, Chrrxs/robloxstudio-mcp, Scenario Labs 3D Collection (CC BY 4.0 avec attribution et contrôle de provenance). Ressources à auditer avant exécution ou intégration.

## Livraison
Pas de publication sans Rojo build vert, playtest deux joueurs, contrôle tactile Android, mesure de performances et conformité licences.
