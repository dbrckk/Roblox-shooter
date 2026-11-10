# IRON YARD — Benchmark qualité RIVALS / trajectoire du jeu

Date : 10 novembre 2026. Référence de produit, pas une copie de contenus ou de code propriétaires.
Source publique : https://www.roblox.com/games/17625359962/RIVALS

## Qualité recherchée et ordre des travaux

La cible est la **qualité ressentie** de RIVALS : tirs exacts, faible délai perçu, silhouette lisible,
déplacements maîtrisables, explications courtes, manches rejouables, interface utilisable sur téléphone.
Le mode actuel d'IRON YARD est **FFA à 15 éliminations** : il n'est pas présenté comme un duel RIVALS.

1. **Intégrité et précision des tirs** : réconcilier l'axe de caméra avec le rayon partant de la tête.
   Conserver les dégâts, collisions, cadence, munitions et cibles exclusivement côté serveur.
2. **Feedback d'armes** : comparer recul ressenti, impacts, sons différenciés, latence de confirmation,
   compréhension des ratés et headshots sans surcharge visuelle Android.
3. **Assets réellement visibles** : activer les meshes VANGUARD et matériaux PBR déjà créés (IDs Roblox
   autorisés), sans annoncer les assets comme intégrés tant que les ID sont à zéro.
4. **Lisibilité et optimisation** : refaire les essais au combat sur Android/PC avec P95/P99, collisions,
   sprint/slide/wallrun, transitions d'arme, spawn et quatre bots.
5. **Duel original 1v1** : après la stabilisation du FFA, livrer un mode séparé et complet, manches
   premier à cinq, adversaire humain, abandon/rematch, résultats autoritaires; étendre ensuite 2v2–5v5.

## Itération livrée dans le code — convergence camera/head

Les armes à rayons, le shotgun et le couteau conservent **leur origine du tir dans la tête serveur**.
Un point de visée acquis par un raycast serveur depuis l'origine caméra annoncée peut seulement orienter
le tir de la tête vers la surface réellement visée. L'origine caméra est optionnelle, limitée à un offset
de 4,5 studs, et vérifiée non masquée depuis la tête. Aucun résultat de touche envoyé par le client
n'est accepté. Un offset excessif, une caméra bloquée ou un angle incohérent entraîne un repli vers
l'ancien rayon partant de la tête : pas de rejet injuste des tirs en cas de retard réseau.

Cette convergence effectue au plus deux raycasts serveur supplémentaires par tir dont la caméra est
admissible. Elle réutilise le filtre du personnage déjà mis en cache. Pas de dépendance ni d'asset payant.

## Critères de validation dans Roblox Studio (non testables par la CI)

- Tirer au pistolet puis au fusil sur une petite cible à 5, 15 et 50 studs ; comparer l'alignement
  du réticule, le serveur et les impacts visuels avant/après, à l'arrêt et en strafe.
- Tirer contre un conteneur depuis une position collée puis en sortie de couverture : aucun hit
  à travers l'obstacle même si la caméra a momentanément vue sur la cible.
- Exécuter sniper/shotgun/couteau, rechargements, respawns, bots et 100 coups automatiques
  (avec latence simulée si possible) : aucune anomalie de munitions, de cadence ou de killfeed.
- Avec MicroProfiler, mesurer le coût ajouté de 1–2 raycasts pour chaque tir convergé.
- Vérifier les inputs PC et Android, y compris une caméra rapidement déplacée, une pente,
  un wallrun et un joueur derrière une couverture.

La CI compile les modules, vérifie la politique mathématique et les contrats d'intégration.
Elle ne remplace ni le test moteur ni les mesures de FPS/latence.
