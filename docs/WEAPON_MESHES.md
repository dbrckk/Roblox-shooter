# IRON YARD - original weapon mesh forge

Purpose: create real imported 3D geometry, not another cosmetic Roblox Part
collection. The first two weapons are the original Pistol and Knife.
They are modeled and exported with free Blender on GitHub Actions.

Workflow: https://github.com/dbrckk/Roblox-shooter/actions/workflows/weaponforge.yml

The job bakes original 512px ColorMap, NormalMap, RoughnessMap and MetalnessMap,
creates two genuine GLB mesh LODs per weapon, and preserves a Blender source.

- iron_yard_pistol_LOD0.glb: pistol frame and independently movable slide
- iron_yard_pistol_LOD1.glb: reduced gun geometry for mobile
- iron_yard_knife_LOD0.glb: ground blade, scaled handle and pins
- iron_yard_knife_LOD1.glb: reduced knife detail for mobile
- weapons_source.blend: editable original Blender source

The pistol GLBs contain two separate mesh nodes: IRONYARD_Pistol_Static and
IRONYARD_Pistol_Slide. The knife uses IRONYARD_Knife_Static. The structural
validator reads the actual GLB binary and verifies triangles, UVs and
embedded PBR textures instead of trusting filenames or extension alone.

IMPORTANT: No asset ID is created and no game is published by this forge.
The live FPS retains its functional procedural viewmodel until the owner
imports the meshes in Studio and confirms scale, pivots, animations and
Android rendering. A GitHub release is an asset source pack, NOT a Roblox
experience release.


## Activation avec import propriétaire (Pistol + Knife)

1. Télécharger la release de la forge, ouvrir Roblox Studio puis importer
   les QUATRE GLB LOD0 et LOD1 (les renommer pour inclure Pistol/Knife et LOD0/LOD1).
2. Contrôler que les MeshParts ont leurs vraies cartes PBR,
   et sélectionner les quatre modèles importés dans Explorer.
3. Exécuter tools/studio/install_weapon_meshes.lua dans la barre de commande
   Roblox Studio. L'installateur vérifie la complétude de tous les fichiers et
   remplace atomiquement ReplicatedStorage/IronYardWeaponTemplates.
4. Tester en Play avec les armes Pistol et Knife. L'attribut local
   IronYardWeaponSource du Viewmodel doit afficher PBR_MESH si tout fonctionne,
   sinon PROCEDURAL_PARTS : aucun asset incomplet ne remplace l'arme jouable.
5. Vérifier pivots, échelle, shaders, flashs, douilles, animation de glissière,
   visibilité de la main et mémoire sur Android, puis sauvegarder/publier depuis
   un compte propriétaire autorisé.

Cette intégration ne publie PAS un jeu public depuis GitHub Actions.
Une nouvelle place construite uniquement par Rojo n'inclut pas les MeshParts
importés dans Studio tant qu'ils ne sont pas conservés dans la place publiée.
