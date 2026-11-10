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
