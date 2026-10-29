# VANGUARD — exporter et intégration Roblox

Le workflow gratuit [Build original VANGUARD 3D/PBR kit](https://github.com/dbrckk/Roblox-shooter/actions/workflows/assetforge.yml) construit l'ensemble sans logiciel sur smartphone : Blender est installé sur GitHub Actions.

## Archive livrée

- `meshes/vanguard_{olive,sand,slate,rust}_{LOD0,LOD1}.glb` : huit vraies scènes GLB texturées, chaque combattant séparé en sept éléments rigides.
- `parts/vanguard_{torso,head,left_arm,right_arm,left_leg,right_leg,rifle}.fbx` : sept pièces individuelles au format FBX, UV et matériaux, destinées à l'import Roblox.
- `textures/` : huit matériaux de texture distincts, **1 024 × 1 024 pixels sur les futurs exports**, contre 512 × 512 pour les anciens ; pour chacun, `ColorMap`, `NormalMap`, `RoughnessMap` et `MetalnessMap`. Matériaux des palettes olive, sand, slate et rust.
- `preview/vanguard_contact_sheet.png` : rendu Blender des quatre coloris.
- `vanguard_source.blend` : scène source éditable, avec textures intégrées.
- `manifest.json`, `validation_summary.md` : inventaire et contrôles.

**Export actuel IRON YARD vérifié le 28 octobre 2026 :** le run [40760716987](https://github.com/dbrckk/Roblox-shooter/actions/runs/40760716987) a réussi l'export, la validation des 7 FBX / 8 GLB / 32 cartes PBR et la publication de la [Release `iron-yard-assets-f2066be670e7`](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-f2066be670e7). Importer ce nouveau kit **olive/sand/slate/rust**, pas la version colorée historique.

**Export historique (ancienne palette) vérifié le 28 octobre 2026 :** le run [40733818033](https://github.com/dbrckk/Roblox-shooter/actions/runs/40733818033) a généré les 7 FBX, 8 GLB, 32 PNG PBR, la scène Blender et l'aperçu. Les 4 meshes LOD0 comptent chacun 3 636 polygones, selon Blender. Une publication dans [GitHub Releases](https://github.com/dbrckk/Roblox-shooter/releases) est automatisée pour conserver le ZIP durablement, sous l'étiquette *assets / prerelease*, et ne constitue pas une publication du jeu.

Tout est **original**. Aucun contenu de RIVALS ni d'un FPS tiers n'a été extrait. REA reste utilisé pour l'analyse de l'architecture d'un FPS sous licence MIT (voir `REA_RESULTS.md`).

## Activation automatique après import Studio

L'archive ne publie pas les assets sur Roblox : l'upload des MeshParts et de leurs textures nécessite les permissions Studio/Creator.

Le script de jeu `BotVisuals.luau` recherche les modèles dans la hiérarchie suivante :

```text
ServerStorage
└─ VanguardTemplates
   ├─ olive
   │  ├─ torso        (MeshPart, SurfaceAppearance si PBR importé)
   │  ├─ head         (MeshPart)
   │  ├─ left_arm     (MeshPart)
   │  ├─ right_arm    (MeshPart)
   │  ├─ left_leg     (MeshPart)
   │  ├─ right_leg    (MeshPart)
   │  └─ rifle        (MeshPart)
   ├─ sand           (mêmes sept pièces)
   ├─ slate          (mêmes sept pièces)
   └─ rust         (mêmes sept pièces)
```

1. Télécharger l'archive via le workflow réussi, la décompresser sur un ordinateur avec Roblox Studio.
2. Importer chaque GLB `LOD0` à l'aide de **3D Importer** (ou chaque FBX pour pièces séparées). Préserver les sept MeshParts et leurs UV ; les renommer exactement selon la hiérarchie ci-dessus.
3. S'assurer que les textures PBR (les quatre cartes) sont importées et assignées par `SurfaceAppearance` aux pièces pertinentes. Roblox peut demander un upload séparé.
4. Placer les MeshParts dans `ServerStorage/VanguardTemplates/<palette>`, puis enregistrer/publier l'expérience.
5. Les bots détectent automatiquement **un ensemble complet** de sept MeshParts et utilisent les meshes téléchargés. Si une pièce manque, les anciennes armures procédurales continuent à fonctionner.

Il n'y a **aucun ID de mesh inventé** dans le code. Le montage demeure **rigide en sept éléments** (animations Motor6D R6), pas un rig skinné. Il faut inspecter l'échelle, le sens de l'arme, le muzzle et les positions en Studio ; le script pose la pièce rifle sur le bras droit avec un décalage provisoire de calibrage.

**Important** : réussir la compilation Luau, exporter les FBX ou créer le fichier `.rbxlx` ne signifie pas que les meshes ont été vus en fonctionnement sur Android. Des tests en Studio puis sur téléphone restent nécessaires.

## Installation groupée en Studio (nouveau)

Un script de **barre de commandes Studio** évite de renommer/déplacer les 28 pièces à la main :

1. Importer les **quatre GLB LOD0** (olive, sand, slate, rust) via **Studio 3D Importer** ; les ressources doivent être importées et autorisées par Roblox.
2. Vérifier que chaque modèle contient sept MeshParts nommés `VANGUARD_torso`, `VANGUARD_head`, `VANGUARD_left_arm`, etc. Renommer les **quatre modèles racines** pour inclure leur palette respective.
3. Sélectionner simultanément ces **quatre modèles racines** dans l'Explorer, puis exécuter `tools/studio/install_vanguard.lua` dans **View → Command Bar** (copier-coller son contenu).
4. Le script vérifie l'existence et l'ID de chaque mesh et construit automatiquement les **28 MeshParts** de `ServerStorage/VanguardTemplates` ; il prévient si les SurfaceAppearance PBR manquent. Il ne modifie pas les modèles sources sélectionnés.
5. Enregistrer l'expérience dans Studio. Lors du Play, inspecter l'attribut `NeonVisualSource` des bots : `PBR_MESH` signifie que le pack est activé, `PROCEDURAL_PARTS` indique le fallback.

Le script n'est **pas exécuté depuis GitHub Actions** : Studio/Creator et les permissions d'upload restent nécessaires. Aucun ID ni résultat de test mobile n'est inventé.

## Mise à jour haute fidélité du matériau (28 octobre 2026)

L'export [GitHub Actions 40740282547](https://github.com/dbrckk/Roblox-shooter/actions/runs/40740282547) a réussi et produit la release **[vanguard-assets-f072ddadf892](https://github.com/dbrckk/Roblox-shooter/releases/tag/vanguard-assets-f072ddadf892)**. Les 32 cartes PNG conservent la résolution mobile maîtrisée de 512×512, mais les normales sont maintenant **calculées à partir des gradients d'une hauteur de surface**. Les couleurs et la rugosité réagissent aux joints de plaques, biseaux, micro-rayures et petites zones d'usure, différenciés selon les matériaux. Cette release remplace la précédente pour les futurs imports ; elle n'est pas automatiquement synchronisée dans la place Roblox sans passage par Studio.

## Génération haute résolution (29 octobre 2026)

Le pipeline gratuit AssetForge produit désormais **32 cartes PBR de 1 024 × 1 024 pixels** : huit matériaux combinant ColorMap, NormalMap, RoughnessMap et MetalnessMap. Le contrôle qualité vérifie les dimensions, tous les CRC des chunks PNG, leur décompression et la non-uniformité des textures. Les deux LOD géométriques sont conservés pour les contraintes Android.

Les kits historiques listés plus haut restent en résolution 512 px ; utiliser la **nouvelle release `iron-yard-assets-*` créée par un workflow réussi** pour les textures 1K. Un ensemble 1K doit être profilé sur téléphone : la résolution ne dispense pas de limiter le nombre de matériaux chargés. L'import des MeshParts et des SurfaceAppearance dans Studio est toujours nécessaire. **Le nouveau kit d'export n'est pas automatiquement actif dans le jeu Roblox.**

## Import Roblox sans importer chaque modèle à la main — option Open Cloud (29 octobre 2026)

Le kit **1K réellement exporté et validé** est disponible dans la release [iron-yard-assets-a94f1989267c](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-assets-a94f1989267c) et le [workflow réussi](https://github.com/dbrckk/Roblox-shooter/actions/runs/40884993381). L'archive de sources (Blender, huit GLB et PNG) pèse environ **215 Mo compressés** ; cela ne signifie pas qu'un appareil charge toute l'archive en jeu.

Roblox permet d'envoyer des fichiers `.glb` comme assets **Model** via son API officielle Open Cloud (modèles uniques limités à **20 Mo** par requête). L'outil `scripts/upload_vanguard_models.py` prépare quatre imports LOD0, contrôle l'identité du propriétaire, vérifie les entêtes GLB et attend la confirmation de Roblox. Il ne prétend pas importer les MeshParts sans clé et lève une erreur si un GLB dépasse les limites d'upload.

**Workflow :** [Upload VANGUARD PBR models to Roblox](https://github.com/dbrckk/Roblox-shooter/actions/workflows/upload-vanguard-opencloud.yml). Sans coche `publish_assets`, il effectue uniquement une validation locale, sans requête Roblox. Pour le vrai upload, ajouter un secret GitHub `ROBLOX_OPEN_CLOUD_ASSETS_KEY` limité aux permissions Asset Read/Write du compte créateur. Le workflow confirme les quatre assets, puis enregistre leurs IDs numériques dans `src/shared/VanguardAssetIds.luau`. Les IDs restent zéro tant qu'aucun import n'est autorisé et terminé.

À l'ouverture d'un serveur Roblox appartenant au bon créateur, `VanguardAssetLoader` tente de charger uniquement ces **quatre packages modèle possédés** et d'en extraire les 28 `MeshPart` nommés. Aucun script contenu dans un asset importé n'est exécuté. L'adaptateur exige des `SurfaceAppearance` PBR avant de remplacer le fallback procédural ; si les modèles ou les permissions sont incorrects, le jeu conserve les anciennes armures jouables.

**Vérifications indispensables :** (a) la taille de chaque GLB doit être inférieure à 20 Mo, (b) les modèles doivent être autorisés et approuvés par Roblox, (c) ils doivent inclure sept MeshParts identifiables et leurs textures PBR, (d) les permissions InsertService doivent autoriser le propriétaire de l'expérience, (e) leur rendu/impact Android doit être mesuré. La CI GitHub ne valide pas (b) à (e). Aucun upload Roblox n'a été effectué sans cette clé.

Documentation officielle : https://create.roblox.com/docs/cloud/guides/usage-assets

## Activation sans blocage du serveur — 29 octobre 2026

Le loader Roblox charge désormais les quatre packages en tâche asynchrone, en construisant les 28 MeshParts **dans un dossier provisoire**. Le serveur publie `IronYardPbrStatus = LOADING / READY / FALLBACK / MANUAL / DISABLED`. Il ne rend les templates visibles qu'après validation complète ; une erreur Roblox, un refus de permissions ou un asset incomplet laisse la version procédurale active sans empêcher les joueurs d'entrer en partie. Les combattants déjà présents ne changent pas d'apparence pendant un duel ; ils sont recréés au début de la **prochaine manche** si les MeshParts deviennent prêts entretemps. Les templates importés manuellement restent prioritaires.
