# Audit de cycle de vie — lot C1 de la V3

**Date :** 12 novembre 2026 · **Backlog actif :** [V3](ROADMAP_V3_SANS_TEST_ANDROID.md) · **Preuve exécutable :** `scripts/test_lifecycle_stress.luau` · **Contrat :** `scripts/check_lifecycle_contract.py`

Ce lot répond à une question que le jeu ne savait pas trancher : **une manche rend-elle tout ce qu'elle prend ?** Les fuites d'instances, les doubles listeners et les boucles après décès ne se voient pas dans une session de dix minutes ; elles se voient quand un serveur vit trois heures. Le registre ci-dessous les rend comtables hors moteur, sans jamais revendiquer une cadence d'images.

## 1. Périmètre audité

Les cinq points du lot C1, et ce qui est réellement couvert ici :

| Point du plan | État |
|---|---|
| Coûts des boucles d'IA sous quatre bots (raycasts par décision, `PathfindingService` en vol, files) | **Couvert** par la politique existante `BotPathBudget` : au plus `MAX_IN_FLIGHT = 2` appels moteur réellement en vol, écart minimal `0,18 s`, bail de validité `5,8 s` |
| Cycles d'équipement PBR, changements d'arme | **Couvert** : dix échanges par manche, une entrée d'arme vivante par combattant, jamais d'accumulation |
| Nettoyage des effets, effets saturés | **Couvert** : `TransientFxPool` et `ImpactMarkPool` recyclent au plafond du preset, y compris sous une rafale cinq fois supérieure |
| Réinitialisations de manche, entrées/sorties, décès | **Couvert** : libération par type au reset, libération au départ, pose relâchée au despawn ; `MatchLobbyPolicy` remet le lobby à `WAITING` quand le dernier joueur part |
| Streaming/LOD, rotation de caméra, reconnections | **Non couvert hors moteur** : ces chemins dépendent du rendu et du réseau, voir §6 |

## 2. Registre de cycle de vie

`src/shared/LifecycleLedger.luau` compte ce qui est vivant, par type : `player`, `weapon`, `listener`, `fx`, `impact`, `pose`.

- `acquire(state, kind, id)` renvoie `true` une seule fois par couple `(kind, id)` : une **seconde** acquisition est un **double listener**, elle renvoie `false`, incrémente `duplicates` et ne crée pas de seconde entrée.
- `release(state, kind, id)` et `releaseKind(state, kind)` modélisent l'unéquipement et la remise à zéro d'une manche.
- `leaks(state)` renvoie ce qui reste vivant, trié : une fuite porte un nom, pas une intuition.
- Le registre est lui-même borné (`MAX_PER_KIND = 256`) et compte ses `overflow` : un outil d'audit ne doit pas devenir la fuite qu'il cherche.
- Toute entrée invalide (type inconnu, identifiant vide, état absent) **lève une erreur** au lieu de fausser les comptes.

## 2 bis. Câblage serveur — `LifecycleService`

Le registre ne vit pas seulement dans les tests : `src/server/LifecycleService.luau` est démarré **avant** `MatchService` dans `src/server/init.server.luau` et l'alimente depuis les seuls endroits qui possèdent la durée de vie d'une ressource.

| Source | Ce qui est compté |
|---|---|
| `Players.PlayerAdded` / `PlayerRemoving` | une entrée `player` par `UserId` ; le départ relâche ses entrées `player` et `weapon`, et rien d'autre |
| `IronYardEquippedWeapon` (miroir publié par `WeaponService.onEquipWeapon`) | une entrée `weapon` par joueur, remplacée et non accumulée à chaque changement d'arme |
| `IronYardRoundPhase` (miroir publié par `MatchService.transition`) | une entrée `fx` de manche, relâchée à `RESULTS`/`WAITING` avec les `impact` |

Compteurs publiés en attributs de `Workspace`, écrits par le serveur seul : `IronYardAuditLive`, `IronYardAuditPeak`, `IronYardAuditLeaks`, `IronYardAuditDuplicates`, `IronYardAuditOverflow`.

Deux garde-fous :

- **Aucun retour vers le jeu.** Les deux miroirs sont écrits par `MatchService` et `WeaponService` et **jamais relus** : le contrat le vérifie, une phase ou une arme ne peut pas dépendre de l'audit. L'écriture du miroir d'arme est **dédoublonnée depuis un état serveur** (`state.mirroredWeaponId`) : un ré-équipement du même identifiant n'écrit rien, et le service ne relit jamais l'attribut pour le savoir.
- **Aucun effet de bord autorisé.** Chaque appel au registre passe par `pcall` : un bug d'audit ne peut pas casser une manche, un équipement ou un départ. Le service ne `kick`, ne déplace, ne téléporte et n'expose aucun remote.

## 3. Scénario de stress

`scripts/test_lifecycle_stress.luau`, déterministe, sans aucune mesure de temps :

**20 manches** avec 2 joueurs + 4 bots, presets `ECO` → `BALANCED` → `QUALITY` en rotation, 10 échanges d'arme et 5 décès par manche, effets réclamés bien au-delà du plafond du preset. Après chaque manche, le registre doit être **vide** ; le pic d'entrées vivantes reste borné à trois par combattant plus une entrée transitoire d'équipement.

Points verrouillés :

1. une manche qui ne relâche pas ce qu'elle prend échoue **avec le nom de la ressource** ;
2. un double listener est rejeté et compté ;
3. les effets se recyclent : le pool ne dépasse jamais le plafond `TransientFxPool.cap(preset, touch)`, ni `ImpactMarkPool.MAX_PARTS` ;
4. une rafale de `cap × 5` réclamations sur des effets qui vivent `0,5 s` remplit exactement le plafond, jamais un emplacement de plus ;
5. les échanges d'arme tiennent exactement une entrée par combattant ;
6. une pose de cadavre est relâchée au despawn ;
7. un départ ne relâche que le joueur parti.

## 4. Budget d'IA à quatre bots

Simulation de 600 ticks à `0,05 s` avec quatre bots partageant **un seul** budget serveur :

- `inFlight` ne dépasse jamais `MAX_IN_FLIGHT = 2` ;
- les appels en attente à la fin de la simulation restent bornés, puis sont tous relâchés ;
- un résultat plus vieux que `LEASE_SECONDS` est **rejeté** alors que son emplacement, lui, est libéré séparément — c'est la distinction qui évite les chevauchements cachés de `ComputeAsync` ;
- aucun emplacement ne survit à la simulation.

## 5. Profiler privé

`src/client/PerfOverlay.client.luau` reste **opt-in** et le contrat le vérifie : sortie immédiate hors Studio sauf pour le propriétaire de la place (`CreatorType == User` et `UserId == CreatorId`), panneau masqué au démarrage, et aucun parcours de `Players:GetPlayers()` qui l'activerait pour tout le monde. Aucun chiffre de ce document ne provient de ce profiler.

## 6. Limites

- **Aucune mesure réelle.** Ces tests comptent des entrées et des emplacements ; ils ne mesurent ni FPS, ni P95/P99, ni temps CPU. Aucun gain de performance n'est revendiqué.
- **Le câblage n'a pas tourné en moteur.** Les signaux `IronYardRoundPhase` et `IronYardEquippedWeapon`, l'ordre de démarrage et la libération au départ sont vérifiés statiquement par le contrat, pas observés sur un serveur Roblox.
- **Le registre ne couvre que ce que les services lui disent.** Les effets côté client (`TransientFxPool`, `ImpactMarkPool`) restent comptés par la suite de stress, pas par le registre serveur : leur cycle de vie appartient au client.
- **Pas de fuite d'instances prouvée en moteur.** Le registre prouve que le code *relâche* ses ressources ; il ne prouve pas que Roblox les collecte, ni que le streaming et le LOD se comportent comme prévu sur Android.
- **Streaming, rotation de caméra et reconnexions** restent hors de portée : ils demandent un client réel.
- **Les assertions Python fragiles** ne sont pas toutes remplacées : ce lot ajoute le socle de comportement Luau qui permettra de retirer les plus critiques, contrat par contrat, sans casser la CI.
