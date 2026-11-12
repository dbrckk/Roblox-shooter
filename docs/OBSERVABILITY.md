# Observabilité et plafond de serveur — socle hors ligne (lot 0b)

**Date :** 12 novembre 2026 · **Plan de référence :** [audit d'écart RIVALS](AUDIT_ECART_RIVALS_2026-11-12.md) §LOT 0 · **Backlog actif :** [V3](ROADMAP_V3_SANS_TEST_ANDROID.md)

Ce lot répond à une question simple : aujourd'hui, l'état réel de la version publiée est **inconnu**. Les `warn` du serveur disparaissent dans la sortie Studio, la taille de serveur n'est décidée nulle part, et personne ne sait si un joueur qui rejoint atteint un premier kill, termine une manche, ou revient. Le socle ci-dessous rend ces mesures calculables ; il ne les mesure pas encore, faute de sessions réelles.

## 1. Pourquoi ce lot

Trois constats vérifiés dans le dépôt, pas trois intuitions :

- **Aucun plafond de serveur n'existe.** `default.project.json` et `game/` ne déclarent aucun `Players.MaxPlayers`. La population maximale est donc celle que Roblox applique par défaut, et rien dans le code ne dit ce que `MatchService` suppose.
- **Le duel exige exactement deux joueurs.** `readyPlayers()` retourne `nil` dès que `#players ~= 2` : sur un serveur très peuplé, un duel ne peut plus démarrer, sans qu'aucun message ne l'explique.
- **Les échecs ne sont pas agrégés.** `ProgressionService`, `WeaponService` et `MatchService` émettent des `warn` utiles, mais rien ne les conserve : savoir si la v54 échoue en production demande aujourd'hui de la chance et un client ouvert.

## 2. Funnel — `src/shared/TelemetryFunnel.luau`

Quatre étapes, marquées **une seule fois** : `JOINED`, `FIRST_KILL`, `ROUND_COMPLETED`, `SECOND_SESSION`.

| Mesure | Règle |
|---|---|
| `uniquePlayers` | premier `recordJoin` d'un `UserId` inconnu ; un retour ne compte pas deux fois |
| `SECOND_SESSION` | deuxième visite d'un joueur déjà vu, marquée une seule fois |
| `kills` | un par kill accepté, attribué à l'arme qui l'a marqué |
| `rounds.completed` / `abandoned` | `ROUND_COMPLETED` n'est marqué que par une manche réellement terminée |
| `averageSeconds` | moyenne sur **toutes** les manches, abandonnées comprises |
| `abandonRate` | part des manches jamais terminées, dans `[0, 1]` |

Bornes, parce qu'un serveur vit longtemps : 64 joueurs suivis, 24 armes distinctes puis un seau `other`, identifiants tronqués à 32 caractères, durée de manche plafonnée à 1 h (au-delà, c'est un bug de mesure, pas une manche). Toute entrée invalide (`NaN`, `UserId` nul, durée négative, complétion non booléenne) **lève une erreur** au lieu de fausser silencieusement les compteurs. `snapshot()` renvoie une copie détachée : un tableau de bord ne peut pas réécrire les compteurs vivants.

Le module ne publie rien : ni remote, ni HTTP, ni DataStore. C'est le serveur qui décide où va un instantané, ce qui garde la comptabilité déterministe et testable hors moteur.

## 3. Plafond de serveur — `src/shared/ServerCapacity.luau`

**Décision :** `MAX_PLAYERS = 12`, dont `SPECTATOR_SLOTS = 2`, soit `COMBATANT_LIMIT = 10` combattants.

Répartition d'un joueur qui rejoint, selon la population **avant** son arrivée :

| Population | Accueil |
|---:|---|
| 0 à 9 | `COMBATANT` |
| 10 à 11 | `SPECTATOR` |
| 12 et plus | `FULL` |

Le budget de bots reprend **exactement** la formule de `BotService` (`max(0, min(MaxCombatants - humains, MaxBots))`), pour qu'un changement de capacité ne déforme pas silencieusement l'IA. `BotConfig.MaxCombatants = 6` reste le plafond d'apparition des bots ; c'est une contrainte différente du plafond de serveur, et le contrat vérifie que les deux tiennent dans `COMBATANT_LIMIT`.

`checkPlaceMaxPlayers(valeur)` nomme l'état réel du place : `UNSET`, `TOO_SMALL`, `EXACT` ou `OVERFLOW`. **`UNSET` est précisément le trou que ce lot existe pour fermer** : un maximum non déclaré n'est pas une politique, c'est ce que Roblox décide.

## 4. Journal d'erreurs — `src/shared/DiagnosticsLog.luau`

Un journal borné, dédupliqué et honnête sur ce qu'il a perdu :

- une paire `(catégorie, message)` identique devient un **compteur** (`count`, `firstSeen`, `lastSeen`) au lieu d'occuper une ligne par occurrence ;
- capacité par défaut 64 entrées, plafonnée à 256 : un appelant ne peut pas transformer le journal en fuite mémoire ;
- à saturation, l'entrée **la plus ancienne** est évincée et `evicted` l'enregistre ; `saturated()` permet au tableau de bord de dire « historique incomplet » plutôt que de faire croire à un résumé exhaustif ;
- textes tronqués (catégorie 24, message 200 caractères) et **la troncature fait partie de l'identité** : deux messages qui partagent un préfixe deviennent un compteur, jamais des lignes illimitées ;
- instantané trié par volume puis par ancienneté, en copie détachée.

## 5. Ce qui reste à câbler

### Câblé le 12 novembre 2026 — `src/server/ObservabilityService.luau`

Le service est démarré **avant** `ProgressionService` dans `src/server/init.server.luau`, pour voir les avertissements émis au démarrage.

| Élément | Ce qui est fait | Effet observable |
|---|---|---|
| Classification à l'arrivée | `ServerCapacity.classify(population)` sur `PlayerAdded`, où `population` exclut l'arrivant | attribut `IronYardSlot` = `COMBATANT` / `SPECTATOR` / `FULL` sur le joueur |
| Funnel | `TelemetryFunnel.recordJoin(funnel, player.UserId)` | `IronYardFunnelJoined`, `IronYardFunnelPlayers`, `IronYardFunnelReturning` sur `Workspace` |
| Journal d'erreurs | `LogService.MessageOut` filtré sur `MessageWarning`, bucketé par `DiagnosticsLog.categorize` | `IronYardLogDistinct`, `IronYardLogEvicted`, `IronYardLogSaturated` sur `Workspace` |
| Places libres | `ServerCapacity.freeSlots(population)` | `IronYardFreeSlots` sur `Workspace` |

Trois garde-fous sont volontaires, et le contrat les vérifie :

- **Aucun `kick`, aucun déplacement de joueur.** Un arrivant au-delà de la politique est étiqueté `FULL` et journalisé ; le plafond dur reste `Players.MaxPlayers`, parce qu'une règle d'expulsion écrite ici serait un comportement serveur non testé.
- **Aucun `warn` dans le handler `MessageOut`.** Ce handler voit tous les avertissements : y imprimer boucherait la boucle. Le service ne réécrit rien, il bucketise.
- **Aucun remote client.** Les compteurs sortent en attributs de `Workspace`, écrits par le serveur seul.

### Reste à faire

1. **Déclarer `Players.MaxPlayers = 12`** dans les paramètres du place (hors dépôt aujourd'hui : `default.project.json` ne porte pas cette valeur, `game/` ne contient que `VISION.md`). Tant que ce n'est pas fait, `IronYardSlot` décrit une politique que Roblox ne fait pas respecter.
2. **Brancher les kills et les manches** : `FIRST_KILL` et `ROUND_COMPLETED` restent à marquer depuis `CombatAwards`/`ScoreService` et depuis la fin de manche de `MatchService`. Ces points touchent l'attribution des dégâts et la vie de la manche : PR séparée, CI verte, preuve en moteur.
3. **Choisir la destination d'un instantané** : DataStore agrégé ou `AnalyticsService`, jamais un remote client.
4. **Construire le tableau de bord interne** exigé par la sortie du lot 0b.

## 6. Limites

- **Aucune session réelle n'a été observée.** Ces suites prouvent que les compteurs sont justes, pas que des joueurs rejoignent, tuent, terminent une manche ou reviennent.
- **Aucun `Players.MaxPlayers` n'a été appliqué** : la décision est écrite et testée, le place n'est pas configuré pour autant.
- **Aucune agrégation inter-serveurs** : ni DataStore, ni `AnalyticsService`, ni tableau de bord.
- **Le câblage n'a pas été exécuté en moteur.** `LogService.MessageOut` côté serveur, l'ordre de démarrage et le comportement aux arrivées sont vérifiés statiquement par le contrat, pas observés sur un serveur Roblox.
- **Les kills et les manches ne sont pas encore marqués** : le funnel est alimenté par les arrivées uniquement, donc `FIRST_KILL` et `ROUND_COMPLETED` restent faux en jeu.
- Les modules partagés ne sont volontairement requis par aucun script client ; `check_observability_contract.py` vérifie cette exclusivité, pas leur intégration au serveur.
