# IRON YARD — publication directement publique (sans étape privée)

Le dépôt **ne dispose plus de workflow de publication privée**. Il construit un artefact Roblox à chaque push et propose une **publication publique manuelle uniquement**. Le script n'active pas une expérience : il met à jour une place **déjà publique**, appartenant à l'utilisateur Roblox autorisé. Il refuse une place privée, un autre propriétaire, un autre nom de jeu ou un Place ID qui n'est pas la place de démarrage.

## Préparer la destination une seule fois

1. Dans le [Creator Dashboard](https://create.roblox.com/dashboard/creations), créer ou sélectionner l'expérience **IRON YARD** du bon compte Roblox. Régler les paramètres de contenu/maturité et la visibilité **Public** selon les critères Roblox ; le dépôt ne crée ni n'active de jeu.
2. Copier le **Universe ID** et le **Place ID de démarrage** depuis Creator Dashboard.
3. Dans GitHub, dépôt > **Settings > Secrets and variables > Actions > Variables**, enregistrer `IRON_YARD_UNIVERSE_ID` et `IRON_YARD_PLACE_ID` (sans les inverser).
4. Depuis le Creator Dashboard, créer une clé Open Cloud avec permission **universe-places / Write** sur cet univers, et lecture des métadonnées de l'univers/lieu pour la vérification. Enregistrer uniquement dans GitHub Actions > **Secrets** sous `ROBLOX_OPEN_CLOUD_API_KEY`. Ne pas la coller dans un message ou dans Git.
5. Vérifier que le [build Rojo](https://github.com/dbrckk/Roblox-shooter/actions/workflows/rojo-build.yml) du dernier commit de `main` est **vert** et que la licence, les règles de Roblox et les assets sont validés. Certains types d'instances (notamment SurfaceAppearance modifiée dans Studio) peuvent nécessiter une publication depuis Studio plutôt que l'API Open Cloud.

## Déployer depuis Android ou un PC

1. Ouvrir [Actions > Publish IRON YARD to PUBLIC Roblox experience](https://github.com/dbrckk/Roblox-shooter/actions/workflows/publish-roblox-public.yml) et choisir **Run workflow**, branche `main`.
2. Laisser **check_only = true** la première fois. La vérification contrôle les IDs, la propriété et le statut PUBLIC **sans rien publier**.
3. Une fois le contrôle vert et le jeu réellement prêt, relancer avec **check_only = false** et saisir **`PUBLISH IRON YARD PUBLIC`** dans le champ de confirmation.
4. Le workflow refuse le lancement si la CI du commit exact n'est pas verte. Il compile, inscrit le SHA Git réel dans le jeu, construit et publie la place, puis affiche le **Place Version** Roblox et l'URL. Ce numéro est aussi nécessaire pour documenter un incident.

**Aucune publication n'est automatique sur push.** Une publication GitHub réussie ne prouve pas que tous les serveurs en cours d'exécution ont chargé la nouvelle version. L'exposition publique, les critères de contenu et les paramètres de découvrabilité se contrôlent dans Creator Dashboard.

## Vérifier après une publication

- Ouvrir l'URL publique sur un Android réel, confirmer que le FPS se lance, que le FFA fonctionne et que la carte des résultats affiche un court identifiant **BUILD** correspondant au SHA.
- Répéter sur PC, vérifier les cinq armes, le HUD, la sauvegarde et la reconnexion, et noter les éventuelles erreurs réseau.
- Si un problème critique survient, arrêter les nouveaux déploiements, ouvrir **Creator Dashboard > Creations > IRON YARD > Configure > Places > Place > Version History**. Restaurer une version connue stable **ne la republie pas automatiquement** ; il faut ensuite la publier depuis Studio et redémarrer les serveurs appropriés. Autre option : revenir à un commit GitHub stable, laisser la CI passer, puis lancer un nouveau workflow public manuel pour ce nouveau commit. Ne pas restaurer une version inconnue sans vérification.

Sources officielles : https://create.roblox.com/docs/cloud/guides/usage-place-publishing et https://create.roblox.com/docs/projects/version-history .
