#!/usr/bin/env python3
"""Build and verify the per-asset acceptance matrix (LOT B1 of the V3 plan).

Reads the three authored asset ID modules and writes one table per family:
what is uploaded, who owns it, which channels exist, what fallback the runtime
keeps, and which control is still missing. Every row carries a status:

  READY_OFFLINE               IDs are filled and offline controls exist. The
                              asset has NOT been rendered in engine: upload is
                              not a proof of appearance.
  BLOCKED_ROBLOX_ASSET_APPROVAL  IDs are still zero, so the runtime keeps its
                              procedural or native-material fallback.

Default mode is --check: the committed document must match what the modules
say, and the invariants below must hold. Run with --write to regenerate.
Nothing here uploads, approves or modifies an asset.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/ASSET_ACCEPTANCE_MATRIX.md"

READY = "READY_OFFLINE"
BLOCKED = "BLOCKED_ROBLOX_ASSET_APPROVAL"

WEAPONS = "src/shared/WeaponAssetIds.luau"
PALETTES = "src/shared/VanguardAssetIds.luau"
WORLD = "src/shared/WorldPbrAssetIds.luau"

# Offline controls that already exist and must keep covering each family.
CONTROLS = {
    "weapons": [
        "src/shared/WeaponAssetPolicy.luau",
        "src/shared/WeaponAssetLoadPlan.luau",
        "src/shared/WeaponPbrFxSockets.luau",
        "scripts/test_weapon_asset_policy.luau",
        "scripts/test_weapon_asset_load_plan.luau",
        "scripts/test_weapon_pbr_fx_sockets.luau",
    ],
    "palettes": [
        "src/shared/VanguardAssetIds.luau",
        "src/server/VanguardAssetLoader.luau",
        "docs/VANGUARD_ASSETS.md",
    ],
    "world": [
        "src/shared/WorldPbrPolicy.luau",
        "src/shared/WorldPbrAssetIds.luau",
        "scripts/test_world_pbr_pipeline.py",
        "scripts/test_world_pbr_policy.luau",
        "tools/assetforge/audit_world_maps.py",
    ],
}


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


def block(text, name):
    """Body of `name = { ... }`, up to the matching closing brace."""
    start = re.search(rf"{name}\s*=\s*\{{", text)
    if start is None:
        raise AssertionError(f"missing block {name}")
    depth = 0
    for index in range(start.end() - 1, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start.end():index]
    raise AssertionError(f"unbalanced block {name}")


def header(text):
    owner = re.search(r"ownerUserId\s*=\s*(\d+)", text)
    commit = re.search(r'sourceCommit\s*=\s*"([^"]*)"', text)
    if owner is None or commit is None:
        raise AssertionError("asset module must declare ownerUserId and sourceCommit")
    return int(owner.group(1)), commit.group(1)


def weapons():
    text = source(WEAPONS)
    owner, commit = header(text)
    rows = []
    for match in re.finditer(
            r"(\w+)\s*=\s*\{\s*LOD0\s*=\s*(\d+)\s*,\s*LOD1\s*=\s*(\d+)\s*\}",
            block(text, "modelIds")):
        name, lod0, lod1 = match.group(1), int(match.group(2)), int(match.group(3))
        rows.append({
            "name": name,
            "ids": [lod0, lod1],
            "owner": owner,
            "source": commit,
            "detail": "LOD0 + LOD1",
            "channels": "MeshPart + SurfaceAppearance (validation offline)",
            "fallback": "viewmodel procédural",
            "runtime": "rendu, cadrage mobile et streaming non observés",
        })
    return rows, commit


def palettes():
    text = source(PALETTES)
    owner, commit = header(text)
    rows = []
    for match in re.finditer(r"(\w+)\s*=\s*(\d+)", block(text, "paletteModelIds")):
        rows.append({
            "name": match.group(1),
            "ids": [int(match.group(2))],
            "owner": owner,
            "source": commit,
            "detail": "modèle opérateur complet",
            "channels": "GLB + cartes PBR (archives locales)",
            "fallback": "personnage procédural IRON YARD",
            "runtime": "import propriétaire et rendu non confirmés",
        })
    return rows, commit


def world():
    text = source(WORLD)
    owner, commit = header(text)
    rows = []
    # The approved uploader writes multi-line Luau with trailing commas.
    # Parse balanced material blocks, accepting both actual and compact forms.
    materials = block(text, "materials")
    names = re.findall(r"(?m)^\s*(\w+)\s*=\s*\{", materials)
    expected = ("freight_steel", "warehouse_steel", "yard_asphalt")
    assert len(names) == 3 and set(names) == set(expected), \
        "world registry must contain exactly the three supported material names"
    channels = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
    for name in expected:
        contents = block(materials, name)
        values = re.findall(
            r"\b(ColorMap|NormalMap|RoughnessMap|MetalnessMap)\s*=\s*(\d+)",
            contents)
        assert len(values) == 4 and {ch for ch, _ in values} == set(channels), \
            f"world material {name} must declare four distinct channels"
        by_channel = dict(values)
        rows.append({
            "name": name,
            "ids": [int(by_channel[ch]) for ch in channels],
            "owner": owner,
            "source": commit,
            "detail": "4 canaux PBR",
            "channels": "Color / Normal / Roughness / Metalness",
            "fallback": "matériaux Roblox natifs",
            "runtime": ("rendu Roblox et FPS Android non observés"
                        if all(int(by_channel[ch]) > 0 for ch in channels)
                        else "upload Open Cloud et rendu non confirmés"),
        })
    return rows, commit


def status(ids):
    return READY if all(ident > 0 for ident in ids) else BLOCKED


def ids_cell(ids, labels):
    return "<br>".join(f"{label} `{ident}`" for label, ident in zip(labels, ids))


def table(rows, labels, family):
    lines = [
        f"### {family}",
        "",
        "| Asset | IDs | Owner | Source | Structure | Canaux | Fallback | Contrôle runtime manquant | Statut |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| `{row['name']}` | {ids_cell(row['ids'], labels)} | "
            f"{row['owner']} | `{row['source'] or '—'}` | {row['detail']} | "
            f"{row['channels']} | {row['fallback']} | {row['runtime']} | "
            f"`{status(row['ids'])}` |")
    lines.append("")
    return lines


def build():
    weapon_rows, weapon_commit = weapons()
    palette_rows, palette_commit = palettes()
    world_rows, world_commit = world()

    weapon_ids = [ident for row in weapon_rows for ident in row["ids"]]
    palette_ids = [ident for row in palette_rows for ident in row["ids"]]
    world_ids = [ident for row in world_rows for ident in row["ids"]]

    assert len(weapon_rows) == 5, f"expected 5 weapons, found {len(weapon_rows)}"
    assert len(weapon_ids) == 10, f"expected 10 weapon IDs, found {len(weapon_ids)}"
    assert all(ident > 0 for ident in weapon_ids), "a weapon Model ID is still zero"
    assert len(palette_ids) == 4, f"expected 4 palette IDs, found {len(palette_ids)}"
    assert len(world_rows) == 3 and len(world_ids) == 12, \
        f"expected 3 materials x 4 channels, found {len(world_ids)} IDs"
    assert len({row["owner"] for row in weapon_rows}) == 1, "weapon owner must be unique"
    for family, rows in (("weapon", weapon_rows), ("palette", palette_rows),
                         ("world", world_rows)):
        assert all(row["owner"] > 0 for row in rows), \
            f"{family} assets must declare a non-zero owner"
    assert re.fullmatch(r"[0-9a-f]{40}", weapon_commit), \
        "uploaded weapons must record a valid source commit"
    # The existing uploaders write sourceCommit when their entire batch has
    # finished. Future approved VANGUARD/world uploads must be accepted by
    # the matrix instead of being rejected for having legitimate provenance.
    for family, ids, commit in (
        ("VANGUARD", palette_ids, palette_commit),
        ("world PBR", world_ids, world_commit),
    ):
        if any(identifier > 0 for identifier in ids):
            assert re.fullmatch(r"[0-9a-f]{40}", commit), \
                f"{family} approved IDs require a source commit"
        else:
            assert not commit, f"{family} must not claim an unuploaded source"

    # Never promote an incomplete Roblox upload batch into production.
    for family, ids in (("VANGUARD", palette_ids), ("world PBR", world_ids)):
        configured = [identifier for identifier in ids if identifier > 0]
        assert len(configured) in (0, len(ids)), \
            f"{family} registry must be entirely empty or complete"
        assert len(configured) == len(set(configured)), \
            f"{family} registry reuses an ID"

    for family, paths in CONTROLS.items():
        for path in paths:
            assert (ROOT / path).exists(), f"missing offline control {path}"
        _ = family

    weapon_ready = sum(status(row["ids"]) == READY for row in weapon_rows)
    palette_blocked = sum(status(row["ids"]) == BLOCKED for row in palette_rows)
    world_blocked = sum(status(row["ids"]) == BLOCKED for row in world_rows)

    out = [
        "# Matrice d'acceptation par asset — état certifié par la CI",
        "",
        "**Date :** 12 novembre 2026 · **Lot :** B1 de la [V3](ROADMAP_V3_SANS_TEST_ANDROID.md) "
        "· **Généré par :** `scripts/asset_acceptance_matrix.py` (`--write`)",
        "",
        "> Ce document est **généré** depuis `WeaponAssetIds.luau`, `VanguardAssetIds.luau` et "
        "`WorldPbrAssetIds.luau`. `scripts/asset_acceptance_matrix.py --check` échoue s'il dérive "
        "des modules : la CI publie donc ce que le dépôt contient réellement, pas ce qu'on espère.",
        "",
        "## Statuts",
        "",
        f"- `{READY}` : IDs renseignés **et** contrôles offline présents. L'asset n'a **pas** été "
        "rendu en moteur ; un upload réussi n'est pas une preuve d'apparence.",
        f"- `{BLOCKED}` : IDs encore à zéro, le runtime conserve son fallback. Rien n'est inventé, "
        "rien n'est déclaré livré.",
        "",
        "## Synthèse",
        "",
        "| Famille | Assets | IDs | Prêts offline | Bloqués |",
        "|---|---:|---:|---:|---:|",
        f"| Armes | {len(weapon_rows)} | {len(weapon_ids)} | {weapon_ready} | "
        f"{len(weapon_rows) - weapon_ready} |",
        f"| Opérateurs VANGUARD | {len(palette_rows)} | {len(palette_ids)} | "
        f"{len(palette_rows) - palette_blocked} | {palette_blocked} |",
        f"| Matériaux du monde | {len(world_rows)} | {len(world_ids)} | "
        f"{len(world_rows) - world_blocked} | {world_blocked} |",
        "",
        "## Armes — 10 IDs propriétaires",
        "",
    ]
    out += table(weapon_rows, ["LOD0", "LOD1"], "Modèles d'armes")[2:]
    out += [
        "Fallback vérifié hors moteur : `WeaponAssetPolicy` et `WeaponAssetLoadPlan` gardent le "
        "viewmodel procédural quand un ID manque, et `WeaponPbrFxSockets` fixe les sockets FX. "
        "**Aucun rendu, cadrage mobile ou coût de streaming n'a été observé.**",
        "",
        f"## Opérateurs VANGUARD — {len(palette_rows) - palette_blocked} prêts hors moteur, "
        f"{palette_blocked} bloqués",
        "",
    ]
    out += table(palette_rows, ["Modèle"], "Palettes d'opérateur")[2:]
    out += [
        ("Quatre IDs de modèles propriétaires sont consignés. Leur rendu réel dans "
         "Roblox et sur Android reste à vérifier."
         if palette_blocked == 0 else
         "Blocage factuel : les quatre GLB existent dans les archives, mais aucun ID n'est "
         "approuvé. L'import propriétaire reste à faire, avec un préflight **sans upload réel**."),
        "",
        f"## Matériaux du monde — {len(world_rows) - world_blocked} prêts hors moteur, "
        f"{world_blocked} bloqués",
        "",
    ]
    out += table(world_rows, ["Color", "Normal", "Roughness", "Metalness"], "Matériaux PBR")[2:]
    out += [
        ("Douze IDs d'images sont consignés dans le registre propriétaire. "
         "La résolution des textures PBR sur Roblox reste à vérifier."
         if world_blocked == 0 else
         "Les douze PNG et leurs hashes sont produits par `tools/assetforge/generate_world_maps.py` "
         "et validés par `audit_world_maps.py`. Aucun upload Open Cloud n'a eu lieu : le jeu garde "
         "les matériaux Roblox natifs."),
        "",
        "## Ce que la CI certifie, et ce qu'elle ne certifie pas",
        "",
        "**Certifié ici :** la présence et la cohérence des IDs, l'unicité du propriétaire, la "
        "traçabilité du commit source des armes, l'existence des contrôles offline par famille, "
        "et le fait que chaque famille non uploadée est marquée `BLOCKED`.",
        "",
        "**Non certifié :** l'approbation Roblox, l'upload réel, le rendu en moteur, le cadrage "
        "mobile, le comportement au streaming, et l'absence de scripts tiers dans les modèles "
        "importés. Ces points exigent les permissions du créateur et une session Roblox.",
        "",
        "## Collisions, raycasts et repli",
        "",
        "Aucun asset de ce lot ne modifie une collision, un raycast, un déplacement ou une "
        "couverture : les IDs ne remplacent que l'apparence, et le repli natif reste actif tant "
        "qu'un ID vaut zéro. Un modèle contenant des scripts tiers ne doit jamais être intégré.",
        "",
    ]
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="regenerate docs/ASSET_ACCEPTANCE_MATRIX.md")
    args = parser.parse_args()
    generated = build()
    if args.write:
        DOC.write_text(generated, encoding="utf-8")
        print(f"wrote {DOC.relative_to(ROOT)}")
        return
    if not DOC.exists():
        raise SystemExit("docs/ASSET_ACCEPTANCE_MATRIX.md is missing: run --write")
    committed = DOC.read_text(encoding="utf-8")
    if committed != generated:
        raise SystemExit("docs/ASSET_ACCEPTANCE_MATRIX.md drifted from the asset "
                         "modules: run scripts/asset_acceptance_matrix.py --write")
    print("IRON YARD asset acceptance matrix matches current Roblox asset IDs: OK")


if __name__ == "__main__":
    main()
