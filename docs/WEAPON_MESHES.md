# IRON YARD — original PBR mesh weapon forge

Production objective: replace the first-person procedural Part weapon bodies
with **original, mechanically separated 3D meshes**, not borrowed RIVALS models.
The generator uses free Blender in GitHub Actions.

**Forge workflow:** https://github.com/dbrckk/Roblox-shooter/actions/workflows/weaponforge.yml

## Generated source pack (five weapons, ten GLBs)

| Weapon | Files | Mechanical export |
| --- | --- | --- |
| Pistol | `iron_yard_pistol_LOD{0,1}.glb` | `IRONYARD_Pistol_Static`, `IRONYARD_Pistol_Slide` |
| Knife | `iron_yard_knife_LOD{0,1}.glb` | `IRONYARD_Knife_Static` |
| AR-24 | `iron_yard_assault_rifle_LOD{0,1}.glb` | `IRONYARD_AssaultRifle_Static`, `IRONYARD_AssaultRifle_ChargingHandle`, `IRONYARD_AssaultRifle_Magazine` |
| B-8 | `iron_yard_shotgun_LOD{0,1}.glb` | `IRONYARD_Shotgun_Static`, `IRONYARD_Shotgun_PumpAction` |
| Sniper | `iron_yard_sniper_LOD{0,1}.glb` | `IRONYARD_Sniper_Static`, `IRONYARD_Sniper_Bolt` |

Each weapon also has an editable `iron_yard_<weapon>_source.blend`.
`weapons_source.blend` remains for backward compatibility.
The kit contains 512px original base color, normal, metallic and roughness
maps; each GLB embeds PBR channels. `validate_weapon_exports.py` parses
**actual GLB2 binary chunks**, checks UVs, triangle counts, required nodes,
embedded images, the manifest, all 10 exports and LOD0 > LOD1 triangles.

**Note:** A successfully exported GLB is not evidence that its `MeshId`
or `SurfaceAppearance` is accessible to a specific Roblox creator. The
GitHub artifact and release are source kits, **not an updated Roblox game**.

## Roblox Studio activation

1. Download the `iron-yard-original-weapon-meshes` job artifact or
   the latest `iron-yard-weapon-meshes-<commit>` release.
2. With the destination **owner** account, open the game in Roblox Studio.
   Use the 3D Importer to import both LOD0 and LOD1 of a weapon. Ensure
   each imported root is a Model named with its weapon and LOD (e.g.,
   `iron_yard_assault_rifle_LOD0`). Check scale and pivots.
3. Inspect the imported `MeshPart` objects. Each must have a nonempty
   `MeshId` and all four `SurfaceAppearance` map asset IDs. Imported
   meshes without fully assigned maps are not accepted.
4. In Explorer select **both** imported LOD root Models for each weapon
   you want to add. It is valid to select 2, 4, 6, 8 or all 10 models,
   provided every selected weapon has its LOD0/LOD1 pair.
5. Run `tools/studio/install_weapon_meshes.lua` in the Studio Command Bar.
   It validates all selected files before swapping the template folder,
   strips scripts and attachments, and retains previously installed
   **approved** weapon kits when adding new categories.
6. In Play, the local `<Weapon>Viewmodel` attribute
   `IronYardWeaponSource` is `PBR_MESH` when that weapon's validated kit
   is active; otherwise `PROCEDURAL_PARTS` and the weapon stays playable.
   Check weapon swaps, magazine / lever / pump / bolt motion, brass ejection,
   B-8 reload shell, scope visibility, muzzle FX and sight alignment.
7. Test ECO/BALANCED/QUALITY in both Android and PC, then save and
   **publish the Roblox place** using the authorized owner account.

The first-person Roblox code only clones the required MeshParts and their
four maps. Existing server raycasts, ammo rules, damage, respawns and net
messages do **not** depend on imported meshes.

## Mobile and visual verification remaining

- Check all LODs on actual Android devices with GPU frame time / FPS,
  material rendering, screen clipping and moving-hand alignment.
- Approve and version the final assets on Roblox. All imported model
  permissions must match the destination experience's account.
- Capture in-engine images to verify the visual quality gap versus RIVALS.
- The repository's GitHub Actions **cannot publish the live Roblox game**
  without configured Open Cloud authorization and destination IDs; a
  source release alone does not activate the meshes.

The transparent local muzzle and ejector anchors keep recoil, tracer,
case ejection and B-8 shell reload behavior working with the PBR models.
The sniper's optic still hides the first-person weapon when scoped.


## Automated owner-authorized activation (Open Cloud)

The legacy Studio import above remains an available manual fallback. There is
now a **non-interactive owner-owned path** for the same ten authored GLBs:

1. The existing [weaponforge](https://github.com/dbrckk/Roblox-shooter/actions/workflows/weaponforge.yml)
   produces ten GLB files and validates their real binary content.
2. The [Upload original weapon PBR GLBs](https://github.com/dbrckk/Roblox-shooter/actions/workflows/upload-weapon-opencloud.yml)
   workflow retrieves a successful forge artifact, checks that weapon source
   files still match, verifies every GLB and checks the Roblox creator ID.
   Its default `publish_assets=false` validates offline and **never uploads**.
3. When the experience owner has configured the GitHub Actions repository
   secret `ROBLOX_OPEN_CLOUD_ASSETS_KEY` with the Roblox Assets API read/write
   scope, run the workflow with `publish_assets=true` and owner user ID
   `9774173158`. **Never paste the key into a public issue, chat or repo.**
4. Roblox creates ten **Model** assets. The script verifies each ID, owner,
   Model type and explicit moderation approval, checkpoints confirmed uploads
   and restores the checkpoint on retry. Reruns recheck previously registered
   assets to avoid uploading duplicates.
5. Only after all ten have passed the checks does GitHub Actions update
   `src/shared/WeaponAssetIds.luau`. No partial registry commit can activate
   an incomplete weapon. Successful upload IDs do not by themselves prove
   texture or movement fidelity.
6. `WeaponAssetLoader.start()` on game-server initialization reads the
   committed IDs. For a matching **user-owned** experience, it asynchronously
   uses `AssetService:LoadAssetAsync()`, validates all expected `MeshPart`
   names, actual mesh content and all four `SurfaceAppearance` maps,
   strips all other descendants, and publishes complete LOD0/LOD1 pairs
   into `ReplicatedStorage.IronYardWeaponTemplates`. Existing owner-imported
   templates are never overwritten. The client selects them on weapon equip;
   an absent or invalid asset retains the procedural weapon.
7. **Publish the updated Rojo place to the public Roblox experience** with
   its independently configured release workflow. The GitHub source build
   and the upload workflow are distinct from this final deployment.
   A running server is not retroactively updated simply because new GitHub
   asset IDs have been committed.

### Production checks

- Server: `workspace:GetAttribute("IronYardWeaponMeshStatus")` reports
  `DISABLED`, `LOADING`, `PARTIAL`, `READY`, `MANUAL` or `FALLBACK`
  according to actual runtime source availability.
- Client: the equipped viewmodel's `IronYardWeaponSource` reports
  `PBR_MESH` only when an approved, complete mesh pair was found.
- Run an Android + PC test with all five weapons: select ECO/BALANCED/QUALITY,
  aim, shoot, reload, swap, inspect muzzle flashes, shells and scope
  occlusion. Measure FPS/P95/P99 and inspect the model scale/origin.
- Never consider an asset upload, a Rojo build or a repository merge as
  proof of a successful **live Roblox publication**.

If the Open Cloud key is missing, no remote Roblox request occurs. The
previously published game stays unchanged and the generated source pack
remains available from
[the five-weapon release](https://github.com/dbrckk/Roblox-shooter/releases/tag/iron-yard-weapon-meshes-c6ac0d03969f).


## Compatible glTF material primitives and live LOD updates

Roblox's official glTF importer can create a nested `Model` per authored mesh
and **one `MeshPart` per glTF material primitive**. Our authored weapons use
four PBR material roles, so the original one-part-per-component assumption
was incorrect. The runtime and Studio installer now share
`WeaponMeshLayout.luau`: they identify only the expected authored component
names (including Roblox's `_Node` suffix), validate every material primitive,
reject duplicate component roots or oversized groups, and sanitize each part.
The client keeps all material pieces under the *same* mechanical animation
track (slide, magazine, pump, or bolt). No scripts are imported.

Roblox documents this hierarchy:
https://create.roblox.com/docs/studio/importer#glTF-import-hierarchy

A server can finish importing an approved model **after** a player equips an
arm. The client now checks for a completed mesh kit at most once every 1.2 s
using its existing render callback. If valid, it upgrades from procedural to
PBR only when the player has not recently fired, aimed, sprinted, or reloaded;
pending cartridge ejection and blending also prevent interruption. Switching
between ECO/BALANCED/QUALITY similarly selects LOD1/LOD0 at the next safe idle
moment without forcing the player to re-equip their gun.

The imported viewmodel sets `IronYardWeaponLOD` to `LOD0` or `LOD1`
and may set `IronYardWeaponUpgrade=DEFERRED_IDLE` after a safe runtime swap.
These are local cosmetic diagnostic attributes, not user-facing HUD labels.
Client transforms, pivot alignment, PBR texture fidelity, visibility and
Android frame rates still require Roblox Studio + device QA. A green Rojo
build cannot confirm any live asset import or visual quality.

## Origine géométrique stable — GLB LOD0/LOD1

Chaque export original (les dix GLB, cinq armes × deux LOD) contient maintenant
un mini-mesh **`IRONYARD_WeaponOrigin`**, placé exactement à l'origine du
modèle Blender, indépendant de la taille de la crosse, du canon et de l'optique.
Cette pièce est un *repère de transformée*, **jamais un élément visible**.

Pourquoi : le pivot d'un Model Roblox téléchargé depuis une ressource Open
Cloud ou importé avec glTF peut être basé sur son centre d'encombrement.
Ce centre se déplace selon l'arme et sa version LOD. S'y fier décalerait les
mains, le recul, les armes et les effets de tir. Le chargeur serveur et
l'installateur Studio exigent donc une origine unique et correctement
dimensionnée, qu'ils copient dans le `WeaponOrigin` invisible des templates.
La vue première personne se place relativement à ce repère déterministe.

**Sécurité et compatibilité :** un ancien pack sans cette origine ne peut
pas être activé automatiquement par le nouveau chargeur. Il conserve le
fallback jouable jusqu'à la publication d'un nouveau pack validé. Les
templates déjà installés et explicitement approuvés dans Studio gardent
leur ancien `WeaponOrigin` lors d'une mise à jour partielle, pour éviter
d'altérer silencieusement les placements précédemment réglés.

Le validateur inspecte les fichiers **GLB2 binaires réels** et impose un
repère unique à l'origine (transformation et géométrie bornées). Le test
`scripts/test_weapon_origin_glb.py` corrompt volontairement les GLB en
mémoire (repère absent, translaté, mis à l'échelle, surdimensionné) et
vérifie que l'activation est refusée. Le workflow
`.github/workflows/weaponforge.yml` exécute ces tests avant la création
de l'archive et sa mise en ligne.

Même avec ces corrections, les réglages de visée, l'orientation des axes,
la visibilité PBR et le positionnement des mains doivent être mesurés en
situation réelle sur Roblox Studio/Android avant toute affirmation de
qualité AAA ou publication finale.
