# IRON YARD — correction production : spawns physiquement validés

**13 novembre 2026** · base `79f336533e7377fc3757c92756a0e258d102f172` · version Roblox publique **v62 (place 58)**.

## Défaut confirmé dans la version précédente

`SpawnService.safestPosition()` vérifiait 12 points et le centre.
Si tous étaient physiquement bloqués, la dernière branche sélectionnait
**quand même un de ces points**, même après un résultat négatif de
`Workspace:GetPartBoundsInBox`. Le bouclier de 2,5 secondes protège des
tirs, pas des collisions : le joueur ou le bot pouvait se retrouver
enfermé dans un obstacle. De plus, `BotService.resetRound()` faisait
`CFrame.new(SpawnService.selectSafeSpawn(...))` sans vérifier le résultat.

## Correctif de fonctionnement (pas d'art ni de prototype)

1. Conserver les 12 spawns validés et le point central.
2. En dernier recours seulement, explorer une grille **7 × 7**, soit
   49 emplacements à y=3,4 studs dans la carte existante, avec le
   **véritable contrôle de collisions Workspace**, puis noter uniquement
   les cases dégagées selon le score de proximité et de ligne de vue.
3. Si aucune position n'est dégagée, **ne jamais forcer un téléport dans
   un mur**. Les joueurs conservent leur personnage Roblox réel et
   essaient de nouveau au maximum 2 fois à 0,7 seconde d'intervalle,
   sans jamais interférer avec un duel ou un avatar remplacé.
4. Un bot ne peut plus être construit sans position sûre ; la
   réconciliation des 4 slots le réessaie normalement toutes les
   1,25 seconde. À la réinitialisation d'une manche, un bot vivant
   reste en place si aucune nouvelle position valide n'est disponible ;
   aucune création d'un CFrame invalide ni interruption de la boucle.
5. Le mode 1v1 reste strictement sur ses points opposés physiques
   prévalidés, sans sélection d'un point flexible pouvant déséquilibrer
   le duel.

## Vérifications automatiques

- Exécuter la suite Luau réelle `scripts/test_spawn_safety.luau`
  sur les 49 cases, collision totale, un seul point libre, meilleur
  de deux points libres, NaN et score infini.
- Compiler chaque fichier Luau et construire la place Rojo.
- Contrat source `scripts/check_production_spawn_fallback.py` vérifiant
  l'intégration des collisions en direct, l'absence de téléportation
  bloquée et la conservation des spawns stricts en duel.
- Vérifier en jeu la naissance des bots et des joueurs, le début de FFA,
  la réapparition après élimination, la rotation vers un duel, puis le
  retour au FFA. Aucune exécution Roblox Studio ne peut être inférée
  du simple passage de la CI.

**Limite raisonnable :** si *toute* la zone est véritablement saturée de
collisions, le système refuse le téléport dangereux ; il ne peut pas
fabriquer une position libre. Aucun art ou hitbox n'est ajouté.
