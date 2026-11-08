# IRON YARD — Master roadmap V2 (objectif : FPS Roblox public premium)
Dernière révision : 8 novembre 2026
Branche de référence : main
Audit probant : docs/AUDIT_GLOBAL_2026-11-08.md
Statut : PLAN VALIDÉ POUR EXÉCUTION — travail incrémental, sans redémarrage du projet

## Objectif produit

Faire d'IRON YARD un FPS Roblox distinctif, compétitif et accessible, à l'identité d'un terminal de fret industriel crédible, où l'on peut rejoindre immédiatement un combat compréhensible sur Android ou PC, progresser sans payer, s'améliorer contre une IA honnêtement identifiée et jouer ensuite contre d'autres humains.

**Critère de réussite : une expérience publique jouable et agréable**, pas une alpha orientée développeur ni une succession de packs graphiques non intégrés.

Priorité explicite : fiabilité > fonctionnement réel > sécurité > architecture > performances > interface/graphismes > fonctionnalités secondaires. Pas de nouvelle mécanique importante tant que l'étape en cours ne dispose pas d'une preuve adaptée.

## Positionnement et limites de périmètre

- Mode de base : FFA rapide, manche de 240 s / 15 éliminations, déjà implémenté ; on l'améliore, on ne l'efface pas.
- Combat : cinq armes, mouvements avancés, cartes à couvertures, quatre bots maximum ; garder le serveur autoritaire.
- Mode suivant : un **duel 1v1** autonome et fini, avant 2v2–5v5. Ne pas promettre les cinq modes simultanément.
- Direction visuelle : plein jour industriel olive/sable/ardoise/rouille ; aucun retour au néon ni à des assets tiers exclusifs.
- Plateformes prioritaires : téléphone Android puis PC ; autres supports après preuve de contrôle/compatibilité.
- Budget : Roblox, Rojo, Luau, Blender, scripts libres, GitHub Actions ; éviter les abonnements/credits payants.
- Promotion : progression et cosmétiques obtenables par jeu, aucun avantage pay-to-win.

## Tableau de priorités exécutable

| ID | Priorité | Chantier | Sortie attendue | Blocage externe |
|----|----------|----------|-----------------|----------------|
| P0-A | Critique | Préparer la livraison Roblox reproductible | Configuration de destination, build, stage privé, rollback documenté | Open Cloud + ID de la place |
| P0-B | Critique | Sécuriser les remotes publics et les requêtes de pathfinding | Limites par joueur, anti-spam, gestion des tâches navmesh expirées | Aucun |
| P0-C | Critique | Fermer le contrat progression et session | Reconnexion DataStore fiable, mode de secours cohérent, récupération validée | Vraie session Roblox pour la preuve finale |
| P1-A | Haute | Activer les assets 3D/PBR déjà produits | 4 opérateurs VANGUARD et 3 matériaux originaux visibles | Autorisation Assets Roblox / modération |
| P1-B | Haute | Refonte visuelle perceptible, cohérente | Silhouettes grandes masses, armes, éclairage, décors lisibles sur mobile | Visuel final des assets |
| P1-C | Haute | Signature sonore professionnelle | 5 armes différenciées, pas, recharge, impacts, ambiance | Vérifier les droits des sons |
| P2-A | Haute | Première minute de jeu, HUD public | Objectif immédiatement clair, contrôles tactiles et UI adaptatifs | Aucun |
| P2-B | Haute | Sensations combat et rythme FFA | Balance armes/bots, respawn, lecture des tirs, réengagement rapide | Mesures de jeu |
| P3-A | Haute | Mesure Android/PC et performance | Profils ECO/BALANCED/QUALITY basés sur chiffres | Test en moteur |
| P3-B | Moyenne | Maintenance et fiabilité CI | Contrats moins fragiles, services extractibles, validation avant publication | Aucun |
| P4-A | Moyenne | Progression et motivation | Maîtrise des armes, récompenses cosmétiques, objectifs légers | Persistance confirmée |
| P5-A | Après FFA | Duels 1v1 et parties privées | Création de duel, attribution équitable, victoire, revanche | Code et tests de matchmaking |
| P5-B | Après 1v1 | Équipes 2v2 puis jusqu'à 5v5 | Escouades, répartition, score, spectateur, anti-abus | Preuve de charge serveur |
| P6-A | Lancement | Page publique / découvrabilité | Icône, vignettes, texte, vidéo/captures, contrôles Roblox | Création et visibilité plateforme |

## Exécution ordonnée par lots complets

### LOT 0 — Figer une base de livraison fiable (P0-A, P0-B, P0-C)

**L0.1 — remotes et protection du serveur, autonome**
**État : protections contre rafales et répétitions intégrées côté serveur le 8 novembre 2026 ; reste la validation en réseau réel.**
- Inventorier tous les RemoteEvents et callbacks : EquipWeapon, FireWeapon, ReloadWeapon, SetSprinting, MovementAction, diagnostics et autres.
- Appliquer une validation structurée et des budgets bornés par joueur et type d'action, particulièrement aux changements d'équipement/sprint et aux actions haute fréquence, sans créer de latence artificielle sur des commandes valides.
- Vérifier les refus sur morts, changements de manche, disparition de Character, NaN, infini, payloads excessifs et attaques par spam.
- Ajouter tests Luau purs de rate-limit et contrôle d'intégration. Ne jamais donner au client l'autorité sur dégâts, vitesse, soins ou XP.
- **Livré :** limiteurs à jetons par joueur et RemoteEvent (src/shared/RemoteRatePolicy.luau, src/server/RemoteGuard.luau), protection précoce des handlers tirs/équipement/rechargement/sprint/déplacements/diagnostics. Rafales d'updates boost/wallrun bornées séparément ; arrêt du boost et du wallrun traité via un canal indépendant pour ne pas rester coincé en accélération. Répétition du même état sprint neutralisée, et changement de sprint d'un personnage mort rejeté. scripts/test_remote_rate_policy.luau vérifie saturation, équité, rejet des valeurs invalides, récupération ; scripts/check_remote_rate_contract.py valide les appels réels.
- **Contrôle moteur restant :** vérifier en Studio deux clients sous rafales et latence que les ordres d'arrêt sont pris en compte, les tirs normaux passent à cadence normale et aucun état UI ne se désynchronise. La validation statique/CI n'atteste pas d'une épreuve d'attaque réseau réel.

**L0.2 — calculs de chemin des bots, autonome**
- Corriger l'ambiguïté actuelle : expiration d'un ticket à 5,8 s ne signifie pas arrêt effectif de ComputeAsync. Éviter toute accumulation réelle et empêcher les callbacks anciens de restaurer des trajectoires périmées.
- Garantir un comportement utile sous pression : détour local borné, retour à l'itinéraire sûr, temps d'attente plafonné, pas de téléportation par-dessus une couverture.
- Exploiter le profil PERF déjà créé pour compter les requêtes réellement actives, les fins, les délais, les blocages et leur impact sur les bots.

**L0.3 — progression et exploitation, autonome + session Roblox**
- Contrôler les idempotences, états LOCKED/RETRYING, sauvegarde en sortie, reconnexion et victoire FFA. Conserver les clés existantes et prévoir toute migration avant de modifier le schéma.
- Construire un protocole Studio/test privé pour la vérification du moteur sans écrire dans les vraies données de production.
- Remettre le statut de sauvegarde clairement dans le HUD ; aucun point n'est annoncé définitivement acquis avant confirmation.

**L0.4 — mise à disposition, owner-gated**
- Conserver l'actuel pipeline CI Rojo et le workflow manuel de publication privée, avec cible IRON YARD uniquement, jamais Chaos Survival.
- Brancher, lorsqu'ils existent, IRON_YARD_UNIVERSE_ID, IRON_YARD_PLACE_ID et ROBLOX_OPEN_CLOUD_API_KEY dans GitHub Actions, sans jamais enregistrer les secrets dans le dépôt ou le chat.
- Ajouter un manifeste/version de build visible côté client et un contrôle de rollback de la place privée ; ne pas prétendre publié avant confirmation d'une version Roblox.
- Préparer ensuite un flux public séparé qui exige confirmation propriétaire et conformité ; aucune publication publique silencieuse.

**Gate LOT 0 :** Rojo vert ; spam remote contrôlé ; IA ne se bloque pas sous charge ; régression sauvegarde validée sur une expérience de test ; et version privée identifiée de manière reproductible quand l'autorisation existe. Les tâches autonomes avancent même si l'autorisation Roblox manque.

### LOT 1 — Impact visuel et sonore premium visible pour le joueur (P1-A/B/C)

**L1.1 — terminer ce qui a déjà été produit**
- Importer le kit Blender VANGUARD 4 palettes et les 12 images de matériaux, après validation propriétaire/mode de traitement Roblox ; renseigner les quatre IDs modèles et les douze IDs de textures.
- Conserver les fallbacks actuels durant l'import et sur toute erreur de modération ; interdire IDs fictifs et téléchargement de scripts dans les modèles.
- Vérifier rig R6, poids visuel, occlusion, SurfaceAppearance, UV, normals, roughness, accessoires, cohérence éclairage.
- Optimiser les GLB et les cartes PBR avant de générer un deuxième gros kit. Prioriser VANGUARD, armes en première personne et entrepôt avant microaccessoires.

**L1.2 — trois refontes visuelles prioritaires**
1. Silhouettes des opérateurs + armes (échelle de lecture, détails authentiques, animations claires).
2. Entrepôt, containers et matériaux sol/acier (panneaux, salissures, architecture, identité des voies).
3. Éclairage et atmosphère (ombres douces, détail des contrejours, silhouettes lisibles, cohérence jour).
- Chaque refonte doit être visible dans une comparaison côte à côte de l'ancien et du nouveau rendu à la même caméra, sans basculer les colliders de gameplay.
- Conserver une version ECO propre, pas une variante volontairement dégradée.

**L1.3 — son**
- Remplacer le mélange dominant de snap/bass/electronicpingshort Roblox par une bibliothèque originale ou sous licences compatibles, attribution lorsqu'exigée.
- Construire un système de sons distinct par arme, intérieur/extérieur, distance et recharge, ainsi qu'un impact caractéristique par matière.
- Limiter les voix simultanées et contrôler fatigue sonore, volumes, spatialisation et indicateurs d'accessibilité.

**Gate LOT 1 :** images réelles de l'expérience, quatre silhouettes reconnaissables, matériaux autorisés visibles, cinq signatures d'armes distinctes, animation/son synchronisés, qualité ECO acceptable.

### LOT 2 — Première partie exemplaire et identité de l'expérience (P2-A/B)

**L2.1 — accueil de session**
- Définir un seul chemin : entrée → voir l'objectif FFA → contrôler caméra/tir → première action → premier engagement → mort/reprise → résultat/progression.
- Ajouter des indices contextuels réellement joués, pas un tutoriel bloquant ; cacher définitivement ou réduire les aides une fois comprises.
- Réduire les doublons HUD ; organiser l'ordre de priorité objectif > arme/munitions > santé > feedback > score > carrière.

**L2.2 — contrôles et lisibilité Android**
- Corriger recouvrement dans petites surfaces, 16:9 et 20:9, encoches, niveaux de densité et orientation.
- Permettre personnalisation simple de la sensibilité de visée, des zones du pouce et des touches essentielles ; version PC/Android cohérente.
- Dissocier tout panneau PERF/technique du produit destiné au public.

**L2.3 — jeu de tir fini**
- Équilibrer 5 armes sur distance, cadence, précision, couverture, mobilité et rechargements.
- Améliorer en priorité le feedback impact/kill, compréhension des sources de dégâts, contre-jeu des bots, respawns et densité d'engagement.
- Laisser les quatre bots facilement identifiables et ne jamais fabriquer une illusion de joueurs humains connectés.

**Gate LOT 2 :** un nouveau joueur comprend en moins d'une minute comment gagner ; aucune assistance de développeur nécessaire ; commandes et feedback utilisables sur petit Android ; tirs et morts explicables.

### LOT 3 — Performances reproductibles et architecture durable (P3-A/B)

- Mesurer sur un même appareil Android faible gamme et un appareil Android milieu gamme, puis PC : zone calme, quatre bots actifs, combat soutenu, traversée complète de la carte.
- Cibles initiales de conception : faible gamme stable autour de 30 FPS (33,3 ms/frame), milieu gamme 60 FPS si matériel compatible (16,7 ms/frame), absence de gels de longue durée ; revoir selon les profils réellement accessibles.
- Archiver profils PERF, traces MicroProfiler/Studio, allocations d'effets, instances, mémoire, lenteurs pathfinding et comparaison avant/après.
- Retirer seulement les coûts démontrés. Évaluer le regroupement de Parts, les sons simultanés, les effets transitoires et les FPS adaptatifs avant de diminuer la qualité des silhouettes Core.
- Réduire progressivement la taille des modules monolithiques (BotService, init.client, MovementService, WeaponVisuals) avec changement de comportement nul et validation systématique.
- Transformer les checks de recherche de chaînes les plus fragiles en tests de comportements, laisser la CI compiler et construire la place.

**Gate LOT 3 :** rapports de performance par scénario, régression reproductible et seuils vérifiés ; aucun goulot majeur non expliqué en session quatre bots.

### LOT 4 — Progression et fidélisation sans pay-to-win (P4-A)

- Construire trois premières familles de défis simples : maîtrise d'arme, précision/mobilité, victoires/reprises.
- Gagner des cosmétiques purement visuels, avec inventaire durable et migration de DataStore sûre. Ne pas créer un système de monnaies/confettis déconnecté de la boucle FFA.
- Afficher récompense, progression et prochain objectif de manière brève ; le match doit rester prioritaire.
- Capturer uniquement les métriques agrégées nécessaires à l'équilibrage et à l'amélioration, sans collecte de données personnelles inutile.

**Gate LOT 4 :** récompense déterministe, durable après reconnexion, sans modification du dommage/rate of fire et sans duplication sous latence.

### LOT 5 — Modes multijoueurs après FFA stable (P5-A/B)

**5A :** extraction des règles de manche et des résultats dans un modèle commun, puis un vrai duel 1v1 : assignation, spawn équitable, victoire de manche, revanche, abandon, spectateur et prévention des faux gains. Un bot peut servir d'entraînement mais ne se fait jamais passer pour un joueur humain.

**5B :** 2v2 validé puis seulement 3v3–5v5, avec équipes, limite de joueurs, scoreboard séparé, spawn d'équipe et dimensionnement performance. Prévenir les récompenses de farming et les équipes déséquilibrées.

**Gate LOT 5 :** 1v1 réellement rejouable sans modifier le FFA ; pas de mode présenté comme disponible tant qu'il n'est pas dans la place publiée.

### LOT 6 — Version publique et présentation Roblox (P6-A)

- Préparer identité graphique du produit : icône, vignette de couverture, captures mobile/PC et bande-annonce issue du vrai jeu. Éviter toute promesse de PBR ou de mode non activé.
- Publier description courte et mode d'emploi, configuration de maturité/contenu, tags et métadonnées conformes ; s'assurer de la provenance/licence de chaque asset.
- Préparer le processus d'incidents : disponibilité, sortie de version, retour arrière, protection des clés, DataStore et logs d'erreurs.
- Passage en PUBLIC uniquement après validation des critères et action propriétaire autorisée, pas par simple commit GitHub.

**Gate LOT 6 :** page officielle correcte, jeu accessible au public, chargement normal sur Android, retour à l'action fiable, première session sans intervention développeur.

## Definition of Done commune à toutes les tâches

Une tâche n'est **terminée** que si :
1. Elle modifie le bon repo, la bonne branche et les modules concernés, sans inventer une architecture parallèle.
2. Le code réellement appelé dans le jeu porte la fonctionnalité ; aucune fonction fictive, donnée factice ou panneau réservé aux développeurs pour le public.
3. Les protections serveur, collisions, sauvegarde et ergonomie antérieures restent cohérentes.
4. Tests exécutables utiles, contrôle Luau, validations Python adaptées et build Rojo sont verts dans GitHub Actions.
5. Tout changement visible porte un critère visuel vérifiable ; tout gain de performances porte une mesure reproductible ; tout upload Roblox possède un identifiant réellement autorisé.
6. Le changelog/plan indique exactement ce qui a été livré, ce qui manque et l'expérience à vérifier sans prétendre l'avoir déjà faite.

## Ordre immédiat des prochains « Continue / Go »

**SÉQUENCE A — entièrement réalisable depuis GitHub, sans nouvel accès Roblox**
1. L0.1 : durcissement des remotes, anti-spam serveur et tests.
2. L0.2 : sûreté du nombre de ComputeAsync vraiment actifs, reprise des tâches longues et métriques.
3. L2.1 : parcours de premier match et UX sur petit écran, en gardant la mission compréhensible.

**SÉQUENCE B — nécessite uniquement les autorisations Roblox déjà prévues**
4. L0.4 : publication privée sur la bonne expérience et version identifiable.
5. L1.1 : upload/activation des meshes VANGUARD et PBR originaux.
6. L1.2 + L1.3 : refonte premium visuelle et sonore adaptée au rendu réel.

**SÉQUENCE C — approfondissement**
7. L2.2/2.3 : ergonomie, équilibre des cinq armes et comportement crédible des bots.
8. LOT 3 : campagnes performance, corrections démontrées.
9. LOT 4 : progression cosmétique ; puis LOT 5 : duel 1v1.
10. LOT 6 : packaging, publication publique contrôlée et exploitation.

La séquence A doit avancer immédiatement même si l'utilisateur n'a pas encore branché ses secrets Roblox. Aucun nouvel audit global chronologique ne doit remplacer l'exécution d'un lot commencé.

## Historique et sources

- Audit du dépôt : docs/AUDIT_GLOBAL_2026-11-08.md
- Historique technique antérieur (à ne plus utiliser comme backlog actif) : docs/ROADMAP.md
- Direction créative : docs/ART_DIRECTION.md et game/VISION.md
- Critères visuels Studio : docs/STUDIO_VISUAL_ACCEPTANCE.md
- Déploiement privé : docs/PRIVATE_ROBLOX_PUBLISHING.md
- Contrat de sauvegarde : docs/PROGRESSION_PERSISTENCE.md
- Références de jeux utilisées seulement pour principes : https://www.roblox.com/games/17625359962/RIVALS ; https://www.roblox.com/games/286090429/Arsenal


### L0.2 — correction de la limite physique des calculs IA (8 novembre 2026)

- [x] Correction d'une limite trompeuse : l'ancienne expiration de ticket après 5,8 secondes permettait de lancer un troisième ComputeAsync alors que deux requêtes moteur pouvaient toujours être en cours. Les tickets ne sont plus supprimés par l'écoulement du temps ; seule la fin réelle de l'appel asynchrone libère un créneau.
- [x] La validité d'un résultat reste limitée à 5,8 secondes : les réponses tardives ou appartenant à une révision de trajectoire dépassée sont ignorées. Les deux slots maximum restent une borne sur les requêtes physiques en cours, même si un bot abandonne son calcul après 5 secondes.
- [x] Les bots sans créneau poursuivent les déviations sûres ou attendent, sans déclencher une nouvelle requête. Si deux ComputeAsync restent bloqués dans le moteur, le serveur cesse d'en lancer d'autres jusqu'à leur retour : compromis explicite sécurité/performance contre reprise automatique.
- [x] Tests de concurrence incluant expiration logique, maintien des créneaux physiques et libération tardive ; contrôle statique anti-régression.
- [ ] Vérifier en Studio la durée maximale de ComputeAsync et le comportement des quatre bots lorsque deux appels restent durablement bloqués ; aucune annulation Roblox n'est simulée.


### L2.1 — accueil et premier engagement (8 novembre 2026)

- [x] Carte d'objectif FFA synchronisée avec le score limite réel du serveur (au lieu d'un 15 codé en dur).
- [x] Première aide non bloquante spécifique au PC (WASD, souris, clic) ou à Android (joystick gauche, visée droite, FIRE), présentée seulement si aucun tir n'a encore été émis.
- [x] Après un premier tir, une seule aide de survie/couverture et recharge est affichée si la manche est toujours active et si le joueur n'a pas déjà éliminé un adversaire ; aucun HUD de tutoriel permanent.
- [x] Aucun contrôle verrouillé, aucune requête réseau supplémentaire, aucun effet sur les dégâts ou les scores. La première action est suivie uniquement par un attribut local PlayerGui.
- [x] Tests purs du texte d'objectif, des deux profils d'entrée, de la progression du guide et de l'arrêt après élimination.
- [ ] Tester en jeu sur Android petit écran, notamment la superposition avec le HUD et la compréhension en moins d'une minute.


### L2.2 — ergonomie mobile : tailles tactiles et priorités de l'interface (8 novembre 2026)

- [x] Sur Android, le réglage MOUSE SENS (qui ne commandait pas la caméra tactile native) est remplacé par BUTTON SIZE : SMALL, MED (défaut) et LARGE. La souris PC conserve sa sensibilité.
- [x] TouchLayout applique un facteur de taille au même ensemble de dix boutons, uniquement lors du redimensionnement ou du changement de préférence locale, sans calcul par image.
- [x] Trente-six configurations automatisées (trois tailles sur douze dimensions de 300×260 à 1920×1080) vérifient la géométrie, les cibles tactiles d'au moins 28 pixels, l'absence de chevauchement entre boutons et le dégagement du bouton SET.
- [x] SET est compact, placé en haut à gauche sous la zone de score et à l'écart de la sélection d'armes.
- [x] Le briefing remplace temporairement la carte de score dans la zone haute, sans recouvrir la sélection d'armes. L'ouverture de SET masque la mission et élève le panneau de réglages devant les autres interfaces.
- [x] Contrôle d'intégration du HUD et vérification CI ajoutés. Les tirs, dégâts, mouvement et score ne changent pas.
- [ ] Valider dans Roblox sur Android la compatibilité effective avec le joystick/saut natifs, les encoches et la lecture sur plusieurs tailles d'écran ; la compilation ne simule pas le moteur graphique.

 
### L2.3 — confirmations de combat fiables, à faible coût (8 novembre 2026)

- [x] Tout tir confirmé affiche désormais dans le HUD un seul nombre compact de dégâts réellement soustraits au Humanoid, non la valeur théorique de l'arme. Un tir qui tue une cible à 9 PV affiche 9 DMG même si l'arme inflige normalement 24 dégâts. Le serveur reste autoritaire.
- [x] Les headshots affichent HEADSHOT et une priorité supérieure aux touches classiques ; les éliminations l'emportent sur les autres retours de la même volée de shotgun, avec le budget temporel existant de CombatVfxProfile.
- [x] Un tir ayant touché un adversaire protégé à la réapparition indique SPAWN SHIELD (sans marqueur trompeur ni transmission de nom/position). Les retours protégés sont plafonnés à un message toutes les 0,45 secondes par tireur.
- [x] Les RemoteEvents Miss étaient transmis à chaque tir infructueux mais n'avaient aucun consommateur client : suppression de ces transmissions inutiles. Les messages Hit, Ammo, OutOfAmmo, médailles et effets spectateurs sont conservés ; aucun changement au rythme ni aux dégâts.
- [x] Readout compact réutilisé au-dessus du viseur, sans créer de nouvel objet GUI par tir ; délais de masquage bornés. Filtre des valeurs non finies.
- [x] Tests Luau des dégâts réellement perdus, des boucliers et d'une baseline théorique des 5 armes pour une cible à 100 PV ; contrôle d'intégration des flux serveur/client en CI.
- [ ] Confirmer en jeu sur Android/PC les confirmations visuelles, la lisibilité pendant l'ADS, le cas shotgun multicibles, le respawn protégé et le débit réseau. Les TTK théoriques ne mesurent ni les dispersions ni le taux de réussite.
- [ ] Ajuster statistiquement l'équilibrage des armes après des sessions réelles ; ne pas altérer les valeurs sans référence d'usage.
