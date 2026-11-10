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
