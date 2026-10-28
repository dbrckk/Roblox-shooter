# REA: analyse réelle d'un FPS open source et application au projet

**Outil exécuté** : `rea-agents@6.8.0 analyze-javascript-application`, workflow GitHub Actions [REA FPS reference analysis](https://github.com/dbrckk/Roblox-shooter/actions/runs/40723443779), succès le 28 octobre 2026.

**Cible** : [Hazzad123/fully-ai-arena-fps](https://github.com/Hazzad123/fully-ai-arena-fps/tree/920b123d67015d5e8151a4ebd6742d8015d538be) à commit figé. Code MIT, © 2026 Ben Darling ; assets tiers sous conditions propres ; aucun asset n'a été repris.

## Résultat vérifiable de REA

- 55 fichiers JavaScript parsés, aucun échec d'analyse, 102 106 nœuds AST visités.
- 1 258 observations statiques.
- Les chemins effectivement identifiés dans le rapport incluent `server/modes.js`, `server/room.js`, `server/ai.js`, `server/validate.js`, `shared/weapons.js`, `shared/collision.js`, `client/src/weaponView.js` et `client/src/net.js`.
- REA décrit une **analyse statique** : les relations de dépendance ne prouvent pas le comportement réel ; l'exécution de l'application n'a pas été réalisée.
- L'Evidence complète (JSON volumineux) et son résumé sont conservés comme **artifacts GitHub Actions** pour consultation (durée limitée).

## Inspection des sources identifiées après REA

Le fichier `server/modes.js` isole les règles de mode, d'affectation d'équipe, de victoire et d'élimination ; `server/room.js` détient les états du round et le temps ; `server/ai.js` contient le comportement des adversaires (perception, ligne de vue, poursuite et imprécision de visée), et `shared/weapons.js` contient des profils d'armes/TTK. Ces observations viennent de la lecture du **code libre correspondant**, en complément de l'inventaire REA ; elles ne sont pas des tests runtime.

## Transposition originale dans NEON STRIKE

- `src/server/MatchService.luau` : machine de phases serveur indépendante des dégâts (WAITING/COUNTDOWN/LIVE/RESULTS).
- `src/client/MatchHud.client.luau` : annonce du round, chrono et objectif d'éliminations, gagnant.
- `src/server/WeaponService.luau` : le serveur accepte les tirs pendant LIVE uniquement, rejette les vecteurs non finis, et refuse un tir d'arme non équipée.
- Les scripts sont une **nouvelle implémentation Luau originale**, pas une traduction/copier-coller du code d'Arena FPS.
- Mode FFA entraînement et PvP libre; **aucun matchmaking, IA mobile ou duel équipe 5v5** n'est annoncé comme achevé.
- Compilation Rojo requise et comportement Roblox Studio / Android encore à tester.
