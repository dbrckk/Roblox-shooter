# Prompt de travail — Amener IRON YARD au niveau de qualité de RIVALS

Agis comme responsable produit et développeur Roblox d’IRON YARD. Continue le jeu existant à chaque « go » ou « continue ». Prends RIVALS, le FPS de Nosniy Games, comme référence pour la clarté du parcours, la réactivité du combat et l’envie de rejouer. La présentation officielle décrit des duels de 1v1 à 5v5 au premier à cinq, des récompenses à débloquer et une prise en charge de plusieurs appareils. Garde l’identité du terminal de fret, les mécaniques propres à IRON YARD et des assets originaux ou sous licence vérifiée. [RIVALS sur Roblox](https://www.roblox.com/games/17625359962/RIVALS)

## Partir de la version qui fonctionne

1. Vérifie le dépôt, les modifications locales, le dernier commit de `main`, le build Rojo et la dernière publication Roblox. Lis le code des parcours concernés. Les anciens audits reflètent leur date de rédaction.
2. Utilise la [validation de la version 97](#validation-de-la-version-97-et-prochains-lots) comme point de départ. Le jeu inclut le FFA, le 1v1 dans une instance réservée, les invitations, la revanche, le retour en FFA, cinq armes et la progression persistante. La CI couvre les demandes de duel reçues en retard et les régressions sur les commandes tactiles. [Transitions 1v1](MATCH_TRANSITIONS.md)
3. Exécute un lot cohérent par intervention. Corrige d’abord tout blocage dans le parcours normal. Favorise ensuite fiabilité, équité, maintenabilité, performances et finition. Appuie-toi sur la feuille de route active pour les détails techniques et la séquence des lots. [Feuille de route V3](ROADMAP_V3_SANS_TEST_ANDROID.md)

## Ordre des chantiers et critères de livraison

| Chantier | Travail attendu | Preuve demandée |
| --- | --- | --- |
| P0 · Première partie | Un nouveau joueur comprend le mode courant, trouve le 1v1 depuis le FFA et peut chercher, annuler ou répondre à une invitation tout en comprenant la raison d’un échec. Présente les commandes adaptées au clavier, au tactile ou à la manette. | Exécuter le parcours depuis une session neuve. Vérifier les phases, le changement de mode, les commandes visibles et l’absence de chevauchement sur petit écran. Cible de conception : deux actions au plus pour lancer la recherche depuis le HUD, délai de matchmaking mesuré à part. |
| P0 · Intégrité du 1v1 | Consolider le parcours de bout en bout : choix, transfert, attente de l’adversaire, premier à cinq, forfait, revanche et retour. Garder l’autorité serveur sur le score, les dégâts, les récompenses et les transitions. | Vérifier avec deux clients et un troisième joueur restant en FFA. Couvrir arrivée tardive, départ en préparation, départ en manche, retour échoué, reconnexion et progression. |
| P1 · Sensations de combat | Affiner une arme ou une interaction à la fois. Travailler la cohérence du réticule, du recul, du son, des impacts et du rechargement. Garder les silhouettes lisibles et limiter les effets qui couvrent la cible. | Comparer la même séquence avant/après à plusieurs distances, en mouvement et derrière une couverture. Distinguer tir local, hit confirmé par le serveur, et temps réel de confirmation. |
| P1 · Arène et mobile | Renforcer les repères du terminal, la lisibilité des angles et des voies, les spawns et l’éclairage. Conserver des commandes utilisables sur petit écran et une qualité graphique adaptée au téléphone de référence. | Captures Android/PC aux mêmes positions. Comparer P95/P99 du temps d’image, pics de latence et coût des effets sur la même scène. Publier les mesures avec l’appareil, le profil graphique et le nombre de joueurs. |
| P2 · Progression et rejouabilité | Rendre le prochain objectif visible, puis ajouter une récompense cosmétique obtenue en jouant. Étendre le contenu seulement quand les parcours existants sont fiables. Les choix compétitifs doivent rester accessibles par le jeu. | Vérifier attribution unique, sauvegarde, reconnexion et échec temporaire de stockage. Expliquer où le joueur voit la récompense et comment il l’équipe. |
| P3 · Variété compétitive | Étudier une deuxième arène et le 2v2 après validation du 1v1. Estimer l’impact sur le temps d’attente avant d’ajouter des files, du classé ou de plus grandes équipes. | Prouver la qualité des spawns, l’équilibre des routes, le remplissage des parties et le retour au lobby dans chaque format. |

## Exécuter et rendre compte

- Reproduis le problème et note le comportement de départ. Modifie le parcours réel et réutilise son architecture. Réserve le nouveau contenu aux changements utilisables, avec les assets et leurs preuves de chargement quand le chantier en dépend.
- Vérifie chaque scénario corrigé, les régressions proches, les contrats existants, la compilation Luau et le build Rojo. Vérifie les états réseau, les réponses en retard, le spam et la reconnexion quand ils concernent le lot.
- Utilise la CI pour la logique et l’intégration. Pour le rendu, la latence, la sensation de tir, la téléportation et la persistance, distingue explicitement simulation, essai Studio et vérification Roblox en conditions réelles. Garde les objectifs chiffrés comme objectifs tant qu’ils ne sont pas mesurés.
- Termine par le résultat visible pour le joueur, la preuve avant/après, les fichiers et la PR, puis les vérifications qui restent. Une fusion sur `main` prépare une version. Une demande distincte de mise à jour déclenche le circuit de publication publique existant avec CI du commit exact.
- Ajoute une courte entrée de suivi à un changement de priorité ou à la clôture d’un chantier. Au prochain « continue », reprends la première vérification ou amélioration utile qui manque.

## Validation de la version 97 et prochains lots

### Bilan du 18 novembre 2026

- **Publication confirmée.** Roblox a accepté la version de place 97 issue du commit `535ce0ec7ed79d54f23d15161c62379a63f14b3f`. Le workflow a contrôlé le propriétaire, l’univers, la place publique et la CI du commit exact. [Journal de publication](https://github.com/dbrckk/Roblox-shooter/actions/runs/44283980844)
- **Vérifications reproductibles terminées.** Compilation Luau, 149 commandes de test et de contrôle, et build Rojo réussis sur la source publiée. Les suites incluent les phases FFA et 1v1, les sauvegardes simulées, le combat, les spawns, les bots, les assets et les commandes tactiles. [CI du commit publié](https://github.com/dbrckk/Roblox-shooter/actions/runs/44283884563)
- **Retour en partie.** Le joueur confirme que le correctif tactile fonctionne. La couverture géométrique des trois tailles de commandes et les séquences de maintien, relâchement et annulation du saut–boost sont vérifiées en simulation.
- **Mesures encore ouvertes.** Transfert 1v1 avec deux clients, retour en FFA, persistance après reconnexion, FPS et temps d’image Android, rendu et chargement des assets PBR en jeu.

### Ordre de travail

| Priorité | Amélioration | Critère de livraison |
| --- | --- | --- |
| 1 | **Fiabiliser le parcours 1v1 public.** Rejouer recherche et invitation, transfert, départ de l’adversaire, revanche et retour en FFA. Réutiliser les délais et reprises de `DuelRoom` pour corriger les défauts observés. | Deux volontaires se retrouvent dans la même instance réservée, un troisième joueur reste en FFA et chaque échec permet de reprendre le jeu. Relever le build dans les résultats. [Scénarios réseau](MATCH_TRANSITIONS.md) |
| 2 | **Guider la première minute.** Faire évoluer le briefing de `FirstMatchGuide` selon les actions réalisées. Afficher l’objectif, l’action suivante et la touche adaptée au périphérique. | Un nouveau joueur trouve le tir, le rechargement et le 1v1. Les conseils cessent après l’action et restent hors des commandes et des écrans de duel. |
| 3 | **Polir les sensations de l’AR-24.** Comparer le premier tir et la rafale en mouvement et près d’une couverture. Accorder recul, retour sonore et confirmations de touche à leur événement réel. | Les retours restent lisibles pendant une rafale et près des couvertures. Les vidéos avant/après montrent le même scénario. Les dégâts et la cadence restent contrôlés par le serveur. [Référence de combat](RIVALS_QUALITY_BENCHMARK.md) |
| 4 | **Améliorer le rendu et la fluidité Android.** Relever avec `PERF` les sources des modèles, les temps d’image et les pics pendant un combat à quatre bots puis une traversée du terminal. Prioriser la silhouette, les repères de trajet ou le pire pic mesuré selon les résultats. | Comparaison ECO/BALANCED/QUALITY sur le même appareil, avec captures des armes, de VANGUARD et des surfaces PBR. Comparer le P95 et le P99 sans modifier les colliders de jeu. [Audit visuel Android](AUDIT_ANDROID_VISUAL_2026-11-13.md) |
| 5 | **Rendre la progression plus lisible.** Vérifier la sauvegarde et la récupération de l’XP en rejoignant une nouvelle session, puis afficher le prochain déblocage cosmétique dans le parcours de carrière existant. | Les gains restent visibles après reconnexion, une erreur de sauvegarde est identifiable et la récompense est attribuée une seule fois. [Persistance](PROGRESSION_PERSISTENCE.md) |

Au prochain lot, commencer par le parcours 1v1. En l’absence de deux clients Roblox, poursuivre avec l’amélioration du briefing et conserver le scénario 1v1 comme vérification en partie.

**Lot 2 publié en version 98.** Le briefing FFA guide le premier tir, le rechargement et l’accès au 1v1. L’indication suit le clavier, le tactile ou la manette, et le rechargement accepté par le serveur retire le conseil correspondant. Les simulations couvrent les actions anticipées, le changement de périphérique, les menus et le passage en duel. Vérifier ensuite l’enchaînement en jeu sur petit écran. [Publication de la version 98](https://github.com/dbrckk/Roblox-shooter/actions/runs/44287293265)

**Lot 3 publié en version 99.** L’AR‑24 distingue le premier tir après 380 ms de pause des tirs suivants. Le réticule peut réagir dès l’image suivante, et l’inclinaison du modèle ainsi que le volume local sont atténués en rafale. Comparer en jeu le tir isolé et la rafale à l’arrêt, en déplacement et près d’une couverture. Les confirmations de touche proviennent toujours du serveur. [Publication de la version 99](https://github.com/dbrckk/Roblox-shooter/actions/runs/44289437185)

**Lot 4 publié en version 100.** Le client répartit les mises à jour du décor PBR sur plusieurs images et lit le dernier profil graphique au moment d’appliquer chaque variante. En simulation, un lot de 144 surfaces passe de 144 applications immédiates à un maximum de 12 par image sur mobile. Trois événements de matériau consécutifs passent de 432 recherches de variante à 36. Vérifier dans `PERF` la couverture des matériaux et les temps d’image sur Android, pendant une traversée puis après une bascule ECO/BALANCED/QUALITY. [Publication de la version 100](https://github.com/dbrckk/Roblox-shooter/actions/runs/44291604676)

**Captures PERF publiées en version 101.** Le panneau propriétaire enregistre des captures de 240 images distinctes par profil et pour la dernière bascule. Le panneau se masque pendant la collecte pour éviter ses recalculs dans les échantillons. [Publication de la version 101](https://github.com/dbrckk/Roblox-shooter/actions/runs/44293393361) · [Protocole Android](WORLD_PBR_ROOF_ANDROID_QA_2026-11-13.md#comparer-les-temps-dimage-sur-android)

**Avancement du lot 5.** La carrière et les résultats affichent la prochaine finition et les XP restants. Les tests comparent les quatre paliers au calcul du rang côté serveur et couvrent l’arrivée des XP avant le rang. La reconnexion à un serveur Roblox réel reste à tester. [Progression persistante](PROGRESSION_PERSISTENCE.md#prochain-déblocage-cosmétique)

## Première application

Corriger la première impression du 1v1. Le briefing FFA utilise le même bandeau que le score et peut brièvement afficher un objectif FFA en plein duel, tandis que le bouton 1v1 disparaît pendant le briefing du lobby. Garder l’accès au 1v1 visible pendant les conseils FFA, suspendre les conseils quand le menu 1v1 est ouvert et préserver le score et la préparation en duel. Vérifier aussi que les conseils différés d’une ancienne manche ne réapparaissent pas dans le duel suivant.

**Suivi du lot.** Les simulations Luau vérifient l’accès au menu pendant le briefing, le passage FFA → duel dans la même phase, le démarrage d’un duel réservé, les conseils retardés et la priorité de la manette sur le tactile. Les 148 vérifications existantes et le build Rojo passent. La prochaine vérification prioritaire est une session neuve sur Android, suivie d’un 1v1 à deux clients depuis le lobby jusqu’à la revanche ou au retour en FFA.

**Suite du lot P0.** Le 1v1 est accessible à la manette avec R3. Les simulations Luau couvrent la sélection de l’invitation et son expiration, le changement de périphérique, la reprise après le menu système, la revanche et le retour en FFA. La compilation, les 148 vérifications et le build Rojo passent. La validation sur deux clients Roblox inclut désormais le parcours complet avec une manette Bluetooth et le passage du tactile à la manette.

**Retour immédiat sur la recherche.** Le HUD montre l’envoi ou l’annulation sans attendre la réplication. Les actions de matchmaking sont temporairement indisponibles, puis un réessai est proposé au bout de trois secondes sans confirmation. Les simulations couvrent les appuis répétés, la sélection manette, le délai dépassé, la confirmation tardive et le départ vers le duel.

**Réponse aux invitations.** Le même retour immédiat couvre l’acceptation et le refus. Les simulations vérifient les appuis répétés, l’expiration, le passage à l’invitation suivante et le début du transfert. La prochaine validation en partie doit vérifier ces états avec deux clients Roblox et une connexion lente.

**Validation réseau reproductible.** La CI exécute le HUD et le matchmaking du jeu avec deux clients simulés. Elle vérifie la confirmation après le seuil de trois secondes, l’arrivée tardive d’une réponse à une invitation expirée, le refus pendant une recherche et la réservation commune après acceptation. Pour valider le transfert réel, il reste à rejoindre la même FFA avec deux comptes Roblox, inviter, accepter, vérifier que les deux joueurs arrivent dans la même salle, puis tester la revanche et le retour en FFA. Relever le build affiché pour rattacher le résultat à la version testée.

**Échéance de revanche.** Le serveur ferme les votes à l’échéance des résultats. La simulation couvre le vote à la limite, les deux votes reçus à temps et une annulation reçue avant ou après l’échéance. Le test Roblox reste à faire.

**Retour en FFA après les résultats.** Le serveur vérifie la phase et la série affichées au moment de la demande. La simulation utilise le bouton des résultats et le vrai serveur de match pour couvrir un retour qui arrive pendant la revanche, un retour issu de la série précédente et un retour accepté depuis les résultats courants.

**Confirmation des tirs.** Les touches, tirs à la tête et éliminations ont des marqueurs à centre ouvert, différenciés par leur forme et leur signal sonore. Une confirmation prioritaire reste visible pendant sa durée minimale, même sous un tir soutenu. Les marqueurs et le son sont réutilisés par le HUD. Vérifier leur lisibilité en visée et le niveau sonore sur Android et PC, en tir isolé et en rafale.

**Changements de manche.** Les confirmations de touche et de bouclier suivent la génération de combat du serveur. À la prochaine manche ou reprise du 1v1, le HUD efface les anciens marqueurs et coupe leur son. La CI couvre l’ordre variable des confirmations, des mises à jour de munitions et de la réplication de la génération.

**Réglage sonore.** Le menu propose trois niveaux pour les sons de confirmation, de la coupure complète au volume standard. Les marqueurs et le texte restent visibles au niveau OFF. Vérifier le réglage au tactile et à la manette, ainsi que le niveau LOW pendant une rafale.

**Réduction des mouvements.** Le réglage Roblox désactive l’inclinaison et l’élargissement du champ de vision liés aux déplacements, le flash de dégâts plein écran et la pulsation des marqueurs. La visée, la direction des dégâts, le texte et les sons de confirmation restent disponibles. Vérifier la bascule en partie sur Android et PC, en déplacement et en visée.

**Entrées de combat et menu Roblox.** À l’ouverture du menu, les commandes maintenues sont relâchées et les commandes tactiles sont masquées. Après fermeture, tirer ou reprendre le boost demande une nouvelle pression. La CI simule les événements du menu, la perte de focus, le clavier et la manette.

**Direction des dégâts.** Le chevron contouré suit l’origine du dernier impact pendant que la caméra tourne. Son angle reste calculé à l’horizontale, y compris en visée haute ou basse. Le mode de mouvement réduit conserve un chevron fixe en opacité jusqu’à sa disparition. Vérifier sa lisibilité sur fond clair et sombre dans l’arène.

**Votes de revanche.** Le serveur accepte un vote ou son annulation uniquement depuis les résultats de la série en cours. La simulation rejoue les actions des deux joueurs et vérifie qu’un ancien écran ne peut ni compter un vote ni annuler un choix de la nouvelle série.

**Confirmation de la revanche.** Le bouton indique immédiatement l’envoi d’un vote ou d’une annulation. Les appuis répétés pendant l’attente ne renvoient pas l’action et la manette garde sa sélection. Le bouton accepte un réessai après trois secondes sans confirmation. La simulation vérifie également qu’un troisième joueur reste en FFA et qu’un retour échoué peut être relancé après le réessai automatique.
