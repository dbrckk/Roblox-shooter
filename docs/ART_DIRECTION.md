# IRON YARD — direction artistique 2026

## Positionnement
Un FPS Roblox **arcade tactique rapide**, original, destiné à rester lisible sur Android. Les références RIVALS / Hypershot démontrent l'intérêt d'affrontements réactifs, de silhouettes claires et d'un feedback immédiat ; cela ne suppose ni de reproduire leur IP, ni de copier leurs cartes, armes ou UI.

## Direction retenue
Terminal de fret industriel contemporain, de jour, au contraste élevé, légèrement stylisé.

- **Environnements**: grandes masses de béton clair, containers acier peints, grues, rails, marquages et panneaux de sécurité. Trois chemins de combat reliés avec couvertures basses et plateformes.
- **Personnages**: équipement militaire original VANGUARD, plaques balistiques et textile mat, palette olive / sable / ardoise / rouille, marqueurs bots identifiables.
- **Éclairage**: soleil de début d'après-midi, atmosphère légère, ombres douces, bloom désactivé. Pas de faux aspect métallisé émissif.
- **Interface**: charbon mat, texte ivoire, accent jaune sécurité discret, informations de manche prioritaires. Réticule blanc avec contour sombre pour fonds clairs.
- **Effets de tir**: flash balistique bref et traînées temporaires lisibles, sans ambiance néon permanente.
- **Audio**: sons courts et nets, cohérents avec les actions, volume et répétition à calibrer lors du playtest.

## Performance mobile
Les éléments purement cosmétiques (`NeonArtTier` / `NeonCosmeticTier`, clés internes historiques) sont masqués localement au-delà d'une distance selon l'appareil. Les parties de collision et le rig serveur restent inchangés. Les performances réelles sur Android restent à mesurer.

## Critères de validation
1. Faire démarrer le jeu avec 1 joueur / 4 bots et valider la circulation entre les voies et les tirs bloqués par couverture.
2. Confirmer que les zones de réapparition ne chevauchent aucun container ni obstacle et que la protection de spawn est respectée.
3. Importer les **vrais meshes** dans `ServerStorage/VanguardTemplates` et confirmer leur rendu PBR en Studio ; le code utilise encore des armures procédurales en absence de modèles importés.
4. Vérifier réticule sur ciel clair, lecture du tableau des scores et commandes tactiles sur un téléphone réel.
5. Mesurer CPU, GPU, mémoire, cadence et chauffe sur Android. Ne pas annoncer de qualité AAA vérifiée avant ces tests.

Le workflow REA précédent (référence FPS sous licence MIT) demeure conservé dans `docs/REA_RESULTS.md`. Aucun asset tiers propriétaire n'a été repris.


## Enrichissement 3D procédural (29 octobre 2026)

Les huit containers de l'arène possèdent désormais des nervures latérales, des
encadrements, des doubles portes, des tiges de verrouillage, des charnières et des
plaques d'identification. Les pièces de détail sont **non-collisionnelles et
non-interrogeables** : les volumes de gameplay de MapService restent identiques.
Les détails éloignés suivent le système de culling local mobile existant.

L'animation de l'arme en première personne suit désormais la vélocité au sol ;
le rechargement visuel reçoit son état des événements `Ammo` du serveur.
Les bots disposent de réactions de recul aux impacts et d'amortissement à
l'atterrissage, sans nouvel asset ni animation payante.

Il s'agit de géométrie **procédurale**, pas d'un remplacement des vraies surfaces
PBR de VANGUARD ; l'import Studio des MeshParts reste nécessaire.
