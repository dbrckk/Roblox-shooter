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
| Opérateurs VANGUARD | 4 | 4 | 4 | 0 |
| Matériaux du monde | 3 | 12 | 3 | 0 |

## Armes — 10 IDs propriétaires

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `Pistol` | LOD0 `134864362258514`<br>LOD1 `84881223568978` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Knife` | LOD0 `99348309499128`<br>LOD1 `103350592551962` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `AssaultRifle` | LOD0 `81435833013728`<br>LOD1 `126956757917272` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Shotgun` | LOD0 `114122460440295`<br>LOD1 `77438296092988` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |
| `Sniper` | LOD0 `136956878791627`<br>LOD1 `85416191844702` | 9774173158 | `61bf0302d0aa091043f2a7051c5bc63cb3e31e45` | LOD0 + LOD1 | MeshPart + SurfaceAppearance (validation offline) | viewmodel procédural | rendu, cadrage mobile et streaming non observés | `READY_OFFLINE` |

Fallback vérifié hors moteur : `WeaponAssetPolicy` et `WeaponAssetLoadPlan` gardent le viewmodel procédural quand un ID manque, et `WeaponPbrFxSockets` fixe les sockets FX. **Aucun rendu, cadrage mobile ou coût de streaming n'a été observé.**

## Opérateurs VANGUARD — 4 prêts hors moteur, 0 bloqués

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `olive` | Modèle `132796067986747` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `READY_OFFLINE` |
| `sand` | Modèle `120630851905937` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `READY_OFFLINE` |
| `slate` | Modèle `73086824169421` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `READY_OFFLINE` |
| `rust` | Modèle `136698723350933` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | modèle opérateur complet | GLB + cartes PBR (archives locales) | personnage procédural IRON YARD | import propriétaire et rendu non confirmés | `READY_OFFLINE` |

Quatre IDs de modèles propriétaires sont consignés. Leur rendu réel dans Roblox et sur Android reste à vérifier.

## Matériaux du monde — 3 prêts hors moteur, 0 bloqués

| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |
|---|---|---|---|---|---|---|---|---|
| `freight_steel` | Color `111567469787123`<br>Normal `132527554211334`<br>Roughness `101204051758497`<br>Metalness `101235706800607` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | rendu Roblox et FPS Android non observés | `READY_OFFLINE` |
| `warehouse_steel` | Color `140140460726517`<br>Normal `78831244971620`<br>Roughness `103344882500626`<br>Metalness `103763537751236` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | rendu Roblox et FPS Android non observés | `READY_OFFLINE` |
| `yard_asphalt` | Color `138045450696080`<br>Normal `133921977945079`<br>Roughness `94859615368621`<br>Metalness `85573136066604` | 9774173158 | `903deaafacc29011972b86cbea117bd52d211b76` | 4 canaux PBR | Color / Normal / Roughness / Metalness | matériaux Roblox natifs | rendu Roblox et FPS Android non observés | `READY_OFFLINE` |

Douze IDs d'images sont consignés dans le registre propriétaire. La résolution des textures PBR sur Roblox reste à vérifier.

## Ce que la CI certifie, et ce qu'elle ne certifie pas

**Certifié ici :** la présence et la cohérence des IDs, l'unicité du propriétaire, la traçabilité du commit source des armes, l'existence des contrôles offline par famille, et le fait que chaque famille non uploadée est marquée `BLOCKED`.

**Non certifié :** l'approbation Roblox, l'upload réel, le rendu en moteur, le cadrage mobile, le comportement au streaming, et l'absence de scripts tiers dans les modèles importés. Ces points exigent les permissions du créateur et une session Roblox.

## Collisions, raycasts et repli

Aucun asset de ce lot ne modifie une collision, un raycast, un déplacement ou une couverture : les IDs ne remplacent que l'apparence, et le repli natif reste actif tant qu'un ID vaut zéro. Un modèle contenant des scripts tiers ne doit jamais être intégré.
