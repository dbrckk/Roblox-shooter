# Matrice d'acceptation par asset — état certifié par la CI

**Date :** 12 novembre 2026 · **Lot :** B1 de la [V3](ROADMAP_V3_SANS_TEST_ANDROID.md) · **Généré par :** `scripts/asset_acceptance_matrix.py` (`--write`)

> Ce document est **généré** depuis `WeaponAssetIds.luau`, `VanguardAssetIds.luau` et `WorldPbrAssetIds.luau`. `scripts/asset_acceptance_matrix.py --check` échoue s'il dérive des modules : la CI publie donc ce que le dépôt contient réellement, pas ce qu'on espère.

## Statuts

- `READY_OFFLINE` : IDs renseignés **et** contrôles offline présents. L'asset n'a **pas** été rendu en moteur ; un upload réussi n'est pas une preuve d'apparence.
- `BLOCKED_ROBLOX_ASSET_APPROVAL` : IDs encore à zéro, le runtime conserve son fallback. Rien n'est inventé, rien n'est déclaré livré.

## Synthèse

| Famille | Assets | IDs | Prêts offline | Bloqués |
|---|---:|---:|---:|---:|
| Armes | 5 | 10 | 5 | 0 |
| Opérateurs VANGUARD | 4 | 4 | 0 | 4 |
| Matériaux du monde | 3 | 12 | 0 | 3 |

## Armes — 10 IDs propriétaires

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `Pistol` | LOD0 `134864362258514`<br>LOD1 `84881223568978` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Knife` | LOD0 `99348309499128`<br>LOD1 `103350592551962` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `AssaultRifle` | LOD0 `81435833013728`<br>LOD1 `126956757917272` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Shotgun` | LOD0 `114122460440295`<br>LOD1 `77438296092988` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Sniper` | LOD0 `136956878791627`<br>LOD1 `85416191844702` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |

Fallback vérifié hors moteur : `WeaponAssetPolicy` et `WeaponAssetLoadPlan` gardent le viewmodel procédural quand un ID manque, et `WeaponPbrFxSockets` fixe les sockets FX. **Aucun rendu, cadrage mobile ou coût de streaming n'a été observé.**

## Opérateurs VANGUARD — 4 IDs à zéro

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `olive` | Modèle `0` | 9774173158 | `—` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |
| `sand` | Modèle `0` | 9774173158 | `—` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |
| `slate` | Modèle `0` | 9774173158 | `—` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |
| `rust` | Modèle `0` | 9774173158 | `—` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |

Blocage factuel : les quatre GLB existent dans les archives, mais aucun ID n'est approuvé. L'import propriétaire reste à faire, avec un préflight **sans upload réel**.

## Matériaux du monde — 12 IDs à zéro

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `freight_steel` | Color `0`<br>Normal `0`<br>Roughness `0`<br>Metalness `0` | 9774173158 | `—` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | upload Open Cloud et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |
| `warehouse_steel` | Color `0`<br>Normal `0`<br>Roughness `0`<br>Metalness `0` | 9774173158 | `—` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | upload Open Cloud et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |
| `yard_asphalt` | Color `0`<br>Normal `0`<br>Roughness `0`<br>Metalness `0` | 9774173158 | `—` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | upload Open Cloud et rendu non confirmés | `BLOCKED_ROBLOX_ASSET_APPROVAL` |

Les douze PNG et leurs hashes sont produits par `tools/assetforge/generate_world_maps.py` et validés par `audit_world_maps.py`. Aucun upload Open Cloud n'a eu lieu : le jeu garde les matériaux Roblox natifs.

## Ce que la CI certifie, et ce qu'elle ne certifie pas

**Certifié ici :** la présence et la cohérence des IDs, l'unicité du propriétaire, la traçabilité du commit source des armes, l'existence des contrôles offline par famille, et le fait que chaque famille non uploadée est marquée `BLOCKED`.

**Non certifié :** l'approbation Roblox, l'upload réel, le rendu en moteur, le cadrage mobile, le comportement au streaming, et l'absence de scripts tiers dans les modèles importés. Ces points exigent les permissions du créateur et une session Roblox.

## Collisions, raycasts et repli

Aucun asset de ce lot ne modifie une collision, un raycast, un déplacement ou une couverture : les IDs ne remplacent que l'apparence, et le repli natif reste actif tant qu'un ID vaut zéro. Un modèle contenant des scripts tiers ne doit jamais être intégré.
