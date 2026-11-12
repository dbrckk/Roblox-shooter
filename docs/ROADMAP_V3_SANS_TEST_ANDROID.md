# IRON YARD — Feuille de route V3 : finition production sans test Android immédiat

**Date de référence : 12 novembre 2026**  
**Dépôt :** `dbrckk/Roblox-shooter` · **branche :** `main` · **base d'audit initiale :** `ca97f32e3bf86874351bc0232ac6d14f15f46b4e` · **mise à jour de l'état public :** `a91ef6b821dfab54b6663961f6b42bf4fa51f135`  
**Expérience Roblox :** IRON YARD publique, **version 54 confirmée** par le workflow de publication GitHub Actions `43227082815`.  
**Condition utilisateur actuelle :** pas de test manuel Android/Roblox Studio possible pour le moment. Les tâches bloquées doivent rester en attente **sans bloquer l'ensemble du chantier**.

> **V3 est la liste active des priorités.** [V2](ROADMAP_V2_PUBLIC.md) et [l'audit du 8 novembre](AUDIT_GLOBAL_2026-11-08.md) sont des références historiques utiles, mais plusieurs de leurs statuts sont périmés. [L'historique technique](ROADMAP.md) n'est pas le backlog actif. Aucun « fait », « FPS améliorés » ou « assets PBR visibles » ne peut être inféré d'un simple build vert.

### Actualisation — publication v54 (12 novembre 2026)

- Le correctif [PR #57](https://github.com/dbrckk/Roblox-shooter/pull/57) est fusionné : les six paires de réapparition du duel tournent tous les deux bouts et les côtés sont inversés. La recherche cyclique d'une paire entièrement dégagée maintient la règle de placement atomique existante.
- Les tests Luau ont couvert 49 152 sélections pour 4 096 masques d'obstacles et 12 manches, ainsi que les vérifications de personnages d'origine. CI branche, PR et `main` réussies ; **publication publique v54 confirmée** par [Actions #43227082815](https://github.com/dbrckk/Roblox-shooter/actions/runs/43227082815).
- **A1 reste partiellement ouvert** : aucune validation de duel réelle en Studio et des transitions FFA/1v1 sous réseau perturbé. La progression et les FPS Android réels restent non prouvés. Aucun nouveau modèle VANGUARD/texture PBR n'a été importé par cette version.

### Actualisation — A1 (matrice des transitions), 12 novembre 2026

- **A1 — matrice livrée.** [docs/MATCH_TRANSITIONS.md](MATCH_TRANSITIONS.md) fixe les **6 phases**, **14 arêtes légales**, les événements réellement possibles et les **11 cas** exigés par A1. `scripts/test_match_transitions.luau` les exécute ; `scripts/check_match_transition_contract.py` refuse toute phase, durée ou règle qui divergerait de `MatchService`. **Aucun défaut de transition n'a été démontré : aucun comportement de manche n'a été modifié.**
- **Verrou testé par mutation** : une durée de phase modifiée fait échouer `check_match_transition_contract`, et une cible émise sans arête déclarée dans `startLiveDuelBout` casse le contrat d'arêtes. Fichier restauré, `git diff` vide sur `MatchService`.
- **A1 reste ouvert** pour ce qui n'est pas automatisable : deux clients Roblox réels, abandons, tiers entrant, respawn pendant `DUEL_PREP`, réseau perturbé.

## 1. Cible produit, périmètre et principes

**But :** une expérience FPS publique industrielle, agréable et compréhensible, dont le combat et la progression sont fiables, avec des modèles 3D PBR réellement déployés lorsque les autorisations Roblox le permettent. Qualité perçue proche des bons FPS Roblox, mais design, code, audio et assets originaux.

Ordre de décision : **fiabilité > fonctionnement réel > sécurité > architecture > performances > interface/visuels > fonctionnalités secondaires**. Le FFA existant reste le mode principal. Finir et fiabiliser le **1v1 déjà développé** avant toute extension en 2v2/5v5. Aucune nouvelle arme, carte ou monnaie avant clôture des risques P0. Pas de copie de jeu propriétaire, d'avantage pay-to-win, de service payant obligatoire ni d'expérience Roblox privée parallèle.

Toute tâche porte un propriétaire logique (« code client », « code serveur », « pipeline d'assets »), une modification limitée, ses tests et une preuve de sortie. Une tâche nécessitant Roblox ou un téléphone n'est **pas** réputée accomplie avec seulement une compilation Luau.

## 2. État vérifié dans le dépôt (12 novembre)

| Composant | Réalité vérifiée | Dette ou preuve manquante |
|---|---|---|
| Publication | L'expérience **publique** IRON YARD a été publiée en version 54 ; workflow CI et déploiement réussis | Un build/publication réussis ne sont ni un playtest, ni un relevé FPS |
| Base de jeu | FFA, 5 armes, munitions et dégâts côté serveur, HUD tactile, progression, bots et déplacements présents | Temps jusqu'au premier engagement, ressenti des tirs, latence et ergonomie physique non mesurés |
| Duel 1v1 | **Déjà présent**, pas « à développer de zéro » : `MatchService`, `DuelRules`, `DuelCombatState`, `DuelSpawnPlan`, tests duels en CI | Enchaînements d'abandons, respawns, changements de personnages, état réseau et équité à éprouver dans Roblox |
| Armes PBR | `WeaponAssetIds.luau` contient **10 IDs non nuls**, 5 armes × LOD0/LOD1 ; politique de validation, cache de viewmodel, ADS et rechargements PBR implémentés | Contrôler résolution réelle de chaque asset, cadrage mobile, textures, animations et pertes au streaming |
| Opérateurs PBR | `VanguardAssetIds.luau` garde **4 IDs à zéro** ; kit Blender original, archives et contrôle GLB présents | Upload propriétaire, approbation, branchement effectif et preuve visuelle |
| Décors PBR | `WorldPbrAssetIds.luau` garde **12 IDs à zéro** ; workflow de génération/validation de 3 matériaux × 4 canaux présent | Upload Open Cloud Images propriétaire, IDs approuvés, activation et preuve de rendu |
| Performance | Pool VFX borné, adaptation transitoire Android, mesures privées FPS/P95/P99, charge IA, coût CPU du viewmodel et chronométrage privé A/B du changement d'arme disponibles | **Aucune mesure Android représentative** disponible pour attribuer un gain précis |
| Progression | `ProgressionLedger` et `ProgressionService` avec `UpdateAsync`, verrou, autosave, retry et états visibles ; tests calculatoires | Sauvegarde, reconnexion et résilience DataStore **sur serveurs Roblox réels** non prouvées |
| Sécurité | `RemoteGuard`, validation serveur, quotas, génération de chemins IA bornée et refus des anciennes réponses | Audit croisé des changements de manche, spam, sortie de joueur et latence ; épreuve réseau réelle différée |
| Documentation | V2 et README mélangent anciennes limitations et avancées réelles | V3 est la source de décision ; maintenir les statuts synchronisés |

**Clarification importante :** la politique `BotPathBudget` retient désormais ses slots tant que les `ComputeAsync` moteur ne se sont pas réellement achevés. Ne pas réintroduire la libération artificielle des slots à l'expiration d'un simple timeout.

## 3. Plan d'exécution : tâches réalisables sans téléphone

L'ordre ci-dessous est strict **par lots terminés**. On ne lance pas trois grandes refontes simultanément ; chaque PR conserve un comportement existant, ajoute ses tests et passe la CI avant de passer à la suivante.

### LOT A — Fiabilité FFA + 1v1 + session (P0)

**A1. Audit des transitions réelles de manche, priorité immédiate.**  
**Fichiers principaux :** `src/server/MatchService.luau`, `DuelCombatState.luau`, `src/shared/DuelRules.luau`, `DuelSpawnPlan.luau`, `RemoteGuard.luau`, `scripts/test_duel_*.luau`.

1. Établir une matrice complète des états **FFA → lobby → préparation duel → LIVE → pause → résultats → retour FFA** avec seuls événements réellement possibles dans les handlers serveur.
2. Couvrir en tests purs : joueur retiré avant départ, doublons `SetDuelReady`, départ simultané des deux participants, morts simultanées, défaite au temps, égalité, mort après changement de phase, respawn tardif, lobby avec troisième joueur, redémarrage de manche et nouvelle demande de duel.
3. Vérifier que les gagnants et les kills sont calculés par identifiant immuable et au maximum une fois ; que les remotes de tir ne peuvent jamais inscrire des dommages hors du mode admissible.
4. Corriger **uniquement les anomalies démontrées**, conserver la cadence et les règles actuelles des duels.

**Terminé quand :** suites Luau de transitions et contrats du vrai branchement serveur verts ; absence de chemins où une ancienne manche compte les dégâts/points de la suivante. **Reste à prouver en moteur :** deux personnages réels, physique, abandons réseau, transitions visibles.

**Statut 12 novembre 2026 :** matrice écrite ([MATCH_TRANSITIONS.md](MATCH_TRANSITIONS.md)), 11 cas exécutés et contrat de câblage vert. Aucune anomalie de transition démontrée, donc aucune règle de manche changée ; la preuve moteur reste la seule partie ouverte.

**A2. Progression DataStore et reprise.**  
**Fichiers :** `ProgressionService`, `ProgressionLedger`, `ProgressionHud`, `scripts/test_progression_ledger.luau`.

1. Simuler de façon déterministe les opérations asynchrones hors ordre, sauvegardes concurrentes, callbacks répétés, départ pendant `UpdateAsync`, expiration/reprise de bail et gain obtenu entre deux autosaves.
2. Vérifier la séparation stricte entre XP de session et XP réellement confirmé par DataStore, dans l'UI et sur les résultats.
3. Ne pas changer les clés `IronYard_Progression_v1`, schémas ni politiques de commit sans migration démontrablement sûre.
4. Documenter le mode dégradé : le joueur continue à jouer même si DataStore est indisponible, mais ne voit pas un succès de sauvegarde fictif.

**Terminé quand :** conservation exacte et non-duplication dans les tests ; aucune promesse de persistance réelle avant une reconnexion testée plus tard.

**A3. Robustesse des remotes et du cycle de vie serveur.**  
**Fichiers :** `RemoteGuard`, `WeaponService`, `MovementService`, `BotNavigation`, `BotService`.

1. Inventorier tous les événements actionnables par un client et leur validation de type, taille, cadence, état `LIVE`, identité du personnage et autorité.
2. Tester des rafales synthétiques, `NaN`/`inf`, ordres périmés, doublons, spawn/death en pleine animation, annulation du boost/wallrun ; **les ordres d'arrêt valides restent prioritaires**.
3. Tester le plafond **effectif** des `ComputeAsync` en vol et l'abandon sûr des réponses tardives ; conserver la capacité de combat utile lorsque la navigation est saturée.
4. Ne pas mettre d'outil offensif en contact avec un serveur hors périmètre autorisé.

**Terminé quand :** une erreur de client ou un spam n'altère ni les dégâts, ni la manche, ni les états de mouvement ; tests purs + contrat de raccordement serveur en CI. Les attaques réseau et les vrais raycasts restent à éprouver en moteur.

### LOT B — Qualité 3D réellement déployable (P1, sans produire de packs supplémentaires)

**B1. Terminer la chaîne d'assets existants avant d'en fabriquer d'autres.**

1. **Armes :** vérifier et inventorier les dix IDs déjà renseignés, la provenance propriétaire, les LOD, la complétude des MeshParts et SurfaceAppearance, les sockets FX, la correspondance des composants animés et le fallback procédural. Consolider les contrôles offline et détecter les trous **avant** publication.
2. **VANGUARD :** traiter les quatre IDs à zéro comme un blocage factuel. Vérifier les quatre GLB des archives et leurs cartes PBR, préparer un import propriétaire contrôlé avec préflight **sans upload réel**. Aucune valeur inventée ou fausse confirmation d'upload.
3. **Matériaux du monde :** utiliser le workflow existant de douze PNG et le validateur des hashes, CRC, UV/normal/roughness/metalness ; préparer un chemin de reprise des uploads partiels. La commande d'upload réelle exige des permissions du créateur, et ne doit pas être lancée par simple push.
4. Préserver les collisions, raycasts, déplacements, couvertures et les matériaux Roblox natifs de repli. Ne jamais intégrer un modèle contenant des scripts tiers.
5. Produire une **matrice d'acceptation par asset** : source/ID/owner/LOD/canaux PBR/fallback/contrôle runtime manquant.

**Terminé quand :** la CI établit ce qui est prêt et ce qui reste `BLOCKED_ROBLOX_ASSET_APPROVAL` ; la livraison des assets réels dans le jeu reste non certifiée tant que l'upload et le rendu ne sont pas confirmés.

**B2. Amélioration visuelle à plus fort impact, sans explosion d'instances.**

- Priorité 1 : silhouettes des bots VANGUARD et armes en première personne ; posture, mouvement de rechargement, visée et lecture à distance.
- Priorité 2 : grandes masses entrepôt/conteneurs, panneaux métalliques et sol, sans modifier les colliders de gameplay.
- Priorité 3 : éclairage naturel industriel cohérent (pas de thème néon), contraste des cibles/chemins ; fallback ECO propre.
- Priorité 4 : impacts, douilles et effets déjà présents ; renforcer les détails seulement lorsqu'un scénario visuel les justifie.

**Terminé quand :** changements vérifiables sur les sources de géométrie, budgets d'instances bornés, sécurité des colliders prouvée, et captures/contrôles visuels **à réaliser plus tard** en moteur. Les contrôles de code ne valident pas une qualité AAA perçue.

### LOT C — Performance et UX démontrables sans mesure matérielle (P1/P2)

**C1. Réduire la dette d'exécution mesurable par le code.**

- Vérifier les coûts des boucles d'IA et d'affichage sous quatre bots : raycasts par décision, cadences, traitements redondants, `PathfindingService` véritablement en vol, files et abonnements.
- Auditer les cycles d'équipement PBR, streaming/LOD, nettoyage d'effets, réinitialisations de manche, reconnections et rotation de caméra ; rechercher fuites d'instances, doubles listeners, resets de pose et boucles après décès.
- Étendre les tests de stress **déterministes** (20 manches simulées, transitions graphiques ECO/BALANCED/QUALITY, changements d'arme, entrée/sortie, effets saturés), en mesurant **bornes d'allocations/compteurs simulés**, jamais des FPS fictifs.
- Identifier les assertions Python fondées sur des chaînes fragiles et remplacer progressivement leur partie critique par des tests de comportement avec le runtime Luau ; conserver une CI reproductible et Rojo compilable.
- Conserver le profiler privé (CPU arme, FPS et P95/P99, bots et VFX) **opt-in**. Ne pas l'activer sur tous les joueurs.

**Terminé quand :** chaque optimisation a un test de non-régression et une raison technique explicite. Aucune hausse de FPS revendiquée sans mesure réelle.

**C2. Première minute de jeu et clarté Android/PC.**

- Valider statiquement le parcours : rejoindre → comprendre les 15 éliminations → viser/tirer → recharger → mourir/réapparaître → résultat → progression ; vérifier le 1v1 sans masquer le FFA.
- Éliminer les contradictions ou doublons visibles dans briefing, HUD armes/santé, annonces de kill, notifications DataStore, carte de défaite et panneau de résultats.
- Tester géométriquement les contrôles sur petits écrans 16:9 et 20:9, écrans avec zones d'encoche, contrôles de tir/ADS/slide/reload/boost. Aucune aide réservée aux développeurs dans l'interface publique.
- Préserver une distinction honnête entre **bots** et **humains** ; pas de faux joueurs connectés.

**Terminé quand :** parcours logique, scénarios de transitions HUD et layout automatisés ; la maniabilité tactile réelle reste à valider plus tard.

**C3. Réalisme sonore et sensations, seulement sur preuves.**

- Auditer licences/attributions et spatialisation des cinq armes, recharge, impacts et environnement.
- Éliminer les sons génériques trompeurs uniquement lorsqu'une alternative originale ou libre et compatible existe réellement.
- Vérifier les budgets de voix simultanées, priorité du joueur local, atténuation derrière les couvertures et nettoyage à l'expiration.
- Ne pas ajouter de sons factices, liens morts ou assets tiers non autorisés.

### LOT D — Campagne Roblox réelle différée (bloquée, pas abandonnée)

**Pas d'intervention utilisateur exigée maintenant.** Lorsque Roblox Studio ou un Android seront disponibles :

1. Sur la **même version publique** et les mêmes scènes, ouvrir le bouton propriétaire **PERF** : relever FPS, P95/P99, images >33 ms, CPU moyen/pic du viewmodel, pièces PBR actives, effets actifs/budget, bots et temporisations serveur.
2. Répéter quatre scénarios : repos et rotation caméra, quatre bots en combat, tirs/effets saturés, traversée rapide des quais avec streaming ; puis changements d'armes/LOD et reprise Android.
3. Contrôler visuellement les quatre palettes opérateur et douze textures de décor **uniquement si leurs IDs approuvés sont non nuls** ; comparer ECO/BALANCED/QUALITY et la lisibilité sur petite résolution.
4. Faire une session FFA et un 1v1 avec de vrais participants : tir près de couvertures, respawn, déconnexion, manche annulée, chargeur, pompe/verrou, casings et score.
5. Vérifier DataStore : XP gagné, statut de sauvegarde, attendre l'ack, quitter/rejoindre, puis test d'échec/récupération dans des conditions autorisées. **Ne pas activer l'accès aux données de production depuis Studio pour tester.**
6. Conserver les mesures et un rapport de défauts reproductible ; prioriser les trois plus forts problèmes constatés, pas une refonte au hasard.

**Cibles de conception non mesurées :** ~30 FPS stable sur Android faible gamme, jusqu'à 60 FPS sur milieu de gamme approprié, absence de gels/pics majeurs ; objectifs à réviser à la lumière des mesures réelles. Le CPU du callback viewmodel n'est ni le CPU complet de Roblox, ni le temps GPU.

**Terminé quand :** preuves de sessions réelles conservées, aucune défaillance bloquante des commandes, dégâts, persistance ou transitions ; pas avant.

### LOT E — Extensions seulement après les gates ci-dessus (P3)

- Améliorer le 1v1 existant (rematch/abandon/équité) uniquement à partir des anomalies A1/D4 ; **ne pas le réécrire**.
- Ajouter éventuellement 2v2, spectateur complet et matchmaking après stabilité du FFA/1v1, dimensionnement serveur et preuve anti-abus.
- Progression cosmétique supplémentaire seulement après validation DataStore réelle et migration sûre.
- Acquisition/catalogue, page Roblox et visuels promotionnels seulement lorsque les assets effectivement publiés reflètent la qualité promise.

## 4. Backlog ordonné pour les prochains « Continue / Go »

| Ordre | ID | Intervention autonome | Livrable vérifiable | Dépendance |
|---:|---|---|---|---|
| **1** | **A1** | Matrice FFA/duel, tests des transitions et correction des bugs réels | Matrice + 11 cas + contrat livrés le 12/11 ; preuve moteur restante | Aucune |
| 2 | A2 | Renforcer scénarios DataStore hors ordre / départ / verrou | PR + scénarios ledger non-duplicables | Aucune pour l'offline |
| 3 | A3 | Audit remotes/mouvements/pathfinding et tests adversariaux autorisés | PR + tableau des validations serveur | Aucune |
| 4 | B1 | Inventaire certifié des assets : 10 armes / 4 opérateurs / 12 textures | Manifeste de statut + préflight GitHub Actions **sans upload** | Upload réel réservé aux permissions Roblox |
| 5 | C1 | Tests de cycles de vie long, fuites, streaming, 4 bots, CI moins fragile | PR avec scénarios reproductibles | Aucune pour les politiques pures |
| 6 | C2 | Contrats UX de première partie, HUD et contrôles tactiles | Tests layout + scénarios de transition | Ressenti tactile différé |
| 7 | B2 | Polir **un seul gros ensemble visuel à la fois** | Assets/LOD, budgets et fallback audités | Observation en moteur pour clôture visuelle |
| 8 | C3 | Audio/licences et mixage original | Inventaire des sons, tests de priorité/voix, assets valides | Bibliothèque légalement utilisable |
| 9 | D | Validation publiée Android/Studio/DataStore/PBR | Relevés de performance, images et checklist signée | Appareil/session Roblox |
| 10 | E | Extensions après stabilisation | Lots indépendants et fermés | Gates A–D satisfaits |

**Règle de continuité :** tant que le test Android est impossible, passer de A1 → A2 → A3 → B1 → C1 → C2. Ne pas bloquer A2 sur une capture d'écran ou un relevé P95 absent. Ne pas lancer le 2v2, une sixième arme ou de gros packs avant B1.

## 5. Qualité, sécurité et critères de fusion/publication

Pour chaque PR de code :

1. Inspecter `main` et les derniers workflows ; éviter les écrasements de commits concomitants.
2. Modifier les modules déjà appelés par le jeu, conserver les fallbacks, les IDs de propriétaire et l'autorité serveur.
3. Tester le comportement corrigé par une suite pure Luau si possible ; compléter par Python pour des invariants statiques, compiler **tous** les Luau et construire `rbxlx` via Rojo.
4. Passer la CI complète sur branche/PR **et** sur le SHA fusionné. Corriger les tests en échec, ne pas les ignorer.
5. Pour une évolution du jeu public, utiliser la chaîne d'autorisation unique existante, qui vérifie destinataire/creator, visibilité PUBLIC, place de démarrage, SHA de source et CI verte. **Ne jamais inventer un lien Roblox dont l'ID n'est pas disponible.**
6. Une tâche de documentation seule n'exige **pas** de nouvelle version Roblox.
7. Distinguer explicitement **implémenté dans le dépôt**, **testé automatiquement**, **publié**, **vérifié en moteur** et **mesuré sur Android**.

### Risques actifs, sans cacher les limites

- **R1 — validation manquante** : stabilité réelle des 1v1 et du DataStore dans l'expérience publiée, FPS Android et collisions/animations importées.
- **R2 — pipeline visuel incomplet** : quatre IDs VANGUARD et douze IDs de matériaux PBR toujours nuls ; l'arme PBR à dix IDs ne prouve pas que tout le monde est en PBR.
- **R3 — dérive documentaire** : ancien audit/V2 et portions du README décrivent encore une publication future ou l'absence de duel alors que la version publique et le 1v1 existent.
- **R4 — optimisation aveugle** : pas de mesure physique du CPU/GPU ni de comparaison avant/après ; privilégier correctness, allocations bornées et instruments jusqu'à un vrai test.
- **R5 — livraison** : asset Roblox non autorisé ou source concurrente ; les gates CI et owner et fallback restent impératifs.

## 6. Définition de la sortie recherchée

IRON YARD « prêt pour une exploitation publique crédible » signifie : FFA et 1v1 fiables, tirs et scores autoritaires, sauvegarde annoncée avec sincérité, aucune fuite manifeste sur sessions prolongées, modèles/animations/audio honnêtes et cohérents, contrôles Android utilisables, build reproductible et publication/rollback vérifiés. **La V54 est déjà publique ; elle n'est pas automatiquement validée comme ayant atteint tous ces critères.**

Le chantier commence donc par **A1 : transitions FFA/duel et sûreté des changements d'état**. Aucun test Android n'est nécessaire pour avancer sur ce premier lot.
