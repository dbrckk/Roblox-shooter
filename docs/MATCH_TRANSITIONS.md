# IRON YARD — matrice des transitions de manche (A1, V3)

**Audit initial : 12 novembre 2026** · **Source inspectée :** `src/server/MatchService.luau` (541 lignes), `DuelRules`, `DuelCombatState`, `MatchLobbyPolicy`, `RoundStandings`, `VictoryAwardPolicy`, `CombatAwards`, `WeaponService` (gardes de phase), `SpawnService`.
**Rôle :** établir la liste **fermée** des états et des transitions réellement atteignables depuis les handlers serveur, puis la vérifier en CI. Ce document décrit le code tel qu'il est : il ne propose aucun nouveau mode et ne réécrit aucune règle.

> **Résultat de l'audit : aucun défaut de transition démontré.** Les onze cas exigés par A1 produisent déjà le résultat attendu par les politiques pures. **Aucun comportement de manche n'a donc été modifié dans cet audit initial** : le lot livre la matrice, ses tests et un contrat anti-dérive. Les points restant à prouver sont moteur (deux clients Roblox réels, réseau perturbé), pas logiques.

## Parcours public du 1v1 réservé

Le menu **1v1** (touche **V** sur PC) propose une recherche dans le serveur FFA courant et une invitation ciblée à un joueur de ce serveur. Une invitation exige l’accord des deux. La FFA continue pour le reste du serveur. Les deux combattants rejoignent une instance réservée de la place publique existante, sans création d’une autre expérience.

Une invitation reste valable 30 secondes. Le bouton **ACCEPT** répond uniquement à l’invitation affichée. Si elle a expiré, a été annulée ou a été remplacée, cette réponse ne modifie pas la recherche du destinataire. Il peut accepter une nouvelle invitation dès qu’elle s’affiche.

**DECLINE** retire l’invitation affichée et indique immédiatement le refus à l’émetteur. La recherche en cours du destinataire continue. S’il reste d’autres invitations, la suivante s’affiche dans le même menu.

Le serveur source enregistre les deux identités dans MemoryStore avant le transfert. Le serveur réservé vérifie son roster avant de démarrer le compte à rebours. L’armement et les dégâts suivent les personnages des combattants admis. Le retour en FFA est automatique après les résultats, sauf si les deux combattants choisissent **REMATCH**. **BACK TO FFA** permet de revenir plus tôt ou de réessayer un retour échoué. Si un seul joueur arrive, l’attente est bornée et le retour est proposé. Roblox Studio conserve le duel local pour vérifier les transitions sans téléportation.

Une fois un retour en FFA engagé, la salle réservée ferme la revanche, même si le transfert échoue. Après un échec ou un délai dépassé, **BACK TO FFA** redevient disponible. La relance reste individuelle et n’est pas déclenchée en boucle par le serveur.

Le premier joueur admis déclenche une attente de 40 secondes, affichée dans le HUD. Si le second est admis avant l’échéance, le duel peut commencer et les revanches conservent leur fonctionnement. Si l’échéance est atteinte, les joueurs admis repartent en FFA, même si le second arrive avant la prochaine mise à jour du serveur.

**Validation publiée à faire**

1. Avec trois joueurs dans une FFA, lancer deux recherches. Vérifier que les deux volontaires se retrouvent seuls en duel et que le troisième poursuit sa manche.
2. Répéter avec une invitation et vérifier que le duel commence uniquement après acceptation. Tester aussi l’expiration et le départ du destinataire.
3. Jouer jusqu’aux résultats. Faire une revanche à deux, puis vérifier le retour en FFA si un seul joueur accepte. Vérifier également le départ pendant une manche et pendant le compte à rebours.
4. Vérifier la restauration de l’XP après le retour, puis jouer sur Android avec les menus et le panneau PERF.

## 1. États

| Phase | Sens | Entrée | Sortie |
|---|---|---|---|
| `WAITING` | aucun match publié | démarrage serveur, roster vidé | `COUNTDOWN` dès qu'un joueur est présent |
| `COUNTDOWN` | 6 s avant `startRound` | `WAITING`, fin de `RESULTS` | `LIVE` (FFA), `DUEL_PREP` ou `DUEL_BREAK` (duel) |
| `LIVE` | manche jouable | fin de `COUNTDOWN`, fin de `DUEL_PREP` | `RESULTS` (FFA ou série close), `DUEL_BREAK`, `DUEL_PREP` (duel local accepté en cours de FFA) |
| `DUEL_PREP` | 3 s, deux racines ancrées | `startDuelBout` réussi | `LIVE` si la préparation est `READY`, `DUEL_BREAK` si interrompue, `RESULTS` si les participants changent |
| `DUEL_BREAK` | 7 s entre deux manches de duel (2 s au premier échec, 1 s en réessai) | fin de manche, préparation interrompue, échec de placement | `DUEL_PREP`, `DUEL_BREAK` (réessai borné), `RESULTS` (récupération expirée) |
| `RESULTS` | 12 s, tableau final figé | fin de manche FFA, fin de série, abandon, lobby modifié | `COUNTDOWN` uniquement |

`mode` ne prend que `FFA` ou `DUEL`. `DUEL_PREP` et `DUEL_BREAK` n'existent qu'en mode `DUEL`. La fin de `RESULTS` efface la série avant de repartir sur un compte à rebours. Dans une instance réservée, ce compte à rebours exige le consentement des deux combattants.

## 2. Événements réellement possibles

Aucun événement client ne pilote directement une phase. `SetDuelReady` enregistre une recherche, une invitation ou un choix de revanche. `ReturnToFfa` demande un retour depuis une instance réservée en attente, pendant le compte à rebours ou aux résultats. Les deux événements sont limités par `RemoteGuard`. La boucle `tick()` observe les joueurs admis, les délais et l’état des personnages.

| Événement | Origine | Effet |
|---|---|---|
| `RosterEmptied` | `Players.PlayerRemoving` | `WAITING`, duel et podium effacés (`MatchLobbyPolicy`) |
| `DuelRequested` | `SetDuelReady × 2`, deux demandes compatibles | Transfert des deux joueurs vers une instance réservée, ou duel local dans Studio |
| `StartDeadline` | fin de `COUNTDOWN` | `startRound` : duel si la paire attendue est présente en instance réservée, sinon FFA en instance publique |
| `BoutDecided` | santé serveur d'une manche | point, `DRAW`, ou fin de série |
| `PrepDeadline` | 3 s écoulées | `LIVE` si `DuelRules.prepState == READY` |
| `PrepInterrupted` | personnage mort/remplacé, racine désancrée | `DUEL_BREAK` sans crédit |
| `BreakDeadline` | 7 s écoulées | nouvelle manche ou réessai |
| `RecoveryExpired` | 20 s cumulées (`DuelRules.recoveryExpired`) | `RESULTS` sans vainqueur |
| `RoundDeadline` | 240 s (FFA) ou 80 s (duel) | résultats |
| `ScoreLimit` | 15 éliminations FFA | résultats |
| `ParticipantsChanged` | départ, remplacement ou arrivée d'un tiers en test local | `RESULTS` (forfait ou annulation) |
| `ResultsDeadline` | 12 s écoulées | `COUNTDOWN` en FFA ou sur accord de revanche. En instance réservée sans accord, retour à la FFA publique |

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

- `RESULTS → LIVE/DUEL_*` : tout rejeu efface la série précédente et passe par `COUNTDOWN`.
- `WAITING → LIVE` : le compte à rebours ne peut pas être contourné, même par un `SetDuelReady`.
- `COUNTDOWN → RESULTS` : aucune manche n'a encore de score.
- `DUEL_PREP → DUEL_PREP` : une préparation ratée repasse par `DUEL_BREAK`, jamais par un nouveau `DUEL_PREP`.
- `DUEL_PREP → RESULTS` est **légal uniquement** quand les participants changent (départ d'un combattant, ou tiers entrant dans un test local) : `MatchService` termine alors la série par `endDuel` au lieu de laisser une préparation orpheline. Une simple interruption de préparation passe par `DUEL_BREAK`, jamais par un résultat.
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
| T9 | Lobby Studio avec troisième joueur | `LOBBY_CHANGED` depuis `LIVE`, `DUEL_PREP` ou `DUEL_BREAK`, aucun vainqueur inventé | `sameParticipants`, `forfeitSide`, arête `DUEL_PREP → RESULTS` |
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
