# IRON YARD — matrice des transitions de manche (A1, V3)

**Date : 12 novembre 2026** · **Source inspectée :** `src/server/MatchService.luau` (541 lignes), `DuelRules`, `DuelCombatState`, `MatchLobbyPolicy`, `RoundStandings`, `VictoryAwardPolicy`, `CombatAwards`, `WeaponService` (gardes de phase), `SpawnService`.
**Rôle :** établir la liste **fermée** des états et des transitions réellement atteignables depuis les handlers serveur, puis la vérifier en CI. Ce document décrit le code tel qu'il est : il ne propose aucun nouveau mode et ne réécrit aucune règle.

> **Résultat de l'audit : aucun défaut de transition démontré.** Les onze cas exigés par A1 produisent déjà le résultat attendu par les politiques pures. **Aucun comportement de manche n'a donc été modifié** : le lot livre la matrice, ses tests et un contrat anti-dérive. Les points restant à prouver sont moteur (deux clients Roblox réels, réseau perturbé), pas logiques.

## 1. États

| Phase | Sens | Entrée | Sortie |
|---|---|---|---|
| `WAITING` | aucun match publié | démarrage serveur, roster vidé | `COUNTDOWN` dès qu'un joueur est présent |
| `COUNTDOWN` | 6 s avant `startRound` | `WAITING`, fin de `RESULTS` | `LIVE` (FFA), `DUEL_PREP` ou `DUEL_BREAK` (duel) |
| `LIVE` | manche jouable | fin de `COUNTDOWN`, fin de `DUEL_PREP` | `RESULTS` (FFA ou série close), `DUEL_BREAK`, `DUEL_PREP` (duel accepté en cours de FFA) |
| `DUEL_PREP` | 3 s, deux racines ancrées | `startDuelBout` réussi | `LIVE` si la préparation est `READY`, `DUEL_BREAK` si interrompue, `RESULTS` si les participants changent |
| `DUEL_BREAK` | 7 s entre deux manches de duel (2 s au premier échec, 1 s en réessai) | fin de manche, préparation interrompue, échec de placement | `DUEL_PREP`, `DUEL_BREAK` (réessai borné), `RESULTS` (récupération expirée) |
| `RESULTS` | 12 s, tableau final figé | fin de manche FFA, fin de série, abandon, lobby modifié | `COUNTDOWN` uniquement |

`mode` ne prend que `FFA` ou `DUEL`. `DUEL_PREP` et `DUEL_BREAK` n'existent qu'en mode `DUEL` ; `RESULTS` remet `mode = "FFA"` et `duel = nil` avant de repartir.

## 2. Événements réellement possibles

Aucun événement client ne pilote directement une phase. Les seules entrées sont `SetDuelReady` (booléen, rate-limité par `RemoteGuard`) et la boucle `tick()` à 0,2 s qui observe le roster, les délais, la santé et les drapeaux de préparation.

| Événement | Origine | Effet |
|---|---|---|
| `RosterEmptied` | `Players.PlayerRemoving` | `WAITING`, duel et podium effacés (`MatchLobbyPolicy`) |
| `DuelRequested` | `SetDuelReady × 2`, exactement 2 joueurs | `DUEL` : série ou manche immédiate |
| `StartDeadline` | fin de `COUNTDOWN` | `startRound` : duel si consentement complet, sinon FFA |
| `BoutDecided` | santé serveur d'une manche | point, `DRAW`, ou fin de série |
| `PrepDeadline` | 3 s écoulées | `LIVE` si `DuelRules.prepState == READY` |
| `PrepInterrupted` | personnage mort/remplacé, racine désancrée | `DUEL_BREAK` sans crédit |
| `BreakDeadline` | 7 s écoulées | nouvelle manche ou réessai |
| `RecoveryExpired` | 20 s cumulées (`DuelRules.recoveryExpired`) | `RESULTS` sans vainqueur |
| `RoundDeadline` | 240 s (FFA) ou 80 s (duel) | résultats |
| `ScoreLimit` | 15 éliminations FFA | résultats |
| `ParticipantsChanged` | départ, arrivée d'un tiers, remplacement | `RESULTS` (forfait ou annulation) |
| `ResultsDeadline` | 12 s écoulées | `COUNTDOWN`, `duel` et `mode` remis à zéro |

## 3. Matrice des transitions légales

| Depuis \ Vers | `WAITING` | `COUNTDOWN` | `LIVE` | `DUEL_PREP` | `DUEL_BREAK` | `RESULTS` |
|---|---|---|---|---|---|---|
| `WAITING` | état vide idempotent | **oui** | non | non | non | non |
| `COUNTDOWN` | oui (roster vide) | non | **oui** (FFA) | **oui** (duel) | **oui** (placement impossible) | non |
| `LIVE` | oui (roster vide) | non | non | **oui** (duel accepté) | **oui** (série en cours) | **oui** |
| `DUEL_PREP` | oui (roster vide) | non | **oui** | non | **oui** (interruption) | **oui** (participants modifiés) |
| `DUEL_BREAK` | oui (roster vide) | non | non | **oui** | **oui** (réessai borné) | **oui** (récupération expirée) |
| `RESULTS` | oui (roster vide) | **oui** | non | non | non | non |

**Arêtes interdites et pourquoi :**

- `RESULTS → LIVE/DUEL_*` : `RESULTS` remet `duel = nil` et `mode = "FFA"` ; tout rejeu passe par `COUNTDOWN`.
- `WAITING → LIVE` : le compte à rebours ne peut pas être contourné, même par un `SetDuelReady`.
- `COUNTDOWN → RESULTS` : aucune manche n'a encore de score.
- `DUEL_PREP → DUEL_PREP` : une préparation ratée repasse par `DUEL_BREAK`, jamais par un nouveau `DUEL_PREP`.
- `DUEL_PREP → RESULTS` est **légal uniquement** quand les participants changent (départ d'un combattant, tiers entrant) : `MatchService` termine alors la série par `endDuel` au lieu de laisser une préparation orpheline. Une simple interruption de préparation passe par `DUEL_BREAK`, jamais par un résultat.
- `LIVE → DUEL_BREAK` en `FFA` : impossible, `DUEL_BREAK` n'a de sens qu'avec une série.

## 4. Cas A1 et leur couverture

| # | Cas V3 | Résultat attendu (vérifié) | Vérifié par |
|---|---|---|---|
| T1 | Joueur retiré avant le départ | 1 joueur restant → `FFA`/`LIVE` ; 0 joueur → `WAITING` | `DuelRules.canStart`, `MatchLobbyPolicy` |
| T2 | Doublons `SetDuelReady` | pose d'attribut idempotente ; l'état reste `DUEL` | modèle d'attribut + `canStart` |
| T3 | Départ simultané des deux | `WAITING`, aucun `RESULTS`, aucun crédit | `forfeitSide({}) == nil`, `shouldReset` |
| T4 | Morts simultanées | `DRAW`, aucun point, série continue | `DuelRules.boutWinner(0,·,0,·)` |
| T5 | Défaite au temps | santé relative, `DRAW` si égalité | `boutWinner(..., expired)` |
| T6 | Égalité de manche | `DRAW` publié, aucun XP de victoire | `advance`, `VictoryAwardPolicy` |
| T7 | Mort après changement de phase | aucun tir/dégât hors `LIVE` | `DuelCombatState.canFire`, garde de phase `WeaponService` |
| T8 | Respawn tardif | préparation `INTERRUPTED`, pas de seconde vie | `prepState`, `healthForBout` |
| T9 | Lobby avec troisième joueur | `LOBBY_CHANGED` depuis `LIVE`, `DUEL_PREP` ou `DUEL_BREAK`, aucun vainqueur inventé | `sameParticipants`, `forfeitSide`, arête `DUEL_PREP → RESULTS` |
| T10 | Redémarrage de manche | `advance` refuse après clôture, prime réarmée une seule fois | `DuelRules.advance`, `VictoryAwardPolicy.reset` |
| T11 | Nouvelle demande de duel | consentement consommé, rejeu via `COUNTDOWN` | `startDuelSeries` + matrice |

## 5. Invariants

1. **Aucun vainqueur inventé** : un crédit de victoire exige un participant d'origine encore présent (`forfeitSide`) et une série close par `SCORE_LIMIT` ou `BOUT_LIMIT` avec un leader réel (`advance`).
2. **Aucun blocage** : toute série se termine en 24 manches au plus, et tout échec de placement est borné par 20 s de récupération cumulée.
3. **Aucune seconde vie** : un personnage remplacé ne peut ni tirer, ni encaisser, ni consommer une préparation ancrée.
4. **Aucune phase sans successeur** : chaque phase possède au moins une arête sortante, et `RESULTS` est le seul état à ne pouvoir que revenir à `COUNTDOWN` ou `WAITING`.
5. **Un seul crédit par manche** : `VictoryAwardPolicy.claim` est armé avant toute écriture et réarmé au démarrage de manche.

## 6. Preuves attendues hors CI

`scripts/test_match_transitions.luau` vérifie les **règles de décision** et la fermeture de la matrice, `scripts/check_match_transition_contract.py` vérifie que la matrice correspond aux `transition(...)` réellement écrites dans `MatchService`. Aucun test CI ne simule un `RemoteEvent`, une réplication Roblox, une physique de personnage ou une latence. Les preuves suivantes restent exigées en Studio : deux joueurs réels, abandon de chaque côté, tiers entrant, respawn pendant `DUEL_PREP`, manche nulle répétée jusqu'à la limite.
