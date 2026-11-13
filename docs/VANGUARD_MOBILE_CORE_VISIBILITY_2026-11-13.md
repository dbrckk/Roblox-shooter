# IRON YARD — VANGUARD : silhouette mobile et ordre des primitives GLB

**13 novembre 2026** · Baseline : `95d55850d253a768bae5fabe7f9ddde788bb6500` · expérience publique actuellement v60.

## Défaut de logique démontré par lecture du code

Le système LOD `BotLOD.client.luau` masque tous les MeshParts de niveau
`Detail` lorsque la caméra est éloignée. Jusqu'à ce correctif,
`VanguardMeshPolicy.visualTier` marquait toujours l'index 1 comme
`Core`. L'ordre des MeshParts d'un GLB multi-matériau n'est pas un ordre
d'importance visuelle : il peut commencer par une visière, une petite
languette ou un élément métallique. Un personnage distant peut donc n'avoir
qu'un petit détail visible, alors que le corps Roblox est intentionnellement
transparent. Ceci est un défaut démontré de sélection LOD, **pas une
preuve que c'était l'unique cause des captures Android**.

## Correctif

1. Sur chaque pièce anatomique, sélectionner le MeshPart au plus grand
   volume de boîte englobante positive et finie, avec priorité stable au premier
   en cas d'égalité.
2. Marquer exactement ce MeshPart comme `IronYardCoreVisual` sur la
   **copie assainie côté serveur**. Ne jamais faire confiance à un attribut
   porté par un asset externe.
3. Les bots lisent les marqueurs par identité d'instance, pas par ordre
   de réplication, et utilisent la première primitive si le modèle manuel
   historique n'en contient pas exactement un.
4. Garder le même nombre de MeshParts, les mêmes CFrames, soudures,
   collisions, hitboxes, cartes PBR et coûts de calcul récurrents. Seule
   la pièce conservée en LOD distant change.
5. En CI, tester les primitives arrivant dans un mauvais ordre, les
   égalités, les valeurs invalides, et exactement un Core par pièce.

## Critères de vérification Android

- Ouvrir `PERF` et relever `IronYardPbrStatus` ainsi que la proportion
  de bots `PBR_MESH` ; confirmer `READY` puis des bots PBR après rotation
  de manche, puisque les bots nés avant l'import restent procéduraux
  jusqu'à la prochaine manche.
- Comparer une silhouette à 20, 60 et 120 studs en mode ECO puis QUALITY.
  Tête, torse et membres principaux doivent rester perceptibles à distance.
- Vérifier qu'aucun autre MeshPart de détail ne traverse les murs/sols,
  que les hitboxes R6 peuvent toujours recevoir les tirs, et que FPS/P95
  ne régressent pas.
- Si les bots restent `PROCEDURAL_PARTS`, relever les erreurs serveur
  et les statuts du chargeur ; les IDs propriétaires enregistrés ne prouvent
  pas que Roblox autorise et rend le modèle dans une session donnée.

**État :** correctif CI et code seulement. Publication publique distincte,
obligatoirement soumise au garde-fou de publication existant.
