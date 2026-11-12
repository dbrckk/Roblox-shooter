# Protection des déplacements différés — 12 novembre 2026

**Correctif A3 — `MovementService.requestMantle`.** Un `MovementAction` de type
`Mantle` déclenche deux étapes serveur : impulsion immédiate, puis déplacement
du `HumanoidRootPart` après `task.delay(0.14)`. Avant ce correctif,
l'étape différée vérifiait uniquement la survie du personnage et l'identité
du root. Un `Mantle` déclenché juste avant l'entrée en `DUEL_PREP`
pouvait donc déplacer le combattant malgré l'ancrage et le placement
autoritaire des deux participants.

## Conditions désormais requises

- Le serveur n'accepte un nouveau `Mantle` qu'en phase `LIVE` et avec un
  root non ancré. Les actions d'arrêt `BoostStop` / `StopWallRun` restent
  intactes ; aucune cadence de mouvement n'est changée.
- À l'échéance, le même joueur doit avoir le même personnage vivant, le même
  root et le même état de déplacement serveur ; ce root doit être non ancré.
- La phase doit **toujours** être `LIVE`, le `IronYardFireEpoch` ne doit pas
  avoir changé, et le jeton monotone `mantleToken` doit être identique.
- Ce jeton est invalidé lors de `CharacterAdded` et de
  `MovementService.resetDuelMovement`. Un callback ancien ne peut donc pas
  déplacer un nouveau rig ou une position de départ 1v1.

Le module pur `MantleCommitPolicy` est exercé par
`scripts/test_mantle_commit_policy.luau`. Le contrat
`scripts/check_movement_contract.py` vérifie le câblage des gardes
**avant** la ligne qui modifie `currentRoot.CFrame`.

## Limites

La CI ne simule ni une physique Roblox, ni une véritable latence réseau, ni
l'exécution différée du moteur. Vérifier dans Studio avec deux clients :
déclencher un mantle juste avant la préparation 1v1 et confirmer que les
deux personnages restent à leur position ancrée pendant le compte à rebours.
Le correctif est indépendant de l'upload des assets PBR.
