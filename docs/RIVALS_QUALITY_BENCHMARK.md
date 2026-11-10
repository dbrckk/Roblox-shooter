# IRON YARD — Benchmark qualité RIVALS / trajectoire du jeu

Date : 10 novembre 2026. Référence de produit, pas une copie de contenus ou de code propriétaires.
Source publique : https://www.roblox.com/games/17625359962/RIVALS

## Qualité recherchée et ordre des travaux

La cible est la **qualité ressentie** de RIVALS : tirs exacts, faible délai perçu, silhouette lisible,
déplacements maîtrisables, explications courtes, manches rejouables, interface utilisable sur téléphone.
Le mode actuel d'IRON YARD est **FFA à 15 éliminations** : il n'est pas présenté comme un duel RIVALS.

1. **Intégrité et précision des tirs** : réconcilier l'axe de caméra avec le rayon partant de la tête.
   Conserver les dégâts, collisions, cadence, munitions et cibles exclusivement côté serveur.
2. **Feedback d'armes** : comparer recul ressenti, impacts, sons différenciés, latence de confirmation,
   compréhension des ratés et headshots sans surcharge visuelle Android.
3. **Assets réellement visibles** : activer les meshes VANGUARD et matériaux PBR déjà créés (IDs Roblox
   autorisés), sans annoncer les assets comme intégrés tant que les ID sont à zéro.
4. **Lisibilité et optimisation** : refaire les essais au combat sur Android/PC avec P95/P99, collisions,
   sprint/slide/wallrun, transitions d'arme, spawn et quatre bots.
5. **Duel original 1v1** : après la stabilisation du FFA, livrer un mode séparé et complet, manches
   premier à cinq, adversaire humain, abandon/rematch, résultats autoritaires; étendre ensuite 2v2–5v5.

## Itération livrée dans le code — convergence camera/head

Les armes à rayons, le shotgun et le couteau conservent **leur origine du tir dans la tête serveur**.
Un point de visée acquis par un raycast serveur depuis l'origine caméra annoncée peut seulement orienter
le tir de la tête vers la surface réellement visée. L'origine caméra est optionnelle, limitée à un offset
de 4,5 studs, et vérifiée non masquée depuis la tête. Aucun résultat de touche envoyé par le client
n'est accepté. Un offset excessif, une caméra bloquée ou un angle incohérent entraîne un repli vers
l'ancien rayon partant de la tête : pas de rejet injuste des tirs en cas de retard réseau.

Cette convergence effectue au plus deux raycasts serveur supplémentaires par tir dont la caméra est
admissible. Elle réutilise le filtre du personnage déjà mis en cache. Pas de dépendance ni d'asset payant.

## Critères de validation dans Roblox Studio (non testables par la CI)

- Tirer au pistolet puis au fusil sur une petite cible à 5, 15 et 50 studs ; comparer l'alignement
  du réticule, le serveur et les impacts visuels avant/après, à l'arrêt et en strafe.
- Tirer contre un conteneur depuis une position collée puis en sortie de couverture : aucun hit
  à travers l'obstacle même si la caméra a momentanément vue sur la cible.
- Exécuter sniper/shotgun/couteau, rechargements, respawns, bots et 100 coups automatiques
  (avec latence simulée si possible) : aucune anomalie de munitions, de cadence ou de killfeed.
- Avec MicroProfiler, mesurer le coût ajouté de 1–2 raycasts pour chaque tir convergé.
- Vérifier les inputs PC et Android, y compris une caméra rapidement déplacée, une pente,
  un wallrun et un joueur derrière une couverture.

La CI compile les modules, vérifie la politique mathématique et les contrats d'intégration.
Elle ne remplace ni le test moteur ni les mesures de FPS/latence.


## Itération suivante — animation des douilles + budget de visée (10 novembre 2026)

- Quatre armes à feu éjectent des douilles métalliques purement locales et originales :
  fusil automatique, pistolet, fusil à pompe (après pompe), sniper (après verrou).
  Le couteau n'éjecte rien. Les modèles existants fournissent le point d'origine
  (EjectionPort, Receiver ou Bolt) sans nouveau mesh externe ni asset payant.
- Trajectoire courte avec élévation puis retombée et rotation, sans collision :
  le pool VFX existant anime les douilles puis les recycle, sans nouveau RenderStepped,
  appel réseau, Tween ou Debris. Les douilles ont priorité 1 (elles cèdent aux impacts
  et flashs), sont désactivées en ECO et sont échantillonnées à une sur deux pour
  l'AR-24 sur Android BALANCED. Les autres armes restent visibles.
- Les transitions d'arme annulent toute douille retardée (pompe/verrou), et les effets
  recyclés réinitialisent les paramètres d'arc/rotation.
- Correction performance : la convergence de caméra issue de l'itération précédente
  se calcule désormais uniquement **après** admission par les cooldowns/munitions serveur.
  Les tirs refusés n'ajoutent aucun raycast.
- Validation automatique : tests Luau (quatre armes, admission 18 000 tirs simulés,
  limites Android et courbe), compilation, contrat d'intégration et build Rojo.
- **À vérifier en moteur** : cadrage réel des douilles sur Android/PC, cohérence du
  temps d'éjection du shotgun/sniper, comportement sous changement d'arme rapide
  et coûts FPS sur 100 tirs continus. Les sons restent provisoires et ne sont
  pas revendiqués de niveau RIVALS tant que des échantillons originaux licenciés
  ne sont pas disponibles.


## Audio : distance et couverture (10 novembre 2026)

Les tirs à proximité conservent leurs deux couches sonores et leur spectre complet.
Les tirs lointains conservent la limite de distance/voix existante, mais atténuent
désormais les fréquences hautes (EQ -10 dB) et médianes (-3 dB).
Un mur ou conteneur réellement solide, vérifié par le raycast audio local déjà
existant, ajoute un filtrage plus prononcé (-24 dB haut, -12 dB médium, -1 dB bas),
en complément du mix de volume à 40 % et du mode monocouche.
Ce filtre est un EqualizerSoundEffect Roblox attaché uniquement aux sons qui en
ont besoin : aucun nouveau raycast, aucun nouveau réseau, ni effet EQ pour le
tireur local et les coups proches non masqués. Le cap de voix reste identique.
Les tests Luau contrôlent les valeurs; la qualité perçue doit être comparée en
Studio avec une source proche, derrière un conteneur et à plus de 100 studs.
Les sources audio intégrées demeurent provisoires, sans promesse d'échantillons AAA.


## ADS et visuel natif, 10 novembre 2026

Le jeu possède toujours les 4 IDs VANGUARD et les 12 IDs PBR à zéro :
leurs vrais meshes/textures n'ont donc **pas été activés** dans Roblox par ce lot.

- Correction d'un défaut de transition : un changement d'arme quitte toujours
  l'ancienne visée avant d'équiper la nouvelle. Le sniper ne récupère plus
  le FOV du pistolet ou du shotgun en cas de switch pendant ADS.
- Les positions visées du pistolet, AR-24 et shotgun sont centrées sur
  leurs mires arrière existantes ou ajoutées, au lieu d'un décalage global
  identique pour toutes les armes. L'ADS réduit sway/bob mais garde recul.
- Le fusil à pompe possède désormais une mire arrière; le tube du sniper
  et sa lentille sont cylindriques avec tourelles latérales dédiées.
- Mêmes hitboxes, munitions et logique de tir. Pas de raycast ni audio ajoutés
  à RenderStepped. Les nouvelles pièces sont strictement cosmétiques.
- La CI compile et teste la géométrie numérique, mais ne valide pas
  encore visuellement le centrage sur Android ou PC.


## Lunette sniper graduée et responsive (10 novembre 2026)

- Révision de la lunette : quatre lignes séparées, point central, graduations latérales et verticales, sans promettre de compensation balistique calibrée.
- Taille adaptative (ratio hauteur, 150–350 px), voile périphérique réduit pour distinguer les cibles sur téléphone Android; aucun effet sur les raycasts de combat ou les hitboxes.
- Confirmations de touches, dégâts et éliminations au-dessus des traits optiques. Tous les éléments sont alloués une seule fois et restent cachés hors ADS sniper.
- Contrôle d'intégration ajouté à la suite Python du build Rojo; rendu en moteur encore à vérifier.


## Réticule dynamique de combat et point ADS (10 novembre 2026)

La mire de tir sans zoom réagit désormais visuellement aux coups tirés, à la marche et au sprint. Chaque arme a sa propre ouverture de base et impulsion, avec récupération exponentielle. Cette ouverture ne reflète pas la dispersion réelle du serveur : il s'agit uniquement d'une indication de mouvement/recul.

Les quatre segments sont repositionnés seulement quand leur rayon arrondi change (et pas plus souvent que toutes les 45 ms), via le RenderStepped existant. Aucun Tween ni nouvel événement réseau. En ADS, les quatre barres laissent place à un point central discret et cerclé ; le sniper conserve sa lunette. Les tests Luau simulent 3 600 images et cinq armes, puis la CI vérifie le câblage.

À vérifier en moteur : emplacement du point ADS avec les mires, comportement sur très petits écrans, lisibilité dans les hautes lumières et absence de gêne dans les duels. Aucune métrique FPS réelle n'est affirmée.


## Robustesse caméra / respawn / ADS — 10 novembre 2026

- Correction : le FOV de la caméra remplacée par Roblox reprend maintenant
  systématiquement la valeur de la visée du **vrai équipement actif**.
  Une nouvelle caméra pendant le zoom sniper ne rétablit plus le FOV standard.
- Correction : chaque réapparition annule l'état ADS précédent, même si le joueur
  rééquipe la même arme. Le HUD, la lunette et le zoom ne peuvent plus persister
  après une mort ou un respawn.
- Correction : absence temporaire de Workspace.CurrentCamera n'empêche plus la
  remise à zéro de l'état local, du HUD et du viewmodel.
- Politique client pure testée : 1 2000-samples simulated camera rebind, changement
  des valeurs de FOV, données invalides et équipement sans visée. Aucun impact
  sur les raycasts serveur, les dégâts, la cadence ou le réseau.
- À contrôler dans le moteur Roblox : se faire éliminer pendant l'ADS sniper
  et pistolet, réapparaître, changer de caméra et d'arme, vérifier le FOV
  et le réticule sur Android et PC.


## Précision compétitive : premier tir et rafales (10 novembre 2026)

Un défaut identifié dans le combat : les tirs du fusil AR-24 utilisaient
toujours le même cône de 1,1°, même après une pause. À longue distance,
cela rendait le premier tir aléatoirement imprécis. Correction côté serveur :
le premier tir AR-24 utilise un cône de 0,17°, puis les tirs successifs
élargissent le cône de 0,23° par coup jusqu'à la limite préexistante
de 1,1°. Une pause d'au moins 0,38 s réinitialise la précision.

Le fusil à pompe conserve sa dispersion fixe de huit plombs et les trois
autres armes leurs réglages existants (pistolet et sniper à 0°).
Le serveur gère seul cadence, timestamp, nombre de tirs de la rafale,
dispersion et dégâts. Les tirs rejetés n'augmentent pas le bloom. Une mort
ou une nouvelle manche réinitialise le compteur; changer d'arme pendant une
rafale ne falsifie pas les délais de tir. Aucun nouveau remote, aucun
raycast ni instance; le réticule client reste indicatif, pas une promesse
sur le point exact d'impact du RNG côté serveur.

Tests Luau : premier tir, sixième tir, pause, changement de cadence, armes
non concernées, horloge/paramètres invalides, 50 000 coups simulés;
contrat Python vérifiant le chemin d'admission puis le raycast.
Validation en moteur restante : 50, 100, 200 studs sur cible,
tir par tap-fire vs automatique, recul ressenti et latence Android/PC.


## ADS server-side validé — 10 novembre 2026

La visée n'est plus seulement un zoom local : un événement dédié SetAiming
(10 par seconde, capacité 8) annonce l'intention de viser. Le serveur enregistre
l'arme et le personnage, puis ne valide le bonus qu'après 140 ms de visée.
Le client ne décide jamais des dégâts, du cône, du temps ou de la cible.
Le bonus est suspendu lorsque le serveur constate sprint, glissade, wallrun,
boost, saut ou vitesse horizontale supérieure à 23 studs/s.

- AR-24 : cône réduit de 30 % par rapport au bloom de rafale serveur.
- Shotgun B-8 : cône des huit plombs réduit de 14 %.
- Pistolet et sniper (0 dispersion) : réglages inchangés; couteau non concerné.
- Réinitialisation à la désactivation, au changement d'arme, au respawn et
  au démarrage de manche. Une visée conservée pendant le countdown est
  réannoncée côté client lorsque la manche passe en LIVE.
- Le sprint volontaire annule la visée locale. Toutes les réductions sont
  calculées uniquement après admission du tir, sans raycast ou boucle ajoutés.
- Tests : 40 000 tirs de simulation, paramètres invalides, mobilité, délais,
  limites de fréquence, et contrats client-serveur.

Essais restant à effectuer dans Studio puis Android : tir rafale et contrôlé,
ADS après sprint, saut, réapparition et changement d'arme; vérifier la
latence ressentie et la précision à moyenne et longue portée.


## Mode duel 1v1 — première version intégrée (10 novembre 2026)

**Mode volontaire et jouable** : deux utilisateurs connectés sur un même
serveur appuient chacun sur « JOIN 1v1 DUEL ». Si les deux sont prêts au
démarrage du prochain match, le serveur choisit DUEL au lieu de FFA.
Le FFA avec bots reste la valeur par défaut; aucun duel automatique
n'interrompt les joueurs qui ne l'ont pas choisi.

- Manches séparées de 80 s, victoire du duel au premier à cinq manches.
  Une mort clôt la manche; double KO = égalité. À la fin du temps,
  le pourcentage de vie détermine le gagnant, égalité si identique.
  Après 24 manches sans vainqueur à cinq, la série est nulle.
- Réapparitions réelles et téléportation sur deux points opposés, inversion
  des côtés à chaque manche. Pause de 7 s (prolongée si le personnage n'a
  pas encore respawn), restauration de la vie, des chargeurs et des états
  serveur avant chaque reprise. Aucune manche à sens unique lancée avant
  que les deux Humanoids soient disponibles.
- Les quatre bots sont retirés immédiatement; les nouveaux sont empêchés
  de naître pendant le duel. Un combattant extérieur ne peut pas tirer ni
  subir des dégâts des deux participants.
- L'arrivée d'un troisième joueur annule la série sans offrir de fausse
  victoire; un départ de l'un des deux constitue un forfait.
- Le mode et les scores sont publiés par le serveur; le bandeau et l'écran
  de résultats affichent les manches gagnées, pas des éliminations fictives.
  Les joueurs peuvent préparer une revanche au prochain cycle de match.
- Le matchmaking entre serveurs **n'est pas fourni** : seuls deux joueurs
  réunis dans la même instance peuvent lancer cette première version.
  Les tests de logique et le build Rojo ne remplacent pas un essai Roblox
  sur deux vrais clients.


## 1v1 : anti-blocage des manches et fair-play (10 novembre 2026)

Le mode duel ne doit plus tomber sur les points de spawn FFA ou tourner
indéfiniment pendant les pauses :

- **Points opposés prévalidés ensemble** : six paires d'emplacements séparés,
  avec alternance A/B des côtés d'une manche à l'autre. Avant de déplacer
  le premier joueur, le serveur vérifie les douze points contre la géométrie
  solide tout en ignorant les deux avatars transitoires. Si aucune paire
  sûre n'existe, la manche ne démarre pas (pas de spawn FFA aléatoire).
  Une simulation Luau explore 4096 masques de collision x 8 manches.
- **Attente bornée à 20 secondes** : en cas de réapparition manquante ou de
  géométrie obstruant tous les points, le serveur termine la série avec
  le motif SPAWN_TIMEOUT sans déclarer de faux vainqueur ni laisser le
  serveur en pause permanente.
- **Consentement renouvelé** : les deux demandes « JOIN 1v1 DUEL »
  sont consommées au début de la série. Pour jouer une revanche, les
  deux joueurs doivent choisir de nouveau. Les requêtes adverses de
  préparation ne peuvent pas être activées en plein duel ou dans un
  serveur de plus de deux joueurs.
- **Équité** : les stations médicales sont désactivées pendant les 1v1,
  et leur prompt l'indique. Les forfaits, interruptions de lobby et
  erreurs de respawn ne créditent pas une victoire XP gratuite ; une
  vraie victoire à cinq manches reste récompensée.
- Les tests en CI vérifient les limites de temps, la sélection physique,
  la non-répétition des consentements, les remotes et l'attribution.
  Essais Roblox à deux vrais joueurs toujours nécessaires.


## Intro synchronisée 1v1 — préparation et départ équitable (10 novembre 2026)

Les points de départ sont maintenant suivis d'une séquence **DUEL_PREP**
de **3 secondes** avant chaque manche. Le serveur immobilise les deux
personnages, invalide les anciennes glissades/boosts et remet leurs
vitesses à zéro. Les commandes de mouvement offensives sont ignorées
pendant la préparation (les commandes d'arrêt restent permises).
La cadence des tirs et les dégâts restent désactivés, car seules les
manches LIVE autorisent le tir.

À la fin de la préparation, le serveur vérifie que les deux avatars
sont exactement ceux placés au départ et qu'ils sont vivants :
- Cas valide : les racines sont déverrouillées, les boucliers de spawn
  sont retirés au même tick, les armes réinitialisées, la manche devient LIVE.
- Respawn intervenu pendant le countdown : déverrouillage des anciennes
  références, retour à DUEL_BREAK et réessai dans le délai global borné.
- Lobby modifié : sortie contrôlée sans ancrage restant.
- Le client réutilise le MatchHud existant pour afficher un panneau métal
  en dégradé avec **3 / 2 / 1**, sans RenderStepped additionnel, et le
  score des manches reste lisible dans la bannière de match.

Le nouveau panneau n'est qu'une présentation : aucune source de temps,
dégâts ou d'autorité n'a été déplacée vers le client. Les scripts doivent
être vérifiés sur deux joueurs Roblox/Android, notamment le remplacement
de personnage pendant le compte à rebours.


## Pistolet et shotgun : pièces réellement liées aux mécanismes (10 novembre 2026)

- Le pistolet possède désormais un chargeur amovible visible et un
  talon de chargeur, animés ensemble pendant le rechargement.
- La culasse du pistolet entraîne sa fenêtre d'éjection et son extracteur
  au lieu de laisser ces pièces fixes et visuellement décalées.
- La pompe du shotgun entraîne également tout le bras de soutien gauche :
  la main n'a plus l'air de flotter à travers la pièce mobile.
- Les trois mécanismes réutilisent la **seule boucle RenderStepped**
  du viewmodel. Aucun nouvel événement réseau, hitbox, objet physique
  ou changement de munitions/dégâts côté serveur.
- Les contrats statiques et la compilation sont vérifiés en CI; les
  animations doivent aussi être contrôlées visuellement dans Roblox Studio.


## Correctifs competitifs du duel : identite du combattant et boost

- Chaque manche conserve la reference exacte des deux characters Roblox
  en LIVE. Une reapparition inattendue ne donne pas une deuxieme vie
  dans la manche : la nouvelle incarnation est comptabilisee comme hors
  combat, sans ressusciter le combattant initial.
- La preparation restaure le carburant complet du boost pour chaque
  joueur et remet a zero les delais de slide/boost, en plus des vitesses.
- Tests de logique Luau sur les references, les remplacements, les
  donnees de sante invalides et controles Python sur les ressources.


## Retours de manches 1v1 cote joueur

Les manches montrent maintenant le score dans le sens du joueur local,
sous la forme YOU 2 : 3 RIVAL (plutot qu'un score A/B anonyme).

Chaque fin de manche publie un resultat serveur strictement type :
A, B ou DRAW. Le MatchHud affiche alors ROUND WON, ROUND LOST ou
ROUND DRAW selon l'identite reelle des participants, avant la
preparation suivante. Les informations sont effacees au debut de la
manche suivante et entre deux matchs. Aucune prediction locale de tir
ne peut modifier un resultat de duel.

La logique de readout possede un module Luau pur, un test executable
pour les deux perspectives et les entrées invalides, et des
verifications d'integration de MatchService/MatchHud dans la CI.


## Transition duel : spawns tardifs et interruptions bornees (10 novembre 2026)

- Un callback CharacterAdded differe ne peut plus deplacer un combattant
  deja engage en duel, ni renouveler son bouclier pendant le countdown.
  En mode DUEL, seul MatchService peut placer les joueurs.
- Les references des deux Player qui ont accepte le duel sont conservees.
  DuelRules.sameParticipants compare les instances reelles, sans
  dependance a GetPlayerByUserId pour les identites negatives Studio.
- La duree de recuperation de 20 secondes est cumulative sur toutes les
  tentatives de preparation ratees. Remplacer son Character durant 3-2-1
  ne renouvelle plus indefiniment le delai.
- La recompense de victoire est conditionnee a la presence effective du
  gagnant dans Players et utilise sa reference d'origine.
- Tests de logique Luau et contrats Python verifient les controles.


## HUD 1v1 : cinq marqueurs de victoire par camp

Le bandeau de match possède une petite jauge de dix segments :
cinq ambre pour les manches gagnées par le joueur local et
cinq bleu acier pour son adversaire. Tous les segments sont
créés une seule fois ; seuls les changements de score répliqués
par le serveur modifient leur couleur.

Le bouton JOIN 1v1 DUEL n'encombre plus l'écran lorsque le serveur
contient plus de deux joueurs ou lorsque l'introduction de partie
est ouverte. Il reste accessible pendant les FFA avec un ou deux
joueurs, et au moment de demander une revanche.

Le bandeau conserve une largeur maximale de 340 px, gagne 10 px
en hauteur pour les jauges, et n'ajoute aucune boucle RenderStepped,
requête réseau ou instance Roblox lors de chaque mise à jour.


## Effets de combat : ricochets physiques cosmetiques et confirmations fatales

- Les impacts metal, bois, verre, terre et beton utilisent desormais des
  trajectoires individuelles : chute quadratique, rotation du fragment
  et scintillement pour les etincelles. La trajectoire est calculee sur
  les Parts deja alloues par le pool de VFX, jamais par des projectiles
  physiques, des RemoteEvents supplementaires ou des Tweens par impact.
- L'etincelle metallique reste breve et vive ; les eclats de verre
  pivotent et scintillent ; bois, beton et terre tombent plus vite.
- Une elimination *confirmee par le serveur* affiche en plus une
  expansion annulaire 3D face a la camera, par recyclage du meme pool.
  Cette couronne n'apparait pas avec le preset ECO.
- Le nouveau profil purement Luau est couvert par les tests de materiaux,
  les limites de deplacement et les budgets. Le volume de Parts reste
  limite par TransientFxPool.cap (24/48/72 Android).


## B-8 shotgun : cartouches, boitier et rechargement synchronise

- Le fusil a pompe B-8 presente deux douilles de 12-gauge sur le
  porte-cartouches, chacune avec son culot dore distinct.
- Son boitier comprend desormais un port d'ejection droit et
  une trappe inferieure de chargement. Les douilles expulsees
  utilisent le port comme ancre et le moment mecanique de pompe
  existant (39 centiemes apres le tir).
- Pendant le rechargement confirme par WeaponFeedback Ammo,
  une cartouche mobile est presentee puis inseree dans le boitier.
  Elle est masquee immediatement lors de l'annulation, d'un
  changement d'arme et en preset ECO. Animation purement locale
  et cosmetique : les six munitions et la duree de 2,55 s
  restent entierement determinees par WeaponService.
- Aucun nouvel appel reseau, Part genere a chaque cartouche,
  Raycast ni boucle RenderStepped. Les 8 elements supplementaires
  du premier-personnage sont detruits/recrees seulement au changement
  de viewmodel. Un test de 10 000 positions verifie la trajectoire,
  le bornage, la visibilite et le comportement du preset ECO.


## Ecran de defaite : information adaptee au mode duel

- En FFA, le joueur conserve son compte a rebours de reapparition
  et l'indication du bouclier de spawn.
- En 1v1, un adversaire elimine ne voit plus le message trompeur
  REDEPLOY IN : le panneau indique AWAITING ROUND RESULT puis
  NEXT BOUT IN, avec le verdict serveur (manche perdue ou egalite).
- Une unique interpolation Tween de 0,26 seconde affiche le panneau.
  Le Tween est annule et le panneau est reinitialise au changement
  de Character, sans accumulation d'effets ni de boucles de frame.
- La logique texte est testable hors de Roblox et est couverte par
  une suite Luau et les contrats de branchement mobile.


## Precision des silhouettes : AR-24 et fusil de precision

- Le fusil d'assaut AR-24 possede une deflection d'ejection en WedgePart,
  un selecteur cylindrique, un bloc des gaz metallique, six ouvertures de
  ventilation et trois dents sur le rail superieur. Les visees existantes
  et les axes de tir serveur ne changent pas.
- Le fusil de precision obtient deux bagues cylindriques de lunette,
  un oculaire metallique et un vrai levier de culasse termine par
  une boule. Le levier et la boule suivent la courbe de recul mecanique
  deja utilisee par la culasse, sans nouvelle boucle d'animation.
- Toutes les formes sont uniquement locales et non collidables, adaptees
  aux couleurs de finition de l'operateur. Les details ne s'allouent
  qu'a l'equipement du viewmodel, pas aux tirs.
- Les contrats de presentation imposent le maintien d'une seule
  connexion RenderStepped et verifient les pieces ajoutees.


## Pistolet et couteau : details fins avec LOD automatique

- Le pistolet possede desormais sa deuxieme plaquette de crosse,
  sa bague de bouche cylindrique, son cache de rail et sa securite
  de detente. Les configurations plus riches revelent des vis
  de fixation et des stries arriere/avant du bloc-culasse ; toutes
  les stries suivent le vrai mouvement du slide lors du tir.
- Le couteau comporte un pommeau renforce, des plaquettes de
  prise en main, des rivets, une gorge longitudinale sur la lame
  et des encoches de dos en configuration haute qualite.
- Le module de donnees WeaponDetailPlan ajoute en mode ECO
  seulement quatre details par arme ; sur Android BALANCED dix
  details au pistolet et neuf au couteau ; en QUALITE / ordinateur
  jusqu'a quinze et quatorze. Aucun ajout de boucle RenderStepped,
  d'envoi reseau ni de physique.
- Les couleurs s'adaptent aux finitions de carriere deja acquises.
  Le niveau de detail des pieces est choisi lors de l'equipement :
  apres avoir change de preset graphique, re-equiper l'arme applique
  le nouveau niveau sans ralentir chaque frame du combat.
- Test Luau des tailles, materiaux, formes, unicite de chaque piece
  et de 25 000 consultations de plans caches ; contrat Python
  de cablage et de cycle d'animation.


## Presets graphiques en direct : LOD du pistolet et du couteau

Le joueur peut passer de ECO a BALANCED puis QUALITY au milieu
d'une manche. WeaponVisuals conserve les pieces toujours utiles,
ajoute les details desormais autorises et detruit uniquement celles
qui sont retirees en descendant de qualite. Le traitement n'a lieu
qu'au signal de changement de preset graphique, jamais par frame.
L'arme equipee, son rechargement, le recul et la visee ne sont pas
reinitialises. Les couleurs et finitions de progression sont appliquees
aux nouvelles pieces. Les listes des differentes qualites partagent
les memes definitions de pieces pour garantir leur identite.
