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
- Valider les contrats localement sans ouvrir l'accès Studio aux données de production, puis contrôler sauvegarde/reconnexion en session serveur Roblox après mise en public.
- Remettre le statut de sauvegarde clairement dans le HUD ; aucun point n'est annoncé définitivement acquis avant confirmation.

**L0.4 — livraison directement PUBLIQUE, manuelle et owner-gated (9 novembre 2026)**
- [x] Supprimer le workflow privé : une seule cible IRON YARD publique, jamais Chaos Survival.
- [x] Créer un workflow à lancement manuel : préflight sans upload, confirmation exacte `PUBLISH IRON YARD PUBLIC` et CI verte sur le SHA exact.
- [x] Contrôler les Universe/Place IDs, propriétaire Roblox, nom IRON YARD, visibilité PUBLIC avant et après, et place de démarrage ; aucun changement de visibilité depuis la CI.
- [x] Inscrire le SHA Git complet dans le lieu Rojo avant compilation, rendre son identifiant court visible pendant les résultats, enregistrer la version retournée par Roblox lors d'un vrai déploiement.
- [x] Préparer les tests offline du publisher et le guide Android/PC de publication/retour arrière ; aucun upload par simple push.
- [ ] Configurer `IRON_YARD_UNIVERSE_ID`, `IRON_YARD_PLACE_ID`, `ROBLOX_OPEN_CLOUD_API_KEY` côté GitHub, et mettre l'expérience au statut Public dans Creator Dashboard.
- [ ] Obtenir une version Roblox réellement publiée, puis mesurer gameplay/Android et DataStore. Aucun déploiement n'est affirmé tant qu'il n'existe pas dans Roblox.

**Gate LOT 0 :** Rojo vert, protection serveur, garde-fous publication publique validés en CI ; validation moteur et données sur une expérience publique réelle encore requise.

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
4. L0.4 : préparation puis publication uniquement PUBLIQUE sur IRON YARD après confirmation et préflight.
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


### L1.3 / L2.3 — manipulation des armes et budget audio 3D (9 novembre 2026)

- [x] Cinq profils de recul de la vue FPS, tous cosmétiques : amplitude accumulée plafonnée par arme, récupération exponentielle propre, impulsions angulaires distinctes. Shotgun et sniper retombent plus lentement ; le couteau emploie une rotation de lancer.
- [x] Mise en scène de rechargement propre à chaque arme (roulis/tangage/translation, déplacement de la main gauche et du chargeur). Progression du rechargement toujours dictée par les messages Ammo du serveur ; aucun rechargement anticipé.
- [x] Culasse du pistolet, poignée de charge du fusil automatique, pompe du shotgun et verrou du sniper suivent des courbes mécaniques distinctes. Une seule animation client dérivée du temps depuis le tir, sans nouveaux RenderStepped, RemoteEvents ni objets par image.
- [x] Mixage spatialisé : priorité permanente au son du joueur local, réduction à une couche sonore au-delà de 68 % de la portée, limites ECO/BALANCED/QUALITY selon Android/PC et plafonds des émetteurs distants actifs. Les lancers et les tirs qui infligent des dégâts sont **inchangés**.
- [x] Tests purs des cinq profils, de l'enveloppe/du plafonnement, des distances et des limites vocales. Contrôle CI que le code réellement appelé utilise les profils. Build Rojo conservé.
- [ ] Les sons actuellement exploités restent les sons Roblox intégrés existants (snap/bass/electronicpingshort). La bibliothèque définitive de sons originaux/licenciés par arme n'a pas été importée : ne pas présenter cette passe comme une refonte audio AAA finale.
- [ ] Valider en Studio/Android les animations de tirs/rechargement, la séparation des sons proche/lointain, les rafales à quatre bots et la fluidité réelle. Pas de prétention de mesures FPS/mémoire sans moteur.


### L2.4 — identité acoustique et budget audio des armes (9 novembre 2026)

- [x] Audit du rendu existant : les cinq armes possèdent déjà des animations de recul et mécanismes distincts via WeaponFeelProfile, et des couches sonores à partir d'assets Roblox génériques. Ne pas réimplémenter ces systèmes en doublon.
- [x] La spatialisation distante tient désormais compte de la portée acoustique de l'arme : fusil et sniper 100 % du budget de distance du profil graphique, shotgun 90 %, pistolet 75 %, couteau lancé 38 %. Le budget global des voix reste inchangé et les effets locaux du tireur ne sont jamais filtrés.
- [x] Tests de limites de distance et du nombre maximal de voix sur Android ajoutés ; aucun nouveau RemoteEvent, aucun nouvel asset ni instance supplémentaire.
- [ ] Produire et publier cinq véritables enregistrements originaux/licenciés Roblox (les sons actuels sont des sons génériques fournis par Roblox), puis intégrer les IDs valides sans les inventer.
- [ ] Écouter et mesurer en Studio/Android le mix réel et les transitions près/loin avant d'affirmer une qualité audio premium.

 
### L2.5 — atténuation des tirs derrière le couvert (9 novembre 2026)

- [x] Nouvelle occlusion acoustique réelle, locale au client : pour chaque tir **distant admis** au budget sonore et situé à au moins 12 studs, une unique raycast entre la caméra et la source vérifie le couvert physique. Les personnages, bots et la caméra sont exclus ; les décorations sans collision ne bloquent pas le son.
- [x] Tir direct : deux couches proches (ou une à grande distance), portée propre à l'arme. Tir derrière une structure collidable : une seule couche, volume à 40 % de la valeur d'origine, même portée et même durée de vie ; aucun son n'est entièrement supprimé.
- [x] Les tirs locaux sont toujours entendus immédiatement et ne déclenchent jamais de raycast d'occlusion. Les sons lointains déjà rejetés par les quotas ne déclenchent pas non plus de raycast.
- [x] Aucun nouveau RemoteEvent, asset, boucle par image ou objet audio ajouté. Le plafond de voix déjà en place reste strict.
- [x] Tests purs de l'occlusion/volume/limites et contrat d'intégration des raycasts et du mixage.
- [ ] Validation acoustique sur Android + Studio : tirs face à face, derrière container, couloir ouvert, près d'un mur non collidable, quatre bots, distance variable, choix ECO/BALANCED/QUALITY. Mesurer le surcoût de raycasts en jeu.
- [ ] Sons source toujours génériques Roblox en attente d'enregistrements originaux réellement importés et autorisés.

### L0.3 — fermeture tardive des sessions DataStore (9 novembre 2026)

- [x] Corrigé le cas où `UpdateAsync` acquiert le verrou **après** la fin du délai de `PlayerRemoving` : une fermeture différée sauvegarde le cumul local et libère le verrou avec le GUID d'origine, même après retrait du joueur de `records`.
- [x] Les accusés de réception de fermeture déjà réussie restent idempotents si un autre serveur a repris la clé : le marqueur `lastSession` doit prouver les compteurs, sans toucher au nouveau verrou.
- [x] Régression Luau couvrant cette course, la préservation du nouveau verrou et le refus d'un gain non sauvegardé.
- [ ] Tester la récupération d'une session avec latence/expiration réelle sur une expérience Roblox **privée de test** ; aucune garantie de persistance si le processus est interrompu ou si Roblox DataStore reste indisponible.
- [ ] Compléter L0.3 (migrations éventuelles, reconnects et statut de sauvegarde en session réelle) avant de considérer le gate LOT 0 validé.

### L0.3 — statut réel des XP non encore sauvegardés (9 novembre 2026)

- [x] Le serveur réplique séparément `IronYardSavedXP` depuis la dernière acquisition/écriture DataStore acquittée, sans modifier les clés ni le schéma v1.
- [x] Le HUD de carrière affiche `SAVE PENDING` pour les gains non encore écrits et `SAVED` uniquement lorsque le cumul visible est confirmé ; indication compacte maintenue pendant la manche sur Android.
- [x] Les gains reçus pendant un `UpdateAsync` en cours restent en attente ; les échecs n'avancent jamais le compteur confirmé. Vérifications statiques du flux ajoutées à la CI.
- [ ] Confirmer les transitions des indicateurs dans une session publiée de test, sur Android puis PC, avec des retards réseau/écritures.


### L0.4 — pivot confirmé : aucune version privée (9 novembre 2026)

La publication privée est abandonnée à la demande du propriétaire. Le pipeline public est manuel et refuse de transformer la visibilité d'une expérience ou d'écraser Chaos Survival. La vérification à blanc doit précéder le déploiement public réel, lequel reste impossible sans une expérience IRON YARD déjà publique et une clé Open Cloud configurée. Les tests DataStore en serveur réel sont à mener après publication sous contrôle, sans configurer Studio pour écrire sur les clés de carrière de production.


### L1.2 — refonte visuelle des quatre grandes limites de l'arène (9 novembre 2026)

- [x] Nouveau parement industriel original à **28 travées 3D** sur les quatre grands murs de 356 × 38 studs, dérivé uniquement des vrais colliders `MapService`. Les grandes tôles acier, poutrelles hautes et plinthes ambre restent visibles en ECO ; les cadres de joint et les petites ouïes relèvent du LOD Detail mobile.
- [x] Douze grandes inscriptions de secteurs WEST/EAST/NORTH/SOUTH, lisibles depuis la zone de jeu sans ID d'image importée. Une seule surface d'inscription par panneau sélectionné, sans lumière dynamique, RemoteEvent ni calcul par image.
- [x] Aucune nouvelle collision, interception de raycast, surface d'escalade ou obstacle IA : tous les éléments décoratifs sont `CanCollide=false`, `CanTouch=false`, `CanQuery=false`, `CastShadow=false` et participent au système `NeonArtTier` existant.
- [x] Plan pur Luau testant les 4 colliders exacts, 28 panneaux, 12 plaques, limites des sections, rejet des dimensions/identités invalides. Contrôle d'intégration et build Rojo en CI.
- [ ] Valider les quatre côtés dans Roblox Studio/Android, notamment contraste et lisibilité des plaques, recouvrement avec les anciens poteaux et enseignes, taille des éléments sur petit écran, absence de scintillement, FPS et mémoire à quatre bots. Aucune mesure réelle n'est revendiquée.


### L1.2 — entrée monumentale de l'entrepôt et circulation lisible (9 novembre 2026)

- [x] Création d'un **portail de fret industriel** dans la vraie ouverture sud de l'entrepôt : linteau, auvent métallique, deux piles, liseré ambre et grande plaque IRON YARD / FREIGHT PROCESSING. Cette identité reste lisible en ECO Android ; les contreventements/chevrons sont classés Detail pour le LOD existant.
- [x] Trois lignes directrices sur l'asphalte indiquent l'entrée réellement praticable, sans fausse ouverture ni repère décoratif qui pourrait bloquer un tir.
- [x] Le plan utilise exclusivement les **3 vrais colliders MapService** (murs ouest et est, cloison nord), avec vérification stricte de leurs dimensions, positions, orientations et noms ; sur changement de géométrie, aucun décor décalé n'est construit.
- [x] Zéro nouvel obstacle physique ou raycast, aucune lumière serveur, nouveau RemoteEvent ou boucle client ; l'intégration est effectuée dans `ArenaArt.build`.
- [x] Tests Luau du plan et des rejets + vérification d'intégration CI et build Rojo.
- [ ] Contrôle Studio et Android : lisibilité du panneau depuis les arrivées sud, absence de confusion avec une couverture physique, chevrons sans scintillement à l'approche, silhouette depuis les passerelles et coût GPU réel. Aucun FPS mesuré en CI.


### L2.6 — affichage fiable des sauvegardes en fin de manche (9 novembre 2026)

- [x] Ajout d'un indicateur réel SAVED / XP SAVE PENDING / LOADING / STUDIO / RETRYING à l'écran RESULTS, puisque le HUD carrière est caché pendant le podium. Les gains arrivant pendant un UpdateAsync restent affichés comme non sauvés.
- [x] Les deux HUD utilisent la même politique Luau pure `CareerReadout` (sans RemoteEvent ni accès DataStore client). Une réplication hors ordre ne peut pas faire afficher SAVED si les compteurs reçus sont discordants.
- [x] Affichage des XP restant pour atteindre le rang suivant, plutôt que du seuil cumulatif ambigu ; même pourcentage dans le HUD et le podium.
- [x] Tests de politique pure et contrôle d'intégration CI, sans nouvelle instance graphique à chaque XP.
- [ ] Tester les transitions d'autosave dans une session Roblox publique réelle avec Android/PC, victoire FFA et reconnexion.


### L3.1 — budget de tirs VISUELS distants Android (9 novembre 2026)

- [x] Audit du pipeline : les armes et les bots sont déjà filtrés par distance, mais quatre bots peuvent produire une rafale collective de Parts/Tweens malgré le LOD existant. L'émetteur distant dispose maintenant d'un **token bucket partagé BOT** et d'un bucket séparé PLAYER, afin que les effets des bots ne privent pas les autres joueurs humains de leurs retours visuels.
- [x] ECO Android : jusqu'à **4 groupes BOT/s** (+2 groupes de courte rafale), BALANCED : **7/s** (+3), QUALITY : **11/s** (+4). Le groupe englobe tracer, flash et impact afin d'éviter la création d'effets incomplets. Les tirs humains distants ont leurs propres quotas plus élevés.
- [x] Admission locale O(1) et deux seuls états conservés pour toute la session ; aucune boucle par image, aucun nouvel objet serveur ou RemoteEvent. Les tirs prévus du joueur local et les indications serveur de dégâts/kills ne traversent **jamais** ce filtre.
- [x] Les règles de distance restent prioritaires. Les impacts de pellets d'un joueur local restent visibles malgré les quotas des autres tireurs. Tests purs de charge 1000 événements/s, cas 4 bots, priorité humains, preset ECO/BALANCED/QUALITY et entrée invalide ; contrôle de branchement des deux chemins réseau.
- [ ] Mesurer le vrai coût GPU, nombre d'effets simultanés, FPS p95 et confort de combat sur Android faible gamme face à quatre bots ; la CI prouve les plafonds logiques, pas un gain de FPS observé. Ajuster les quotas selon mesures.


### L3.2 — marques d'impacts recyclées, sans Tween/Debris par tir (9 novembre 2026)

- [x] `WeaponVisuals.drawImpact` réutilise les objets Part locaux des marques d'impact, au lieu de créer, tweener et détruire une nouvelle Part par balle qui touche le décor.
- [x] Plafond strict de **36 Parts mises en cache au maximum**, quels que soient le nombre de bots, la durée de session ou le volume de tirs. ECO/BALANCED/QUALITY conservent leurs plafonds visibles de 10/16/22 sur mobile et 26/36 sur PC. À saturation, la marque la plus ancienne est recyclée.
- [x] Fondu des marques sur les 1,1 dernières secondes et expiration à fréquence **8 Hz** dans le RenderStepped déjà existant ; aucune nouvelle boucle et aucune allocation de Tween ou de Debris par marque. Les Parts expirées ou exclues par le LOD ont `Parent=nil` ; elles ne bloquent ni les déplacements ni les raycasts.
- [x] Plan pur `ImpactMarkPool.luau` testé sous 5000 impacts, réutilisation, réduction de qualité, durée de vie, entrées invalides, nombre constant de slots ; compilation et build Rojo CI.
- [ ] Mesurer la mémoire et la fluidité réelles sur Android en tir continu, quatre bots et changement de profil ; les particules transitoires restent volontairement indépendantes jusqu'à validation du rendu natif.


### L3.3 — pool de tous les VFX transitoires des tirs (9 novembre 2026)

- [x] Les traceurs, flashs de bouche, pétales de flash, ricochets acier, éclats, poussières et impacts mineurs de shotgun utilisent désormais **un seul pool local de Parts réutilisables**, au lieu de créer un Part + Tween + Debris pour chaque émission.
- [x] Budgets de pool selon qualité : ECO 24, Android BALANCED 48, Android QUALITY 72, PC BALANCED 80, PC QUALITY 96 Parts maximum. Les effets expirés sont masqués puis réutilisés, sans nettoyage différé ou tâche supplémentaire.
- [x] Animation fluide sub-300 ms dans le RenderStepped existant, sans boucle ajoutée ; interpolation linéaire pour les traceurs et quadratique pour les impacts, flashs et poussières.
- [x] Priorité 4 aux flashs du joueur local, 3 aux flashs distants, 2 aux traceurs et impacts pellets, 1 aux débris : les petits éclats ne peuvent pas expulser les retours essentiels à saturation. Toutes les propriétés du Part sont réinitialisées lors d'une réutilisation, y compris la désactivation du PointLight sur une ancienne bouche de canon.
- [x] Aucun changement de dégâts, validation réseau, IA, sons, VFX confirmés de touche, statut des points de carrière, collision ou raycast. Aucun effet 3D de dégâts confirmé n'est throttlé par le pool.
- [x] Tests Luau purs : 12 000+ impacts, saturations, priorités, renversement temporel, baisse de preset, entrées invalides, réutilisation d'instance. Contrat intégration et build Rojo dans la CI.
- [ ] Vérifier visuellement tous les effets sous 4 bots en Studio/Android (notamment lumière de bouche réutilisée, ordre de priorité, absence de traînées figées) puis comparer FPS et mémoire avant/après.


### L3.4 — LOD des bots en cache avec prise en charge du streaming (9 novembre 2026)

- [x] Le client ne reparcourt plus chaque seconde l'ensemble des descendants 3D de chaque bot. La liste des pièces `NeonCosmeticTier=Detail` est construite **une fois lors de l'apparition** de chaque modèle puis actualisée via `DescendantAdded` et `DescendantRemoving`.
- [x] Les pièces apparaissant après le modèle (streaming Roblox) adoptent immédiatement l'état LOD courant ; un abonnement temporaire traite les attributs `NeonCosmeticTier` arrivant après la pièce, puis se déconnecte.
- [x] La boucle de contrôle à 1 Hz n'effectue plus qu'un test de distance au carré par bot. Les propriétés de transparence ne sont réécrites **que** lors d'un changement de mode SHOW/HIDE ou de l'arrivée d'une nouvelle pièce.
- [x] Hystérésis précédente et seuils ECO/BALANCED/QUALITY strictement conservés. Toutes les pièces Core, humanoïdes et hitboxes restent inchangées. Les abonnements et références du cache sont libérés lors du remplacement du bot ou de son dossier.
- [x] Plan Luau pur, tests des changements de qualité, streaming tardif, apparition/disparition du bot et réutilisation sans accumulation ; contrôle d'intégration Python, compilation Luau et build Rojo dans CI.
- [ ] Validation Android/PC : tuer/recréer quatre bots pendant les déplacements, entrer/sortir des seuils de visibilité, observer les pièces répliquées tardivement, mesurer FPS/mémoire et comparer au build précédent.


### L3.5 — index spatial des décors incrémental (9 novembre 2026)

- [x] Corrigé le rebâtissage global de tous les `GetDescendants()` lorsqu'un seul Part apparaît/disparaît en streaming : les 3 dossiers de décor (`NeonStrikeDecor`, `FreightLandmarks`, `IronYardCoverSkins`) créent désormais leur inventaire une seule fois, puis utilisent `DescendantAdded/Removing` et l'index `ArtSectorRegistry`.
- [x] Écriture en O(1) dans l'index de secteur de 48 studs pour chaque nouvel élément de détail. Un retrait recalcule uniquement l'AABB du secteur concerné ; disparition du dernier élément = retrait complet du secteur.
- [x] Les éléments qui répliquent l'attribut `NeonArtTier` après le `Part` sont rattachés via un abonnement temporaire, ensuite libéré ; l'élément tardif hérite immédiatement du masquage selon la dernière position de caméra, sans attendre la prochaine seconde.
- [x] Les modèles ou dossiers retirés libèrent leurs abonnements et leurs références; l'arène remplacée n'hérite pas de caches obsolètes.
- [x] Seuls les éléments `Detail` non-collidants sont pilotés ; `Core`, collisions, raycasts, bots, tirs et lumières sont inchangés. Seuils ECO/BALANCED/QUALITY, marges anti-scintillement et marge de mouvement des ponts roulants conservés.
- [x] Tests purs : 2000 parties ajoutées, la moitié supprimées et contrôle exact des AABB par rapport à un rebuild, puis purge complète ; tests de rejets/duplication et contrôle d'intégration en CI.
- [ ] Mesures Android en situation (chargement progressif du grand décor, changements de qualité et mouvements de caméra) et contrôle visuel d'absence de flash temporaire, à comparer à l'ancienne version.

- [x] Libération d'un dossier/arène en une purge de l'index entier (sans recalcul des AABB de chaque pièce), avec remise à zéro des modificateurs de transparence et des abonnements.


### L3.6 — amortissement du chargement des décors et des retraits (9 novembre 2026)

- [x] Index initial des trois dossiers 3D enregistré par tranches coopératives : 48 inspections par Heartbeat en ECO Android, 96 en BALANCED Android, 128 en QUALITY Android, 96 en ECO desktop et 192 en BALANCED/QUALITY desktop. L'enregistrement est annulé si le dossier disparaît ; les événements de streaming continuent à s'appliquer immédiatement.
- [x] Le cache évite l'indexation double quand un élément reçoit à la fois une notification de streaming et apparaît dans la capture initiale. Les éléments déjà retirés sont ignorés.
- [x] Les ajouts/retraits intérieurs dans un secteur n'invalident plus son mode LOD ; les retraits n'actualisent les limites du secteur que si une pièce constituant l'un de ses extrêmes est retirée, et le mode est conservé si les nouvelles limites restent identiques.
- [x] Les seuils ECO/BALANCED/QUALITY, silhouettes Core, collisions, déplacements, tirs et IA restent inchangés. Tests Luau : 1 000 ajouts et 1 000 retraits intérieurs, extrémités partagées, budgets de chargement et rejets existants ; build Rojo et contrôles d'intégration CI.
- [ ] Sur Android réel, comparer FPS, temps d'image p95/p99 et variations d'affichage à l'apparition de l'arène avec quatre bots. Observer si le premier inventaire en plusieurs images laisse temporairement apparaître des détails lointains.


### L3.7 — cadence adaptée des quatre ponts roulants (9 novembre 2026)

- [x] Les quatre modèles mobiles gardent leur oscillation d'origine déterministe : 15 Hz à proximité sur Android, 24 Hz sur PC. À moyenne distance : 9/12 Hz ; à grande distance visible : 5/8 Hz. Le profil ECO et les modèles hors des seuils de 185/285 studs ne calculent plus de pose ni de `PivotTo`.
- [x] Calcul de distance au carré par rig à la fréquence de contrôle existante ; racine carrée, sinusoïdes, PivotTo et calcul de temps synchronisé seulement lorsqu'une pose visible est réellement due. Mise à jour indépendante des quatre rigs, sans boucle supplémentaires ni charge serveur.
- [x] Transition immédiate lorsque l'appareil change de profil ou lorsque le rig entre/sort de son périmètre visible ; un modèle masqué ne se repositionne et ne réinitialise son phare qu'une fois. Pas de rattrapage d'animations après un ralentissement.
- [x] Les feux restent visuellement pulsés, mais les `PointLight` dynamiques ne sont autorisés que sur desktop QUALITY à moins de 150 studs (plus sur Android). Les feux lumineux Android conservent leur matériau coloré sans lumière calculée.
- [x] Robustesse au streaming : un phare manquant invalide proprement l'enregistrement du modèle, désactive/détruit sa lumière locale ; le hook de chargement existant le réinscrit si une pièce revient.
- [x] Tests Luau de cadence pure, bornes de distance, ECO/QUALITY et entrées invalides + compilation/contrôles d'intégration/build Rojo CI.
- [ ] Mesurer l'impact CPU/GPU, la qualité des animations lointaines et l'apparence des phares en ECO/BALANCED/QUALITY sur Android et desktop ; les tests de politiques ne démontrent pas de gain FPS réel.


### L3.8 — robustesse au streaming des ponts roulants (9 novembre 2026)

- [x] Un modèle de pont roulant qui arrive avant ses attributs `IronYardGantryMover` / `IronYardGantryIndex` peut maintenant s'enregistrer dès leur réplication, sans nécessiter un rechargement complet du dossier.
- [x] Les nouveaux `BasePart` reçus dans les modèles candidats déclenchent une nouvelle tentative d'enregistrement lorsque le phare manquait. Un modèle retiré libère ses abonnements et sa lumière locale.
- [x] Les changements d'index sont traités en repartant du pivot d'origine, et les changements de statut `Mover` suppriment l'ancien rig.
- [ ] Vérifier en Studio avec `StreamingEnabled` : apparition différée du modèle, du phare et des attributs, remplacement du modèle pendant le combat, absence de double lumière.


### L3.9 — réparation déterministe des phares lors du streaming rapide (9 novembre 2026)

- [x] Corrigé une course entre le remplacement du phare d'un pont roulant et la cadence visuelle réduite. Le nouvel élément peut arriver avant le prochain Heartbeat d'animation : l'enregistrement remplace désormais le rig obsolète si son ancien phare n'appartient plus au modèle, même lorsque le modèle et son index n'ont pas changé.
- [x] Le départ d'un phare détecté par `DescendantRemoving` libère immédiatement sa lumière locale et son rig ; l'arrivée du remplaçant réinscrit le modèle.
- [x] Lors d'une modification de l'index, du mode Mover ou du phare, le modèle revient à son pivot de départ avant le réenregistrement : pas de dérive accumulée de l'animation.
- [x] Les abonnements à des attributs tardifs restent actifs pendant la vie du modèle ; pas de déconnexion/réinscription inutile lors d'un changement Mover true/false.
- [x] Politique pure `needsRigReplacement`, cas de régression Luau et garde statique du vrai branchement client. Aucune modification de collisions, serveur, mouvements joueurs ou réseau.
- [ ] Validation visuelle en Studio avec streaming activé (suppression/recréation de phares sous ECO et QUALITY, disparition/réapparition d'un modèle pendant un déplacement) et mesures FPS Android.

- [x] Couverture supplémentaire du chevauchement de streaming : si le remplaçant est déjà présent avant la destruction de l'ancien phare, le client retente l'enregistrement après le retrait, sans recopier le Part sortant ; aucune action si le Model entier est parti.


### L3.10 — effets de combat actifs uniquement (9 novembre 2026)

- [x] Suppression du parcours complet des 96 emplacements du pool VFX à chaque RenderStepped après le premier tir : seul l'ensemble `activeTransientIndices` des effets actuellement visibles est animé. En phase inactive, `next(self.activeTransientIndices)` évite tout travail sur les slots.
- [x] Le pool `TransientFxPool.claim` retourne maintenant la référence ET son index, sans recherche supplémentaire pour retrouver l'emplacement réutilisé. Priorités locales et distantes inchangées : tirs locaux prioritaires, sans nouvel effet serveur.
- [x] À expiration ou lors d'un passage QUALITY → ECO, les effets hors plafond sont détachés du rendu, leurs lumières sont désactivées et leurs indices retirés ; les instances restent recyclables pour le prochain tir.
- [x] Régression Luau : 18 000 demandes d'effets avec changements de qualité, expiration, réutilisation et plafonds 24/48/72 Android, 80/96 PC ; contrôle de branchement Python et build GitHub.
- [ ] Mesures réelles de frame time/FPS sur Android avec quatre bots, phase de combat intense puis repos, et transitions ECO/BALANCED/QUALITY : les tests de pool ne démontrent pas un gain FPS mesuré.


### L3.11 — jauge de propulsion Android sans créations de Tweens par image (9 novembre 2026)

- [x] Corrigé le HUD de boost : `setBoostFuel` est appelé par la boucle de mouvement à chaque `RenderStepped`, mais auparavant il lançait un `TweenService:Create` à chaque appel même lorsque le carburant restait à 100 %. Les nouvelles demandes sont filtrées par une politique pure `BoostMeterPolicy` : jusqu'à 10 animations/s pendant les changements progressifs, aucune durant les états constants.
- [x] Les transitions de couleur NORMAL/WARNING/CRITICAL (seuils 25 % et 12 %) et les passages à exactement 0 % et 100 % restent immédiats, y compris si l'intervalle d'animation n'est pas terminé. Les Tweens précédents sont interrompus pour éviter l'empilement.
- [x] Le serveur, la quantité de carburant, les déplacements et les contrôles tactiles restent strictement inchangés. Seule la représentation visuelle de la jauge est mise à jour moins souvent.
- [x] Simulation Luau de 3601 images à 60 FPS, vidange/remplissage, seuils urgents, horloges et valeurs invalides, et absence d'animations à l'arrêt. Contrat Python de câblage HUD et suite Rojo CI.
- [ ] Vérifier visuellement sur Android et PC les transitions à 12 % et 25 %, l'absence de scintillement et le frame-time réel pendant un combat avec quatre bots.


### L3.12 — arme FPS : transparence mise à jour uniquement à l'équipement et à la lunette (9 novembre 2026)

- [x] Supprimé les écritures de transparence sur chaque pièce de l'arme à chaque `RenderStepped`. La pose CFrame reste mise à jour chaque image, pour préserver caméra, recul, rechargement et fluidité.
- [x] Mise à jour événementielle de l'opacité de l'arme FPS : une fois à l'équipement, puis au changement de visée optique du sniper. Le verre et les éléments semi-transparents retrouvent leur valeur d'origine à la sortie de la lunette ; les autres armes restent visibles en visée.
- [x] Une seule courbe de mécanisme de tir est calculée par image, celle de l'arme actuellement équipée ; les courbes des trois autres armes à feu ne sont plus calculées inutilement.
- [x] Tests pure Luau sur 3600 images, les cinq armes, changement rapide sniper/visée, préservation des transparences ; contrôle de câblage Python, compilation et build Rojo CI.
- [ ] Vérifier sur Android les animations de recul/rechargement et la lunette sniper lors d'un changement d'arme rapide ; comparer temps d'image/FPS sur appareil réel.


### L3.13 — données vitales du HUD idempotentes et sûres après respawn (10 novembre 2026)

- [x] Les synchronisations serveur identiques de munitions n'entraînent plus de réécriture de texte/couleur. Les transitions `RELOADING...`, `UNLIMITED`, munitions faibles et l'équipement restent immédiates, sans temporisation ou perte de données.
- [x] Le HUD de santé évite les écritures de couleur et de texte ainsi que les Tweens répétés lorsque la valeur affichée n'a pas changé. Un vrai changement de santé relance immédiatement une seule animation de barre, en annulant la précédente ; les flashs de dégâts continuent de se déclencher sur une perte de santé même si l'affichage arrondi n'a pas changé.
- [x] L'arrivée d'un nouveau personnage invalide les anciennes demandes de `WaitForChild("Humanoid", 5)` et les anciens événements de santé via un jeton de génération ; les anciens événements ne peuvent plus écraser le nouveau HUD après respawn.
- [x] Nouveau module pur `CombatReadoutPolicy` et régression Luau sur 10 000 snapshots identiques, armes à munitions faibles, transitions de rechargement, seuils de santé et vie maximale. Contrôles de câblage et build Rojo.
- [ ] Vérifier visuellement sur Android une rafale de dégâts, la régénération, le changement de chargeur, la mort/réapparition et comparer les temps d'image en combat. Les tests CI ne mesurent pas les FPS.


### L3.14 — audit client : nettoyage des références du corps à la première personne (10 novembre 2026)

- [x] Corrigé une liste croissante de `BasePart` du personnage local parcourue à chaque `RenderStepped`. Elle recevait les `DescendantAdded`, mais n'avait pas de gestion des `DescendantRemoving` : accessoires, outils ou membres sortis du personnage pouvaient rester dans le tableau jusqu'au prochain respawn.
- [x] Nouveau `FirstPersonBodyCache` dense à index direct et retrait par permutation en O(1), sans doublons ni références aux Parts retirées. Les suppressions de conteneurs entiers nettoient leurs sous-arbres ; pas de parcours du personnage complet en boucle.
- [x] Tous les abonnements sont libérés et l'index purgé lors de chaque changement de Character. La caméra Roblox peut continuer à écraser `LocalTransparencyModifier` : le recalage des seules pièces encore vivantes reste assuré chaque image pour conserver la première personne et les armes visibles.
- [x] Suite Luau : 4000 Parts streamées et retirées, sorties au milieu de la liste, doublons, reparenting, 100 respawns consécutifs ; contrat de câblage Python, compilation et build Rojo.
- [ ] Vérification en Studio/Android : accessoires apparaissant/disparaissant pendant un combat, mort et respawn, caméra en première personne, absence de bras/visage qui masquent l'arme. Mesurer le frame-time réel.


### L3.15 — scoreboard sans écritures inutiles ni leaderstats obsolètes (10 novembre 2026)

- [x] Le panneau de match ne réécrit `header.Text` et `detail.Text` que lorsque la valeur réellement visible change. Les événements de phase, de temps, de score et de bots restent réactifs immédiatement.
- [x] Un compteur de génération protège les connexions `leaderstats` lors d'un remplacement pendant `WaitForChild("Eliminations", 10)`. L'ancien signal est déconnecté et une réponse obsolète ne peut plus écraser le score courant.
- [x] Contrat d'intégration Python ajouté à `check_mobile_hud_contract.py` et exécuté dans la CI existante.
- [ ] Valider en session Roblox la réplication lente des leaderstats, le changement de manche et les transitions de spawn ; comparer les écritures UI avec les versions précédentes.


### L3.16 — mesures P95/P99 et reconnexion du HUD tactique (10 novembre 2026)

- [x] Le bouton PERF privé (créateur/Studio uniquement) affiche maintenant FPS, temps d'image maximal, P95/P99 des 240 dernières images et nombre d'images au-delà de 33,3 ms. L'ancienne mesure FPS/pic ne distinguait pas les ralentissements récurrents des incidents isolés.
- [x] `ClientFrameWindow` utilise un tableau circulaire borné à 240 images, sans allocation par image ; le tri statistique est déclenché au plus une fois par seconde lorsque PERF est activé. Le suivi est réinitialisé à chaque activation, ne quitte pas le client, et ne modifie aucun service de gameplay.
- [x] La connexion aux changements de taille de `CurrentCamera` est désormais recréée après remplacement de la caméra, avec libération de l'ancien abonnement. Les textes de secteur et cap du HUD tactique ne sont plus réécrits lorsqu'ils sont identiques.
- [x] Tests Luau : quantiles exacts nearest-rank, 240 entrées tournantes, pics à 33/50 ms, reset et entrées invalides. Contrôles Python des câblages et sécurité du panneau, puis compilation et build Rojo CI.
- [ ] Enregistrer sur Android, avec le compte créateur, des sessions comparables de 60 secondes et quatre bots : FPS, P95, P99, nombre d'images lentes, ECO/BALANCED/QUALITY. Cette mise à jour rend les ralentissements mesurables, mais n'est pas une preuve de gain FPS.


### L3.17 — répartition des calculs serveur des quatre bots (10 novembre 2026)

- [x] Les quatre mises à jour tactiques (visibilité des ennemis, sélection de cible, couverture et navigation) ne sont plus toutes déclenchées dans la même tranche de 200 ms. La boucle distribue les vérifications sur quatre tranches de 50 ms ; chaque bot continue à prendre ses décisions à la fréquence cible de 5 Hz. Tir, cadence d'arme, vitesse, dégâts et autorité serveur ne sont pas modifiés.
- [x] Nouveau planificateur pur `BotThinkCadence` : phases déterministes propres aux slots 1 à 4, temps absolu pour éviter une convergence progressive des phases, délai minimum de 75 % de l'intervalle pour empêcher les décisions répétées trop rapidement à la suite d'une image serveur retardée. Réinitialisation correcte lors de la création d'un bot et d'un nouveau round.
- [x] Les mises à jour de pose R6 à 15 Hz près du joueur et 8 Hz au loin sont également étalées par slot ; le contrôle de proximité est fait sur les distances au carré sans changer le seuil de 155 studs.
- [x] Tests Luau sur 10 secondes de combat à cadence régulière, 4 bots, équité de fréquence, cas de retard, bornes du planificateur, 8/15 Hz des poses, et contrôles statiques du vrai câblage serveur ; compilation complète et build Rojo CI.
- [ ] Dans Roblox Studio/serveur public, mesurer avec les outils PERF l'impact réel sur les pics `thinkMs`, `poseMs` et le P95/P99 client avec quatre bots sous le même scénario. Les tests garantissent une répartition logique, pas une amélioration chiffrée des FPS.


### L3.17 — art LOD : suppression des parcours inutiles quand la caméra reste immobile (10 novembre 2026)

- [x] Le contrôle LOD des décors, exécuté une fois par seconde, ne parcourt plus tous les secteurs lorsque la position de caméra et les seuils du preset sont strictement inchangés et qu'aucune pièce de décor n'a été ajoutée ou retirée. Les pièces nouvellement streamées conservent leur application immédiate de visibilité.
- [x] Toute addition/suppression de détail marque l'inventaire comme modifié ; le prochain balayage recalcule alors les secteurs concernés. Les changements de preset ECO/BALANCED/QUALITY et tout déplacement réel de caméra déclenchent aussi un balayage complet, sans retard de seuil artificiel.
- [x] Aucun changement aux collisions, hitboxes, bots, dégâts ou règles du serveur. Contrat de régression Python mis à jour pour interdire l'oubli d'invalidation ; build Rojo et CI validés.
- [ ] Mesurer dans Roblox sur Android le coût du LOD avec caméra fixe puis en déplacement rapide ; valider le streaming et les changements de qualité visuellement.


### L3.18 — streaming des décors à caméra rapide et LOD borné (10 novembre 2026)

- [x] Les détails 3D reçus via le streaming sont désormais classés avec la position **actuelle** de la caméra ; le dernier point d'échantillonnage à 1 Hz n'est utilisé qu'en secours si `CurrentCamera` n'est pas disponible. L'ancienne position pouvait dater d'une seconde après une propulsion rapide et masquer à tort des détails proches.
- [x] Ajout d'une fréquence de contrôle LOD **adaptative et plafonnée** : cadence ordinaire de 1 Hz (et aucune boucle de secteurs coûteuse à l'arrêt grâce au cache précédent) ; 4 Hz maximum lorsque la caméra s'est déplacée d'au moins 20 studs depuis le dernier échantillonnage, ou après un changement de qualité. Les bots conservent strictement leurs contrôles LOD à 1 Hz. Aucun rattrapage d'images manquées n'est exécuté.
- [x] La visibilité immédiate des pièces streamées conserve les mêmes seuils et la même hystérésis de détail ; les silhouettes majeures, les collisions, les hitboxes et la navigation serveur restent inchangées.
- [x] Tests Luau sur 60 s simulées, plafond 4 Hz, état statique, transitions ECO/QUALITY, caméra remplacée/absente et apparition de détails proches/lointains lors de déplacements rapides ; vérification des contrats Python et build Rojo.
- [ ] Sur Android, tester une séquence propulsion + demi-tour dans chaque zone, les détails qui streament en entrant/sortant de portée, les transitions de presets et les temps d'image P95/P99. La réussite de la CI n'établit pas de gains FPS mesurés.


### L3.19 — tirs confirmés recyclés et signaux d'animation IA sans allocations (10 novembre 2026)

- [x] Les confirmations visuelles de dégâts serveur (`IronYardConfirmedHit` et `IronYardHitSpark`) n'instancient plus de nouvelles Parts et Tweens à chaque touche. Les mêmes volumes, couleurs, expansions et disparitions Quad.Out sont animés par le pool commun `TransientFxPool` déjà mis à jour à chaque `RenderStepped`, sans nouveau système de rendu, `Debris` ou timer.
- [x] Le noyau d'une confirmation de dégâts reçoit la priorité maximale 4 ; les scintillements associés reçoivent 3. Les fragments décoratifs ne peuvent donc pas déloger le noyau d'une confirmation de touche à saturation, même sur Android ECO. Les règles de priorité tête/élimination et les délais anti-spam sont conservés ; dégâts, raycasts, autorité serveur et messages réseau restent inchangés.
- [x] Régression Luau de 5 400 touches simulées en ECO/BALANCED/QUALITY Android, avec trafics concurrents de tirs, plafonds de 24/48/72 slots, admission des noyaux confirmés et refus de préemption par des effets faibles. Contrat Python assure l'absence de création de Parts/Tweens dans `drawConfirmedHit` et interdit les nouveaux timers `Debris` de combat.
- [x] `BotMotionProfile.turnSignal` et `reversalSignal` n'allouent plus chacun de tableau de cinq/quatre composantes à chaque animation serveur : vérification scalaire des valeurs finies avec la même logique et les mêmes bornes. Tests 50 000 itérations de rotation/inversion, données invalides et contrôle statique interdisant le retour de tables temporaires.
- [ ] En jeu Android réel, comparer à quatre bots les percentiles P95/P99, rafales d'impacts confirmés, tirs à la tête/éliminations, visibilité à courte distance et changement ECO ↔ QUALITY ; vérifier que les effets importants ne disparaissent pas prématurément en cas de pool saturé. Évaluer les temps de pose serveur. La CI ne démontre aucun gain FPS quantifié.


### L3.20 — vapeurs des extracteurs recyclées et fréquence de rendu bornée (10 novembre 2026)

- [x] Audit de `ExhaustAmbient.client.luau` : chaque émission de fumée créait une nouvelle `Part`, un `TweenService:Create` et une entrée `Debris`, alors que la sélection des sources proches était déjà limitée. Les wisps utilisent désormais `ExhaustWispPool`, un petit pool local qui réutilise les Parts après expiration, sans animation Tween ni minuterie Debris par émission.
- [x] Plafonds liés aux préréglages : ECO = 0 ; Android BALANCED = 2, QUALITY = 5 ; PC BALANCED = 5, QUALITY = 11. Plafond absolu = 12, sans préemption des émissions encore visibles ; une saturation temporaire supprime seulement la nouvelle bouffée décorative.
- [x] Animation `Quad.Out` conservée avec les mêmes positions de départ/fin, tailles, transparence et durée (1,08 s). Mise à jour plafonnée à 30 Hz dans un unique RenderStepped, sans travail de pool quand aucune bouffée n'est active. Les objets expirés sont déparentés ; toutes les Parts recyclées sont détruites lorsque le script est supprimé.
- [x] Respect des plafonds et raycasts : `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `CastShadow = false`. Aucun changement aux émissions serveur, à la navigation, aux bots ou aux armes.
- [x] Test Luau sur 20 000 cycles d'émission, saturation, transition ECO/QUALITY, réutilisation de Part et courbe Quad.Out ; contrat Python contrôlant l'absence de Tween/Debris et l'intégration au rendu ; compilation et build Rojo en CI.
- [ ] Tester dans Roblox sur Android les bouffées proches sous BALANCED/QUALITY et la disparition instantanée en ECO, la fluidité perçue de la fumée à 30 Hz, le streaming des ventilations, puis comparer FPS et percentiles P95/P99 en combat avec quatre bots. La CI ne mesure pas le temps GPU.
