# IRON YARD — Audit produit et plan d'évolution vers le niveau RIVALS

**Date : 12 novembre 2026** · **Base inspectée :** `main` @ `cd99cf0` (v54 publique)
**Référence produit :** [RIVALS](https://www.roblox.com/games/17625359962/RIVALS) — Nosniy Games. Référence de **qualité et de structure de jeu**, jamais de contenus : aucun asset, carte, skin, son, script ou interface propriétaire n'est copié.
**Nature du document :** audit de l'existant + plan d'évolution. Il ne remplace pas [ROADMAP_V3](ROADMAP_V3_SANS_TEST_ANDROID.md) (backlog technique immédiat) : il en donne la **cible produit** et l'ordre des investissements au-delà.

---

## 1. Méthode et limites

- **Vérifié dans le dépôt** : les 162 modules Luau de `src` (≈ 22 600 lignes), complétés par 100 suites de tests Luau, 33 scripts Python (dont 18 contrôles de contrats d'intégration) et 12 workflows GitHub Actions ; lecture des services serveur et modules partagés (`MatchService`, `WeaponService`, `ProgressionService`, `ProgressionLedger`, `CombatAwards`, `BotService`, `MapService`, `TouchLayout`, `WeaponConfig`, `PrecisionNet`, `RemoteGuard`).
- **Vérifié par recherche exhaustive** (`grep` sur `src`, `scripts`, `docs`, `game`) : absence de `Shop`, `GamePass`, `ProductId`, `MarketplaceService/ProcessReceipt`: pas d'économie, pas de monétisation, pas de boutique. Absence de `TeleportService`, serveur réservé et file d'attente : pas de matchmaking inter-serveurs. Aucun système de saison, défi quotidien, battle pass, inventaire cosmétique ou classement persistant.
- **Non vérifiable sans Roblox** : FPS réels, P95/P99 Android, latence perçue, TTK ressenti, ergonomie tactile réelle, rendu des meshes PBR, fiabilité DataStore en production, équilibrage humain contre humain. **Aucun chiffre de performance ou d'équilibrage n'est affirmé dans ce document.**
- **Sources publiques RIVALS** consultées le 12 novembre 2026 (voir §4) : usage factuel et comparatif uniquement.

**Convention de notation :** `CONFORME` (équivalent au niveau attendu), `PARTIEL`, `ABSENT`, et effort indicatif `S` (< 1 semaine-homme), `M` (1–3), `L` (3–6), `XL` (> 6).

---

## 2. Verdict synthétique

IRON YARD est aujourd'hui un **très bon prototype technique de FPS compétitif**, pas encore un **jeu de service**. La différence avec RIVALS ne se joue pas sur le tir — le socle autoritaire, les cinq armes, la visée serveur, les bots tactiques et la persistance sont d'un niveau que beaucoup de jeux Roblox n'ont pas — mais sur trois couches absentes ou embryonnaires :

1. **La boucle de session.** IRON YARD propose une arène FFA à 15 éliminations et un duel 1v1 opt-in limité aux deux joueurs déjà présents dans le même serveur. RIVALS propose un **menu de modes**, des duels **1v1 → 5v5 au premier à cinq manches**, une file de matchmaking inter-serveurs, des cartes variées et un rematch immédiat. C'est l'écart n°1.
2. **La boucle de progression et de statut.** IRON YARD a une courbe d'XP saine et cinq finitions d'opérateur jusqu'au niveau 15, puis **plus rien à gagner à vie**. RIVALS entretient une boucle complète : monnaie, armes, caisses, skins, wraps, charms, finishers, emotes, contrats quotidiens, roue, saisons classées, palier ELO.
3. **La couche de présentation.** Les sons d'armes sont des assets Roblox génériques (`snap.wav`, `bass.wav`, `electronicpingshort.wav`), la carte est unique (356 × 356 studs), et 16 des 26 IDs d'assets premium produits restent à zéro (4 opérateurs VANGUARD, 12 matériaux de monde). Le jeu est lisible, il n'est pas encore *désirable*.

**Conséquence stratégique :** le prochain investissement à fort effet n'est **ni une sixième arme, ni un nouveau détail de rivet**. C'est **le mode de jeu à manches dans un vrai menu, avec matchmaking et rematch**, puis **une progression qui donne une raison de revenir**. C'est exactement l'ordre que RIVALS a suivi.

---

## 3. Audit par domaine (état vérifié)

### 3.1 Combat et arsenal — `PARTIEL` (socle solide, calibration non prouvée)

| Constat | Preuve |
|---|---|
| 5 armes originales, cadence/munitions/rechargement/dégâts **entièrement serveur** | `WeaponConfig.luau`, `WeaponService.luau` (822 l.) |
| Convergence caméra → tête plafonnée à 4,5 studs, repli sûr, aucun hit client accepté | `WeaponService` + `docs/RIVALS_QUALITY_BENCHMARK.md` |
| Bloom de rafale serveur, ADS annoncée et validée après 140 ms, bonus suspendu en mobilité | idem + `AimStancePolicy` |
| Les 5 armes sont **toutes disponibles en même temps** : aucune notion de loadout, de choix, de déblocage | `WeaponConfig.Order` = les 5 armes, aucun filtre d'accès |
| Aucune cible de TTK ni de budget de dégâts par distance | pas de module d'équilibrage ; pistolet 100 en headshot, sniper 150, couteau 100 |

**Écart clé :** dans un jeu à manches, l'identité d'une manche vient du **loadout et de la lecture de l'adversaire**, pas seulement du tir. Aujourd'hui chaque joueur a le même arsenal complet : la manche n'a pas de méta.

### 3.2 Modes et boucle de session — `ABSENT` pour l'essentiel

| Constat | Preuve |
|---|---|
| FFA : 6 s de compte à rebours, **240 s**, victoire à **15 éliminations**, 12 s de résultats, rematch automatique | `MatchService.luau` (`ROUND_SECONDS`, `ELIMINATIONS_TO_WIN`) |
| Duel 1v1 : opt-in par bouton, premier à 5 manches, 80 s/manche, 7 s de pause, 3 s de préparation, 24 manches max, forfait/revanche | `DuelRules.luau`, `MatchService`, `DuelSpawnPlan` |
| **Aucun menu de modes**, aucune sélection de carte, aucune file : on rejoint le serveur et la manche démarre | pas de module lobby/menu ; `init.client` démarre en jeu |
| **Pas de 2v2/3v3/5v5**, pas de TDM, pas de Gun Game, pas de spectateur | grep : aucun état d'équipe dans `MatchService` (`duelRows` = 2 lignes) |
| **Pas de matchmaking inter-serveurs** : le duel exige deux joueurs dans la *même* instance | absence de `TeleportService` / serveur réservé |
| Une seule arène, pas de rotation de cartes | `MapService.luau` (une carte procédurale) |

**Écart clé :** RIVALS ne vend pas « un FPS », il vend **le choix d'un format de duel en dix secondes**. Sans menu + file + cartes, IRON YARD reste un bac à sable.

### 3.3 Progression, économie, rétention — `ABSENT` au-delà du niveau 15

| Constat | Preuve |
|---|---|
| XP par élimination : 100 (+35 headshot, +75 chaîne, +20 série ≥ 5) ; victoire : 250 | `CombatAwards.luau` |
| Niveau = `1 + floor(sqrt(xp / 250))`, plafond 1000 | `ProgressionLedger.luau` |
| Persistance DataStore `IronYard_Progression_v1` avec bail, autosave 45 s, retry, release détaché | `ProgressionService.luau` (342 l.) |
| **Contenu déblocable : 5 finitions d'opérateur, niveaux 1/3/6/10/15. Rien après.** | `OperatorFinishes.luau` |
| Aucune monnaie, boutique, caisse, skin d'arme, charme, finisher, contrat quotidien, saison | grep : 0 occurrence de Shop/GamePass/Season/BattlePass/Daily |
| L'inventaire cosmétique n'est **pas** persisté : seule la finition dérivée du niveau existe | aucune table `cosmetics` dans le schéma DataStore |

**Écart clé :** un joueur qui atteint le niveau 15 — de l'ordre de 40 manches avec ~10 éliminations par manche, estimation à confirmer par la télémétrie — n'a **plus aucun objectif**. C'est le plafond de rétention le plus visible du jeu.

### 3.4 Présentation : visuel, audio, mise en scène — `PARTIEL`

| Constat | Preuve |
|---|---|
| 10 IDs d'armes PBR enregistrés (5 armes × 2 LOD) ; **4 IDs VANGUARD et 12 IDs monde toujours à 0** | `WeaponAssetIds.luau`, `VanguardAssetIds.luau`, `WorldPbrAssetIds.luau` |
| Sons d'armes = assets Roblox internes génériques, deux couches + EQ d'occlusion | `WeaponConfig.soundLayers` |
| Effets : flashs différenciés, douilles par arme, impacts par matériau, couronne fatale | `CombatVfxProfile`, `CartridgeEjectionPolicy`, `ImpactMarkPool` |
| Aucun killcam, aucune pose de victoire, aucun finisher jouable, aucune mise en scène de manche | grep `Killcam/Finisher` : absent (les « finitions » sont des palettes) |
| Pas d'écran de menu, ni d'écran de chargement, ni de vitrine de progression | client = HUD de match uniquement |

### 3.5 Interface et mobile — `CONFORME` techniquement, `PARTIEL` produit

`TouchLayout.luau` calcule trois presets (COMPACT/STANDARD/LARGE), garantit des cibles ≥ 28 px, détecte les chevauchements et réserve le bouton saut Roblox — c'est supérieur à la moyenne Roblox. Mais l'interface est **celle d'un match**, pas celle d'un jeu : pas de menu, pas de collection, pas de profil, pas de classement consultable.

### 3.6 Performance — `PARTIEL` (outils réels, mesures absentes)

Pools bornés (`TransientFxPool` 24/48/72 pièces Android), profils graphiques ECO/BALANCED/QUALITY commutables en match, LOD 48 studs, budgets IA et VFX, overlay PERF privé. **Aucune mesure Android/PC réelle n'est archivée** : la V3 le dit explicitement, et ce document ne le contredit pas.

### 3.7 Qualité, sécurité, industrialisation — `CONFORME` pour un projet solo

100 suites Luau, 18 contrats d'intégration Python, compilation exhaustive des sources, build Rojo, 12 workflows dont publication publique à autorisation unique. `RemoteGuard` applique des token buckets par joueur et événement. C'est le point le plus fort du dépôt, et c'est ce qui rend le plan ci-dessous réaliste.

### 3.8 Publication et découverte — `PARTIEL`

v54 réellement publique (Actions #43227082815). Mais : pas de vignettes/icônes versionnées, pas de description publique optimisée, pas de page de bienvenue, pas de canal de staging distinct, pas de suivi d'erreurs post-publication, pas de télémétrie de funnel. **On publie sans savoir ce que font les joueurs.**

---

## 4. Ce que fait RIVALS (état public, novembre 2026)

Chiffres et fonctionnalités issus de sources publiques, datés ; ils servent de **repères de surface produit**, pas de promesse de replication.

| Dimension | RIVALS |
|---|---|
| Boucle cœur | Duels **1v1 → 5v5**, premier à **5 manches** ; slide/movement aussi importants que le tir ; pas de long grind pour être compétitif ([bloxodes](https://bloxodes.com/wiki/rivals), [rivals.wiki](https://rivals.wiki/wiki/modes)) |
| Modes | **21 modes** : duels, Beginner 2v2, Ranked, FFA, TDM, Gun Game, + rotation hebdomadaire (Spleef, Juggernaut, Head Honcho, Mirror Matchup…) ([Fandom Gamemodes](https://robloxrivals.fandom.com/wiki/Gamemodes), [RivalWiki](https://rivalwiki.com/game-modes)) |
| Arsenal | **54 armes** (49 utilisables en loadout normal) ; armes et améliorations achetées avec une monnaie gagnée en jeu ([BloxGuidesGG](https://bloxguidesgg.com/games/rivals)) |
| Progression | **Keys** → armes, Wrap Boxes, Charm Capsules, Finisher Packs, boutique quotidienne ; tâches quotidiennes → tours de roue ; saisons classées ([bloxodes](https://bloxodes.com/wiki/rivals)) |
| Compétitif | Ranked **ELO** en 1v1/2v2/3v3, placement en 10 matchs, paliers Bronze → Onyx → Archnemesis, **saisons** (Saison 3 « The Fame Season » depuis avril 2026) ([earnaldo](https://earnaldo.com/blog/rivals), [BloxGuidesGG](https://bloxguidesgg.com/games/rivals)) |
| Cosmétique | Skins, **wraps**, charms, **finishers**, emotes — cinq classes distinctes, via caisses, roue, boutique, événements, UGC reward track |
| Technique | Serveurs **40 joueurs**, desktop + mobile ([earnaldo](https://earnaldo.com/blog/rivals)) |
| Cadence | Updates numérotées irrégulières (2026 : 19 en mars, 20 en avril, 21 en juin, 22 et 23 en septembre) + événements et rotations intermédiaires ([RivalWiki updates](https://rivalwiki.com/updates)) |
| Statut | ~130 000 joueurs simultanés (oct. 2026) ; Best Shooter Experience aux RIA 2025 **et** 2026 ([AllThingsHow](https://allthings.how/rivals-new-update-schedule/), [RivalWiki](https://rivalwiki.com/updates)) |

**Lecture utile :** RIVALS n'est pas fort parce qu'il a 54 armes. Il est fort parce que **la session est instantanée, la manche est courte, le format est choisi par le joueur, et chaque manche alimente une collection visible**. Les 54 armes et les 21 modes sont la *conséquence* de cette boucle, pas sa cause.

---

## 5. Tableau d'écart

| # | Dimension | RIVALS | IRON YARD vérifié | Écart | Effort | Priorité |
|---:|---|---|---|---|---|---|
| 1 | Choix du mode | Menu + 21 modes | Aucun menu, FFA imposé | **Critique** | L | **P0** |
| 2 | Duels d'équipe | 1v1→5v5, first-to-5 | 1v1 opt-in, même serveur | **Critique** | L | **P0** |
| 3 | Matchmaking | File inter-serveurs | Inexistant | **Critique** | XL | P0 |
| 4 | Cartes | Nombreuses, rotation | 1 arène (`MapService`) | **Majeur** | L | P0 |
| 5 | Raison de revenir | Keys, contrats, saisons | 5 paliers puis rien | **Critique** | L | **P0** |
| 6 | Collection cosmétique | 5 classes, centaines d'items | 5 palettes d'opérateur | **Majeur** | L | P1 |
| 7 | Identité d'arme | Skins/wraps par arme | Aucune personnalisation | Majeur | M | P1 |
| 8 | Classement | Ranked ELO + saisons | Podium de manche, aucun rating | **Majeur** | L | P1 |
| 9 | Loadout | Choix d'armes + upgrades | Les 5 armes imposées | Majeur | M | P1 |
| 10 | Audio | Signature originale | Sons Roblox génériques | Majeur | M | P1 |
| 11 | Silhouettes/opérateurs | Modèles premium | 4 IDs à zéro, fallback Parts | Majeur | L | P1 |
| 12 | Mise en scène | Finishers, poses, emotes | Aucune | Moyen | M | P2 |
| 13 | Onboarding | Chargement + conseils | Briefing court | Moyen | S | P1 |
| 14 | Télémétrie | (implicite, jeu mature) | Aucune | **Majeur** | S | **P0** |
| 15 | Monétisation | Game passes légères + Keys | Aucune | (volontaire) | M | P3 |
| 16 | Vitesse de tir perçue / TTK | Calibré, maintenu par patches | Non mesuré, non calibré | **Majeur** | M | P0 |

---

## 6. Plan d'évolution

**Principe directeur :** on ne construit la couche « jeu de service » qu'au-dessus d'une boucle de manche prouvée. Chaque lot est **autonome, testable en CI, et publié séparément**. Aucun lot ne dépend d'un test Android immédiat ; ceux qui en dépendent sont marqués `GATE-ENGINE`.

### LOT 0 — Voir clair et mesurer (2–3 semaines) · `S`–`M`

Objectif : arrêter de développer à l'aveugle, et figer la cible d'équilibrage.
Le lot est scindé parce que ses quatre tâches n'ont ni le même risque ni les
mêmes fichiers (voir la réconciliation avec la V3 en §6 bis).

**0a — harnais TTK. Livré le 12 novembre 2026.**

1. `src/shared/TtkModel.luau`, module pur sans aucune API Roblox : nombre de tirs létaux, dégâts par zone, portée serveur comme contrainte, temps de vol des projectiles, TTK en secondes depuis le premier tir accepté.
2. `scripts/test_ttk_model.luau` : verrouille les **valeurs actuelles** des cinq armes (tirs **et** secondes) à 5/15/50/100 studs, les cas shotgun par plombées touchées, un seuil de vie à 125 PV, l'absence d'effet de la visée sur le TTK, la porte de portée (`AR-24` à 500 studs, `B-8` à 150, couteau à 291) et le rejet des entrées invalides. Il ne peut pas diverger de `test_arsenal_baseline` : les deux tables de tirs sont comparées.
3. `scripts/check_ttk_contract.py` : contrat statique garantissant que le modèle reste pur, qu'il **n'écrit aucun dégât** (WeaponConfig reste la seule source) et que la CI exécute bien les deux fichiers ci-dessus.
4. **Aucun dégât, aucune cadence, aucune portée n'a changé.** Le harnais mesure ; il ne rééquilibre pas. Une fenêtre cible (par ex. TTK corps 0,35–0,55 s à 15 studs) ne pourra être imposée en CI qu'après les mesures moteur du LOT D, sinon elle remplacerait une valeur non prouvée par une autre.

**0b — observabilité. Différée après clôture de A1 (V3).**

5. **Télémétrie de funnel côté serveur** (DataStore agrégé ou `AnalyticsService`, jamais un remote client) : rejoindre → premier kill → première manche terminée → deuxième session ; abandons en cours de manche, durée par manche, arme utilisée par kill.
6. **Plafond de serveur explicite** : le code ne gère pas la taille de serveur. La fixer et la documenter (par ex. 12 pour du 5v5 + 2 spectateurs) ; sans cela, un serveur à 40 joueurs casserait `MatchService` et ses `BotConfig.MaxBots = 4` bots.
7. **Suivi d'erreurs post-publication** : agréger les `warn` existants dans un store borné pour connaître l'état réel de la v54.

**Sortie 0a (atteinte) :** une courbe TTK versionnée et verrouillée en CI, réutilisable par toute calibration ultérieure.
**Sortie 0b :** un tableau de bord interne alimenté par de vraies sessions ; un plafond de serveur décidé.

### LOT 1 — La boucle de session : menu, format, manches (4–6 semaines) · `L`

C'est **le lot qui rapproche le plus de RIVALS**, et il ne demande aucune monétisation.

1. **Menu de jeu** (une seule `ScreenGui` racine, cohérente avec `TouchLayout`) : `PLAY`, `TRAINING`, `CAREER`. `PLAY` propose les formats réellement disponibles. Aucun écran de menu ne bloque les inputs de match (le module `applyMenuMouseState` existe déjà).
2. **Généraliser le moteur de manches** : extraire de `MatchService` un état de match paramétré par **format** (`1v1`, `2v2`, `3v3`), `winLimit = 5`, durée de manche et règle de victoire — en réutilisant `DuelRules.advance`, déjà pur et testé. Les duels d'équipe deviennent une **variation de données**, pas une réécriture.
3. **File locale d'abord** : dans un serveur, un panneau `PLAY` propose le format ; quand assez de joueurs sont prêts, la manche démarre en mode équipe. C'est la version prouvable sans `TeleportService`.
4. **Matchmaking inter-serveurs ensuite** (`GATE-ENGINE`, `XL`) : `TeleportService:ReserveServer` + téléport de groupe + un `MatchmakingQueue` pur testable hors moteur (composition d'équipes, plafond d'écart de niveau). À faire **après** validation de la file locale, jamais avant.
5. **Deuxième et troisième carte** : l'arène actuelle est un décor unique ; deux cartes supplémentaires, plus compactes (idéal 1v1 : 120 × 120), suffisent à créer la variété perçue. `MapService` est déjà isolé.
6. **Rematch en un clic** et **abandon explicite** avec pénalité de file (déjà partiellement présent via `FORFEIT`).

**Sortie :** deux joueurs peuvent choisir `1v1` depuis un menu et jouer une manche sans connaître le code ; trois formats partagent le même moteur testé ; trois cartes.

### LOT 2 — Loadout, identité d'arme, calibration (3–4 semaines) · `M`

1. **Loadout à 3 emplacements** (primaire / secondaire / mêlée) choisi dans le menu, validé serveur. `WeaponConfig` gagne une catégorie par arme. Aucun changement de dégâts.
2. **Deux armes par catégorie** (une nouvelle primaire, une nouvelle secondaire) : c'est le premier vrai contenu de gameplay depuis longtemps, et il ne coûte rien en monétisation.
3. **Calibration issue du LOT 0** : ajuster dégâts/cadence/dispersion pour que chaque arme ait une fenêtre d'usage, avec le harnais comme garde-fou.
4. **Fin de l'uniformité visuelle** : les finitions d'opérateur doivent devenir **choisies**, pas seulement subies (voir LOT 3).

**Sortie :** la manche a une méta ; le joueur fait un choix avant de jouer.

### LOT 3 — Progression qui donne une raison de revenir (4–5 semaines) · `L`

C'est le second écart critique. À construire **sur** la discipline `ProgressionLedger` existante, pas à côté.

1. **Deuxième DataStore `IronYard_Inventory_v1`** avec le même schéma de bail/commit/idempotence, et une migration documentée. Champs : monnaie, items possédés, loadout équipé, saison.
2. **Monnaie gagnée en jeu** (« SCRAP ») créditée par élimination/manche/victoire, **uniquement** issue d'événements serveur déjà validés.
3. **Boutique cosmétique** (pas d'armes payantes, pas d'avantage) : palettes d'opérateur étendues (10–15 au lieu de 5), **wraps d'armes** (matériau/couleur par arme, appliqués au viewmodel déjà construit), charms.
4. **Contrats quotidiens / hebdomadaires** : 3 objectifs simples et vérifiables serveur (« 10 headshots », « 3 manches gagnées en 2v2 »), avec récompense en SCRAP. Un module pur `Contracts` + tests, aucune boucle par frame.
5. **Courbe d'XP revue** : le palier 15 atteint en ~40 manches est trop court pour un jeu de service. Prolonger la courbe (niveaux utiles jusqu'à ~60) **et** débloquer des palettes sur les niveaux hauts. Ne pas casser le schéma existant : migrer `schema` avec version explicite.
6. **Écran CAREER** : niveau, XP, monnaie, collection, prochain déblocage. Aujourd'hui le joueur ne voit presque rien de sa progression hors match.

**Sortie :** un joueur qui rejoue a un objectif visible à chaque session ; la collection est persistée et survivante à un changement de serveur.

### LOT 4 — Présentation premium (4–6 semaines, partiellement `GATE-ENGINE`) · `L`

1. **Activer les assets déjà produits** : import propriétaire des 4 opérateurs VANGUARD et des 12 matériaux de monde (IDs actuellement à 0), et non de nouveaux packs. C'est un blocage d'*upload*, pas de production.
2. **Pack audio original** : cinq armes, rechargements, impacts, ambiance. Les sons génériques Roblox sont le défaut de finition le plus audible en jeu. Échantillons libres/licenciés uniquement.
3. **Mise en scène de manche** : bannière d'entrée, présentation des deux camps, pose de victoire de fin de série, **finisher** cosmétique unique (une seule séquence, réutilisée : coût maîtrisé, effet perçu élevé).
4. **Killcam courte** (2 s, caméra serveur validée) — uniquement si le budget réseau reste dans les limites déjà imposées par `RemoteGuard`.
5. **Passage de direction artistique** sur les cartes 2 et 3 : identité industrielle cohérente, contraste de cibles, lisibilité à petite résolution.

**Sortie :** les captures du jeu publié ressemblent au jeu, plus à un prototype.

### LOT 5 — Compétitif et statut (3–4 semaines) · `L`

1. **Rating persistant** (ELO simple, un module pur testable) alimenté **uniquement** par les résultats de manches en mode `RANKED`.
2. **Placement** puis paliers lisibles ; affichage dans CAREER et sur la carte de résultats.
3. **Saisons** (durée ~8–10 semaines, remise à zéro partielle, récompense cosmétique de fin de saison) : c'est le mécanisme de rétention le plus rentable de RIVALS.
4. **Anti-abus** : niveau minimum d'accès, âge de compte, vérification anti-smurf simple, résultat de manche déjà autoritaire.
5. **Classement public** (top N par saison) borné et paginé, en lecture seule.

**Sortie :** le joueur a un statut qui monte et descend, et une raison de revenir à la prochaine saison.

### LOT 6 — Monétisation éthique (seulement après LOT 3 et 5) · `M`

**Condition d'entrée non négociable :** rétention D1/D7 mesurée et jugeable, collection déjà plaisante à obtenir gratuitement. Sinon on monétise un jeu que personne ne garde.

1. `MarketplaceService:ProcessReceipt` avec idempotence, journal, remboursement et tests dédiés (aucun code de ce type n'existe aujourd'hui).
2. Un **game pass** cosmétique (palette exclusive) et des **bundles SCRAP**, jamais de dégâts, cadence, munitions ou visibilité avantageuse.
3. Aucune caisse payante à contenu aléatoire de gameplay ; si caisses il y a, elles restent cosmétiques et annoncées.

---

## 6 bis. Réconciliation avec la ROADMAP V3 : A1 reste prioritaire, seul 0a démarre

La [ROADMAP V3](ROADMAP_V3_SANS_TEST_ANDROID.md) est le backlog actif du dépôt et place **A1 — fiabilité des transitions FFA/duel — en priorité 1**. La première version de ce document recommandait le LOT 0 « en premier », ce qui contredisait cet ordre. Résolution, sans changer la V3 :

| Question | Réponse retenue |
|---|---|
| Quel lot est actif ? | **A1**, inchangé. Aucune tâche de ce document ne le préempte. |
| Pourquoi le harnais TTK peut démarrer quand même ? | 0a n'ajoute **qu'un module pur neuf**, un test et un contrat statique. Il ne touche ni `MatchService`, ni `WeaponService`, ni une seule valeur de dégât : il ne peut pas régresser une manche, et il ne crée aucun conflit avec A1. |
| Pourquoi 0b attend A1 ? | La télémétrie et le suivi d'erreurs modifient `MatchService` et `ProgressionService` — exactement les fichiers qu'A1 corrige. Instrumenter des transitions en cours de correction produirait des données faussées et des conflits de fusion. |
| Quel est l'ordre final ? | **A1** (actif) → **0b** → **LOT 1** → LOT 2/3/4 → LOT 5 → LOT 6, avec **0a livré en parallèle** de A1. |
| Règle de passage | Un lot de ce document ne démarre que si la ligne A1 de la V3 est verte ou explicitement hors périmètre. |

**Bénéfice croisé :** A1 corrige des transitions, pas des armes ; le verrou de 0a garantit que ses correctifs ne dériveront pas silencieusement l'équilibrage, et que la calibration du LOT 2 partira de valeurs mesurées plutôt que d'un souvenir.

## 7. Chemin critique et dépendances

```
A1 (V3, lot actif) ────────> LOT 0b (observabilité) ──┐
LOT 0a (harnais TTK, livré) ──────────────────────────┴─> LOT 1 (menu + manches paramétrées + cartes)
                                                            ├─> LOT 2 (loadout + calibration)
                                                            ├─> LOT 3 (inventaire + monnaie + contrats + courbe XP)
                                                            │      └─> LOT 5 (ranked + saisons)
                                                            │             └─> LOT 6 (monétisation)
                                                            └─> LOT 4 (assets + audio + mise en scène)
```

**Règle d'exécution :** un lot = plusieurs PR, chacune avec au moins une suite Luau ou un contrat d'intégration, et la CI verte avant la suivante — la méthode déjà en vigueur dans ce dépôt, qui fonctionne.

---

## 8. Indicateurs à suivre (à figer dans le LOT 0)

| Indicateur | Définition | Cible de départ |
|---|---|---|
| Time-to-first-kill | secondes entre l'arrivée et le premier kill | < 60 s |
| Taux de manche complétée | manches terminées / manches démarrées | > 85 % |
| Part des joueurs qui choisissent un duel | duels démarrés / joueurs actifs | > 30 % (après LOT 1) |
| Rétention J1 / J7 | sessions revenant le lendemain / à 7 jours | J1 ≥ 20 %, J7 ≥ 7 % |
| Durée de session moyenne | minutes par session | > 12 min |
| Progression | % de joueurs au-delà du niveau 15 | > 25 % (diagnostic de la courbe) |
| Stabilité | erreurs serveur par 100 manches | < 1 |

Ces seuils sont des **hypothèses de travail à réviser** après les premières données réelles, pas des engagements.

---

## 9. Ce qu'il ne faut pas faire

- **Ne pas copier** un asset, une carte, un skin, un son, un mode propriétaire de RIVALS. La référence est la *structure* (menu → format → manche → collection), jamais le contenu.
- **Ne pas construire 5v5 avant d'avoir un 1v1 choisi depuis un menu.** La V3 le dit déjà pour le code ; c'est aussi vrai pour le produit.
- **Ne pas ajouter de monnaie ou de boutique avant que la boucle de manche soit agréable** : on fausserait le diagnostic de rétention.
- **Ne pas produire de nouveaux packs 3D** avant d'avoir importé les 16 IDs déjà bloqués.
- **Ne pas annoncer** de FPS, de TTK calibré ou de « qualité RIVALS » sans mesure moteur archivée. Ce document ne le fait pas et ne l'autorise pas.
- **Ne pas remplacer** `ProgressionLedger` ni réécrire `MatchService` : les étendre par paramétrage.

---

## 10. Décisions réservées au propriétaire

| Décision | Pourquoi elle bloque |
|---|---|
| Tests Roblox Studio / Android sur deux clients réels | Aucun lot ne peut être déclaré terminé sans cela (`GATE-ENGINE` sur LOT 1 et 4) |
| Autorisation d'upload des assets VANGUARD / monde | 16 IDs restent à 0 ; sans upload, le LOT 4 est plafonné |
| Choix du plafond de serveur et du modèle de matchmaking | Détermine l'architecture du LOT 1 (`XL` si inter-serveurs) |
| Budget audio (échantillons originaux licenciés) | Conditionne le LOT 4 ; aucune alternative gratuite équivalente n'est garantie |
| Ouverture de la monétisation | Après LOT 5 uniquement, et sur données de rétention réelles |

---

## 11. Prochaine action recommandée

**La priorité reste A1 (V3)** : la matrice des transitions FFA/duel et la correction des anomalies démontrées. Le plan produit ne la remplace pas.

**Déjà fait (0a, 12 novembre 2026) :** le harnais TTK est en CI (`scripts/test_ttk_model.luau`, `scripts/check_ttk_contract.py`), avec les valeurs actuelles verrouillées et zéro changement de dégâts.

**Ensuite :** clôturer A1, puis ouvrir **0b** (télémétrie de funnel, plafond de serveur, suivi d'erreurs) — les trois tâches qui rendent le reste du plan mesurable — avant d'attaquer le **LOT 1**, qui est le vrai levier d'écart avec RIVALS.
