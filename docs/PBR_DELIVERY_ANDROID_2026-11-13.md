# IRON YARD — fiabilisation de la livraison PBR sur Android

**Constat réel :** captures Android du 13/11/2026 montrant un AR-24 au rendu géométrique. Cela **ne prouve pas** la cause d'un fallback : les assets peuvent encore être en cours de chargement ou refusés par le runtime Roblox.

## Défaut logiciel confirmé

`WeaponAssetLoader.loadPair()` charge deux modèles par arme, une seule fois. `AssetService:LoadAssetAsync` peut échouer temporairement (indisponibilité du service), ce que la [documentation Roblox](https://create.roblox.com/docs/reference/engine/classes/AssetService) recommande de traiter avec `pcall`. Avant ce lot, le premier échec de livraison provoquait `FALLBACK` jusqu'au redémarrage du serveur. Les validations de propriété, composants, dimensions et cartes PBR étaient et restent indispensables.

## Correctif

- `MAX_FETCH_ATTEMPTS = 3` pour **chaque téléchargement de Model propriétaire** : jusqu'à deux reprises après erreur API (0,35 s puis 0,7 s). Aucun retry si un Model est téléchargé mais invalide, aucun téléchargement non autorisé, aucun nouvel upload Roblox.
- Deux workers simultanés maximum ; le chargement reste asynchrone, sans bloquer FPS, tirs, serveur, matchmaking ni réapparition. Le modèle procédural reste le repli stable.
- États répliqués, **uniquement informatifs** pour les cinq armes : `DISABLED`, `UNCONFIGURED`, `QUEUED`, `LOADING`, `READY`, `DELIVERY_FAILED`, `VALIDATION_FAILED`, `ROOT_CHANGED`. Jamais d'URL, de clé d'API ou de détail brut d'erreur répliqué.
- Le panneau PERF, déjà réservé au propriétaire/Studio, affiche les états et le compteur `IronYardWeaponMeshReadyCount`; il devient défilable et tient dans la hauteur d'un paysage Android.

## Critères de vérification moteur

1. Ouvrir **PERF** à l'arrivée : attendre fin de `LOADING`. `READY 5/5` est un résultat serveur **attendu**, pas garanti.
2. Après 2 s sans tirer / sprint / visée / recharge, vérifier `Arme AssaultRifle / PBR` et qualité LOD dans le panneau propriétaire.
3. Si `DELIVERY_FAILED` : inspecter warnings Roblox serveur de l'ID autorisé et les permissions de l'expérience. Si `VALIDATION_FAILED` : inspecter les MeshParts, marker `IRONYARD_WeaponOrigin` et les quatre cartes `SurfaceAppearance` sans supprimer les validations.
4. Vérifier visuellement l'arme et les modèles VANGUARD ; comparer QUALITÉ et BALANCÉ, FPS/P95 Android, et commandes touch avant de déclarer le rendu résolu.

**Validation automatisée :** compilateur officiel Luau + tests politiques de reprise/contrats du loader + construction Rojo en CI. Pas de preuve de rendu Android ou de publication Roblox associée au merge.
