# Première minute de jeu — lot C2 de la V3

**Date :** 12 novembre 2026 · **Backlog actif :** [V3](ROADMAP_V3_SANS_TEST_ANDROID.md) · **Preuve exécutable :** `scripts/test_first_minute.luau` · **Contrat :** `scripts/check_first_minute_contract.py`

Ce lot répond à une question qu'un build vert ne tranche pas : **ce que le joueur voit pendant la première minute se contredit-il ?** Une carte de briefing qui parle encore pendant le résultat, un panneau de progression qui annonce une sauvegarde non confirmée, un bouton de tir à moitié hors écran sur un téléphone 20:9 : rien de tout cela ne casse la compilation. Le contrat ci-dessous les rend vérifiables hors moteur.

## 1. Parcours verrouillé

`src/shared/HudSurfacePlan.luau` fixe l'ordre des neuf étapes de la première partie :

`JOIN` → `OBJECTIVE` → `AIM` → `FIRE` → `RELOAD` → `DEATH` → `RESPAWN` → `RESULT` → `PROGRESSION`

`Plan.reached(evidence)` n'accorde une étape que si **sa propre preuve existe** *et* si la précédente est atteinte. Deux conséquences testées :

- une carte de résultat présente dès l'arrivée ne compte pas : `RESULT` exige `DEATH` et `RESPAWN` ;
- `Plan.missing(reached)` nomme la première étape manquante, donc un échec dit `FIRE` et pas « index 4 ».

Les textes du parcours viennent des modules réellement livrés, pas de la suite : `FirstMatchGuide.objective(15)` donne `FIRST TO 15 ELIMINATIONS`, `Guide.hint(...)` donne les commandes tactiles, clavier ou manette, `DefeatPresentation.labels(...)` donne la carte de défaite (`ELIMINATED`, `REDEPLOY IN  3s`, `SPAWN SHIELD 2.5s`, verdicts de bout en duel).

## 2. Surfaces HUD

Sept surfaces sont auditées : `briefing`, `tactical`, `killFeed`, `defeat`, `results`, `progression`, `privatePerf`. Les règles reproduisent les conditions des clients livrés :

| Surface | Visible quand | Source dans le jeu |
|---|---|---|
| `briefing` | `COUNTDOWN` ou `LIVE`, ni options ouvertes ni carte déjà fermée | `Briefing.client.luau` |
| `tactical` | phase ≠ `WAITING` et panneau de briefing fermé | `TacticalHud.client.luau` |
| `killFeed` | `LIVE` sur un écran assez large | `KillFeed.client.luau` |
| `defeat` | joueur mort, en `LIVE` ou en `DUEL_BREAK` d'un duel | `DefeatScreen.client.luau` |
| `results` | `RESULTS` uniquement | `RoundResults.client.luau` |
| `progression` | phase ≠ `RESULTS` et briefing fermé | `ProgressionHud.client.luau` |
| `privatePerf` | Studio **et** propriétaire de la place **et** opt-in | `PerfOverlay.client.luau` |

`Plan.audit(ctx, observed)` compare ce qu'un client déclare dessiner au plan et nomme chaque écart (`results must be hidden`, `killFeed must be visible`…). Deux paires sont interdites quelle que soit la déclaration : le résultat de manche avec la carte de défaite, et le résultat avec le fil d'éliminations.

## 3. Contrôles tactiles

La géométrie est celle qui est déjà livrée (`TouchLayout.compute` / `TouchLayout.check`), mesurée sur cinq écrans : 16:9 petit (640×360), 16:9 avec encoche (640×336), 20:9 (960×432), 20:9 avec encoche (960×408) et tablette 1024×576, pour les trois presets `COMPACT`, `STANDARD`, `LARGE` — **15 agencements**.

À chaque fois : aucun chevauchement, aucun contrôle sous la bande HUD supérieure (`y ≥ 78`), aucune cible plus petite que 28 pixels, accès aux options libre, tir à droite de l'ADS et dans la zone du pouce droit. Un contrôle déplacé dans la bande supérieure est **refusé** : la vérification n'est pas complaisante.

## 4. Bots et humains

- `BotService` marque chaque bot : `model:SetAttribute("IsArenaBot", true)`.
- `MatchService` publie `NeonBotCount`, que `MatchHud` affiche comme **compte de bots**, séparé des joueurs.
- Le contrat interdit que le HUD de match relabelle un bot comme joueur humain : aucun faux joueur connecté.

## 5. Limites

- **Aucun fichier client n'est modifié par ce lot.** Le HUD livré reste identique ; le plan décrit ses conditions et la CI échoue si elles changent, mais **aucune preuve visuelle** n'est apportée : ni capture, ni rendu, ni test sur appareil.
- **La maniabilité réelle n'est pas mesurée.** Les 15 agencements prouvent que les rectangles ne se chevauchent pas et restent dans l'écran ; ils ne prouvent ni la taille perçue, ni l'accessibilité au pouce, ni la latence tactile.
- **Les encoches sont simulées** par une hauteur utile réduite : aucun inset système réel n'est lu, puisque `TouchLayout` raisonne dans la racine déjà sûre de la `ScreenGui`.
- **Le ressenti de la première minute** (comprend-on l'objectif, la carte de défaite, le résultat ?) reste à valider avec un joueur ; le contrat ne vérifie que l'ordre, la cohérence des textes et l'absence de doublons d'état.
- **Rien n'est mesuré en performance** : la suite ne mesure aucune image, aucun temps CPU, et ne revendique aucun gain.
