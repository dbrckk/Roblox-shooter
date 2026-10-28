# NEON STRIKE — références, ressources et choix techniques
Date de recherche: 28 octobre 2026

## FPS de référence

**RIVALS**, Nosniy Games: référence principale pour duels courts, règles immédiatement compréhensibles, 1v1–5v5, progression des armes et skins. Source publique: https://www.roblox.com/spotlight/first-person-shooters ; statistiques indicatives: https://bloxg.com/games/rivals.

**Hypershot**: sensation d'action fluide et équipements très lisibles.
**Arsenal**: variété d'armes et boucle de match rapide.

Il s'agit de références comportementales et ergonomiques. Ne pas copier les modèles, cartes, textures, effets, musiques, scripts, UI ni marques sans permission.

## Base légale / technique

**lukas-mikalainis/roblox-precision-framework**: projet jouable Luau + Rojo sous MIT. Intégré avec copyright et texte de licence conservés. Contient contrôleur d'armes, serveur de dégâts, mouvement, HUD et cibles. README source: https://github.com/lukas-mikalainis/roblox-precision-framework

L'architecture retenue conserve les trois dossiers `src/server`, `src/client`, `src/shared` pour accueillir plus tard le matchmaking, les assets et l'expérience réseau.

## REA (morluto/rea)

REA = **Reverse Engineer Anything**: https://github.com/morluto/rea. Licence MIT; permet d'enquêter sur des logiciels autorisés via un agent. **Ce n'est pas un extracteur garanti d'expériences Roblox**: la prise en charge de bytecode Luau, des fichiers .rbxl et des graphes d'Instances est encore proposée comme fonctionnalité à développer (issue officielle #3692, ouverte le 14 octobre 2026): https://github.com/morluto/rea/issues/3692.

Il n'a pas été exécuté ni installé pour importer RIVALS; ne pas utiliser REA pour extraire une expérience tierce sans autorisation. Sur notre propre jeu, préférer instrumentation Roblox Studio et inspection directe du code source.

## Outils du catalogue star-list

- https://github.com/Astrablox/astrablox (MIT): flux de modélisation Blender et import Roblox Studio, workflow à auditer avant installation.
- https://github.com/Chrrxs/robloxstudio-mcp : connexion agent -> Studio (compatibilité, sécurité et droits à vérifier).
- https://github.com/TabooHarmony/roblox-brain : assistance Luau/Studio; vérifier la dernière version.
- https://github.com/S4US/Roqer : agent Studio et tests, sous AGPL-3.0-or-later dans sa branche courante; ne pas intégrer son code de manière irréfléchie.
- https://huggingface.co/datasets/scenario-labs/3d-collection : pistes d'assets sous CC BY 4.0 nécessitant attributions individuelles et vérification de provenance, optimisation LOD et polycounts.

## Direction visuelle cible

Science-fiction tactique stylisée, palette acier ardoise / cyan / ambre, silhouettes facilement reconnaissables, contraste propre à la vue FPS. Assets originaux: coffres, passerelles, bâtiments, containers, armes, mains/bras, accessoires, effets. Modèles externes et textures uniquement avec droits établis.

## Garde-fous pour publication

- Autorité serveur, anti-spam remotes, sécurité des achats, sauvegardes.
- Android 30/60 FPS ciblés selon appareils, pas d'assets trop lourds.
- Validation visuelle, de la visée, des tirs, de la réplication et du playtest multijoueur dans Roblox Studio.
- Consentement/licence pour chaque élément tiers. Historique des sources et attributions.
