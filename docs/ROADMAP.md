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
