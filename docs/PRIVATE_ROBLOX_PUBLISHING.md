# Publier IRON YARD en expérience Roblox privée

Ce dépôt produit déjà `iron-yard.rbxlx` avec Rojo. La publication sur Roblox
est **distincte** de la compilation et nécessite une connexion Roblox Open Cloud.

## Une seule préparation (l'accès n'est pas connecté à ce chat)

1. Créer dans Roblox Studio une **nouvelle expérience** nommée **IRON YARD** sur
   **ton compte**, séparée de Chaos Survival. Publier une première fois, en
   laissant la visibilité réglée sur **Private**. Roblox crée un `Universe ID`
   et un `Place ID`. Si une expérience privée vide IRON YARD existe déjà,
   cette création n'est pas nécessaire.
2. Sur [Creator Dashboard](https://create.roblox.com/dashboard/creations),
   ouvrir IRON YARD : menu de la vignette → **Copy Universe ID** ; onglet
   **Places** → récupérer l'ID de la place de démarrage.
3. Sur [Roblox Creator Dashboard – API Keys](https://create.roblox.com/docs/cloud/auth/api-keys),
   créer une clé **limitée à l'expérience IRON YARD**, avec les autorisations :
   - `universe:read` (vérifier nom et statut privé)
   - `universe.place:read` (vérifier l'existence de la place)
   - `universe-places:write` (publier le fichier RBXLX).
   Les adresses IP des runners GitHub hébergés varient : pour cette
   automatisation, laisser **Restrict IP addresses** désactivé (optionnel
   chez Roblox), mais **restreindre absolument la clé à IRON YARD**
   et limiter sa durée de validité. Une restriction IP incompatible
   provoquera un refus d'authentification. Révoquer la clé dès qu'elle
   ne sert plus.
4. Dans [GitHub → Actions secrets](https://github.com/dbrckk/Roblox-shooter/settings/secrets/actions),
   ajouter **Repository secret** nommé exactement
   `ROBLOX_OPEN_CLOUD_API_KEY`, avec la valeur de la clé. **Ne jamais coller
   la clé dans le chat, dans un issue, dans les paramètres d'Actions ou dans le
   code source**.
5. Ouvrir [Publish IRON YARD to private Roblox experience](https://github.com/dbrckk/Roblox-shooter/actions/workflows/publish-roblox-private.yml).
   Choisir **Run workflow** sur `main`, saisir les deux identifiants,
   laisser `check_only = false`, cocher la confirmation `confirm_private`,
   puis lancer.

Si le workflow réussit, il affiche le numéro de version Roblox et le lien
de la place privée. Pour vérifier la clé **sans rien publier**, lancer le
workflow avec `check_only = true`.

## Protections imposées par le code

- Le workflow est **uniquement manuel**. Aucun push GitHub ne publie le jeu.
- Il vérifie d'abord l'identité de l'expérience (nom IRON YARD), son statut
  `PRIVATE` et la présence de la place dans cet univers.
- Il **refuse** une expérience publique, une autre expérience Roblox, une
  clé manquante, des identifiants invalides ou une erreur API.
- Il republie exactement le build courant compilé depuis `main` avec
  `versionType=Published`. Cela enregistre une version de place, **sans
  activer la visibilité publique**.
- Il vérifie à nouveau le statut `PRIVATE` après l'upload.
- Il ne contient **aucun appel** à l'API `/activate` ou changement de visibilité.
- Le déploiement s'arrête en cas d'échec. Il n'existe pas de fallback silencieux
  qui utiliserait Chaos Survival.

**Limite** : la clé de publication, les identifiants et l'expérience ne sont
pas fournis dans ce dépôt ; le workflow n'a pas été lancé vers Roblox.
Il est impossible de prétendre que la version a été mise sur ton compte tant
qu'une exécution ne retourne pas de numéro de version Roblox.

## Android

Tu peux gérer le Creator Dashboard, les secrets GitHub et lancer le workflow
depuis le navigateur mobile. La **première création** d'une expérience Roblox
nécessite Roblox Studio sous Windows ou macOS si aucun emplacement privé
adapté n'a déjà été créé.

Sources officielles :
- https://create.roblox.com/docs/cloud/guides/usage-place-publishing
- https://create.roblox.com/docs/cloud/auth/api-keys
- https://create.roblox.com/docs/production/publishing/publish-games-and-places

## Asset PBR Open Cloud optionnel

Le workflow GitHub [upload-vanguard-opencloud.yml](https://github.com/dbrckk/Roblox-shooter/actions/workflows/upload-vanguard-opencloud.yml) a **une clé différente** de celle nécessaire à la publication d'une place : `ROBLOX_OPEN_CLOUD_ASSETS_KEY` (permissions Assets Read et Write). Cette clé ne donne pas automatiquement la permission de publier des places privées. Réciproquement, la clé de publication privée d'IRON YARD ne donne pas automatiquement la permission d'importer des assets. Le nouvel import peut rester en validation locale en l'absence de cette clé.
