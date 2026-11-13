# IRON YARD — Audit Android visuel et corrections prioritaires (13 novembre 2026)

**Expérience :** [IRON YARD publique](https://www.roblox.com/games/99189039770065/IRON-YARD) — captures réelles Android fournies par le propriétaire le 13 novembre 2026.  
**Base auditée :** `9cf32b4b2f80d73a5b1718066190274e767e49e4` (v59 publiée ; version de place Roblox 55).  
**Portée :** captures de jeu + code versionné. Aucun relevé de FPS, logs Roblox Studio, état du panneau PERF ni mesure de rendu GPU joints.

**Actualisation du 13 novembre :** les correctifs prioritaires de l'interface et des marqueurs IA ([PR #91](https://github.com/dbrckk/Roblox-shooter/pull/91)), ainsi que la robustesse et la visibilité des statuts de chargement PBR ([PR #92](https://github.com/dbrckk/Roblox-shooter/pull/92)), sont fusionnés et **publiés en v60** ([preuve Roblox #43474268716](https://github.com/dbrckk/Roblox-shooter/actions/runs/43474268716), version de place **56**). Les critères de visualisation et performance sur Android ci-dessous restent à valider par captures **après v60**.

## Constats vérifiés et limites

| Priorité | Observation Android | Cause vérifiée / statut | Preuve de sortie |
|---|---|---|---|
| **P0** | Textes énormes FIRE, AIM, RUN, SLIDE et armes, écrasant le côté droit | `init.client.luau` met `TextScaled=true` sur tous les boutons sans `UITextSizeConstraint` ; **corrigé dans ce lot** par limite à 16/19 px en unités UI, sans modifier les hitboxes tactiles | CI contrats + essai Android avec vue complète des 10 boutons, sans glyphes débordants |
| **P0** | Nom de l'arme énorme au bas-centre, visuellement concurrent de la barre de vie | `HudController.luau` utilisait `TextScaled=true` ; **corrigé** en légende 17 px et troncature sans perte des munitions | Texte lisible et contenu dans 280 px en mode paysage |
| **P0** | Barres vertes et noms des bots visibles alors que leurs corps semblent derrière une couverture | `BotService.luau` utilisait `BillboardGui.AlwaysOnTop=true`, qui ne respecte pas l'occlusion ; **corrigé** en depth test | Vérifier in-game qu'une paroi opaque masque l'étiquette, et qu'un bot réellement visible conserve sa barre |
| **P1** | Motifs très répétitifs sur sol/toiture, composition sombre dans les deux vues | Cause précise non prouvée. Le jeu utilise trois variantes `WorldPbrPolicy`, textures originales et art procédural ; l'angle de vue et le profil graphique peuvent amplifier le rendu | Comparer captures ECO/BALANCED/QUALITY au même endroit, vérifier que la carte `yard_asphalt` et les variantes locales correspondent au matériau voulu |
| **P1** | Fusil AR-24 encore grossier sur une des captures, absent de l'autre | La scène montre une arme procédurale ou PBR insuffisamment détaillée ; **source exacte non établie par capture**. Le moteur possède un fallback quand le chargement propriétaire échoue ou tarde | Vérifier `IronYardWeaponMeshReadyCount` (cible 5), `IronYardPerfWeaponSource` (`PBR`), erreurs `WeaponAssetLoader` ; inspecter caméra/LOD/reload |
| **P1** | Certains bots semblent invisibles sous leur barre | L'étiquette passe devant le décor (défaut confirmé) ; présence/chargement réel des 4 MeshPBR **non démontrés** | PERF : `IronYardPbrStatus=READY`, bots `PBR_MESH`, visibilité des pièces principales, distances et streaming |
| **P2** | HUD surchargé, panneau de briefing et boutons très concurrents | La carte de mission est temporaire ; le panneau propriétaire PERF est volontairement réservé au propriétaire. La fenêtre noire à droite vient de la superposition du téléphone, pas de Roblox | Après correction des tailles, valider safe areas, position des commandes, résultat de manche, FPS stable |
| **P2** | Qualité graphique globale inférieure à un FPS Roblox premium | Texture/éclairage, formes et hiérarchie visuelle encore à auditer par famille réelle de modèles, pas à supposer terminés sur base des IDs Open Cloud | Audit d'assets 3D, ombres, matériaux, normal maps, relief, LOD par scène |

## Plan d'action — lots complets, séquentiels

### Lot 1 — Fix immédiat HUD et lisibilité de combat (code public v60 ; retest Android ouvert)
- Plafonner les tailles de texte des dix touches Android tout en conservant leur géométrie et les tests `TouchLayout`.
- Afficher le nom de l'arme comme une légende compacte, ammo et santé inchangés.
- Faire respecter la profondeur de la scène par les étiquettes IA, sans raycast local supplémentaire.
- Passer le compilateur Luau, la suite de géométrie tactile et le contrat de HUD.
- **Fin du lot :** merge après CI verte. **Publication Roblox séparée**, autorisée et contrôlée.

### Lot 2 — Diagnostic des vrais MeshParts (P0/P1, avant tout nouvel asset)
- Dans une session live propriétaire, ouvrir `PERF` et relever le statut des kits, les 5 armes `PBR` ou `PARTS`, les 4 bots et `PBR local: N/M`.
- Si `PARTS` ou `FALLBACK`, lire les logs Roblox des chargements `AssetService:LoadAssetAsync` et `InsertService:LoadAsset` ; corriger la cause réelle (permission, validation de carte, pivot, origine, groupage GLB) au lieu d'ajouter de nouveaux modèles.
- Vérifier VANGUARD entièrement à l'écran : silhouettes, bras, armes, palette et animation sous éclairage naturel.
- **Fin du lot :** cinq armes + quatre palettes 3D effectivement visibles sur Android, et repli testable sans asset.

### Lot 3 — Direction artistique 3D et carte (P1)
- Auditer chaque famille de sol, toiture, conteneurs, entrepôt, chariots, barrières, arme et opérateurs ; comptage des formes primitives restantes avec inventaire programmatique.
- Corriger en premier la texture du sol et la densité des répétitions, puis améliorer la lumière du hangar/extérieur ; jamais changer les volumes de collision sans test de navigation.
- Remplacer les groupes prioritaires par des MeshParts détaillés sous licence/utilisation autorisée, avec LOD, PBR et budgets mobiles documentés.
- **Fin du lot :** captures comparatives de lieux identiques (Android HIGH/ECO), silhouette lisible, aucune régression de combat ou de visibilité.

### Lot 4 — Performance, comportement et validation finale (P0/P1)
- Mesurer après stabilisation 5 minutes de FFA et duels : médiane FPS, P95/P99 frame time, memory MB, `PBR local`, transitions de rounds, kits en mouvement.
- Sur mobile cible : viser **au moins 30 FPS soutenus en BALANCED** et P95 sous ~33 ms, sans promettre ces valeurs avant mesure ; adapter la géométrie/particules/LOD, pas les hitboxes.
- Tester orientation d'écran, notifications système, 3 profils de tailles tactiles, trois qualités, boutons pressés simultanément, combat et réapparition.
- **Fin du lot :** version publique publiée sous garde-fous et validée sur smartphone, rollback connu.

## Règles de décision

Ne pas confondre une CI verte, un ID Roblox approuvé et une texture réellement rendue. Ne pas imputer l'overlay Android de l'application de discussion au HUD Roblox. Ne pas déclarer « tous les problèmes réglés » sans retest en conditions réelles.
