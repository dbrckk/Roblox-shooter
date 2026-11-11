#!/usr/bin/env python3
"""Upload ten owner-authored IRON YARD GLBs using Roblox Open Cloud.

Fail closed: verify the exact binary source, creator and moderation before
writing the live Luau registry. The default CLI mode is strictly offline.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "weaponforge"))
from validate_weapon_exports import REQUIRED, ORIGIN_NAME, inspect  # noqa: E402
from upload_vanguard_models import API, request_json  # noqa: E402

LODS = ("LOD0", "LOD1")
WEAPONS = tuple(REQUIRED)
MAX_UPLOAD = 20_000_000


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sources(asset_root):
    manifest = json.loads((asset_root / "manifest.json").read_text("utf-8"))
    require(manifest.get("textureResolution") == 512, "Invalid PBR texture resolution")
    require(set(manifest.get("weapons", [])) == set(WEAPONS),
            "Missing or unexpected authored weapons")
    exports = manifest.get("exports")
    require(isinstance(exports, list) and len(exports) == 10,
            "Weapon forge must contain exactly ten GLB exports")
    declared = {(x.get("weapon"), x.get("lod")): x for x in exports
                if isinstance(x, dict)}
    require(len(declared) == 10, "Duplicate weapon/LOD entries in source manifest")
    entries = {}
    for weapon in WEAPONS:
        for lod in LODS:
            filename = f"iron_yard_{weapon}_{lod}.glb"
            require((weapon, lod) in declared
                    and declared[weapon, lod].get("file") == filename,
                    "Mismatched source manifest: " + filename)
            raw = (asset_root / "meshes" / filename).read_bytes()
            require(2048 < len(raw) <= MAX_UPLOAD, "Model is outside Roblox size limits")
            geometry = inspect(asset_root / "meshes" / filename, weapon)
            require(set(declared[weapon, lod].get("names", [])) ==
                    REQUIRED[weapon] | {ORIGIN_NAME},
                    "Model node identity/origin differs from manifest")
            require(declared[weapon, lod].get("bytes") == len(raw),
                    "Model bytes differ from source manifest")
            entries[(weapon, lod)] = {
                "filename": filename, "bytes": len(raw),
                "sha256": hashlib.sha256(raw).hexdigest(),
                "triangles": geometry["triangles"], "raw": raw,
            }
        require(entries[weapon, "LOD0"]["triangles"]
                > entries[weapon, "LOD1"]["triangles"],
                "LOD0 geometry must be more detailed than LOD1: " + weapon)
    return entries


def confirmed_asset(response, owner):
    require(isinstance(response, dict), "Asset operation missing response")
    asset_id = response.get("assetId")
    try:
        asset_id = int(asset_id)
    except (TypeError, ValueError):
        raise ValueError("Asset operation did not return a valid numeric ID") from None
    require(asset_id > 0, "Invalid Roblox asset ID")
    require(response.get("assetType") in ("Model", "ASSET_TYPE_MODEL"),
            "Asset did not resolve to a Model")
    creator = (response.get("creationContext") or {}).get("creator") or {}
    require(str(creator.get("userId")) == str(owner),
            "Asset creator is not the configured experience owner")
    state = (response.get("moderationResult") or {}).get("moderationState")
    require(state in ("MODERATION_STATE_APPROVED", "Approved"),
            "Asset moderation is not explicitly approved")
    return asset_id


def upload_model(owner, weapon, lod, raw, key):
    boundary = "IY-" + uuid.uuid4().hex
    metadata = json.dumps({
        "assetType": "Model",
        "displayName": f"IRON YARD {weapon} {lod} Original PBR",
        "description": "Original Blender-authored first-person 3D model with two LOD variants.",
        "creationContext": {"creator": {"userId": str(owner)}},
    }, separators=(",", ":")).encode("utf-8")
    payload = (f"--{boundary}\r\n"
               'Content-Disposition: form-data; name="request"\r\n'
               "Content-Type: application/json\r\n\r\n").encode("ascii")
    payload += metadata
    payload += (f"\r\n--{boundary}\r\n"
                f'Content-Disposition: form-data; name="fileContent"; filename="{weapon}_{lod}.glb"\r\n'
                "Content-Type: model/gltf-binary\r\n\r\n").encode("ascii")
    payload += raw + f"\r\n--{boundary}--\r\n".encode("ascii")
    result = request_json(API + "/assets", key, payload=payload,
                          content_type=f"multipart/form-data; boundary={boundary}")
    path = result.get("path", "")
    require(isinstance(path, str) and
            re.fullmatch(r"operations/[A-Za-z0-9_./-]+", path),
            "Roblox did not return a safe operation path")
    for _ in range(45):
        if result.get("done"):
            require(not result.get("error"), "Roblox rejected asset creation")
            return confirmed_asset(result.get("response"), owner)
        time.sleep(3)
        result = request_json(API + "/" + path, key)
    raise TimeoutError("Roblox asset processing timed out")


def verify_existing(asset_id, owner, key):
    require(isinstance(asset_id, int) and asset_id > 0, "Bad saved asset ID")
    response = request_json(API + "/assets/" + str(asset_id), key)
    return confirmed_asset(response, owner) == asset_id


def matching_committed_ids(module_text, source_commit):
    # Re-running the same verified forge must not upload ten duplicate assets.
    # These source-controlled IDs are still rechecked against Roblox live data.
    if not re.search(r'sourceCommit\s*=\s*"' + source_commit + r'"',
                     module_text):
        return {}
    rows = {}
    for weapon in WEAPONS:
        match = re.search(
            rf'\b{weapon}\s*=\s*\{{\s*LOD0\s*=\s*(\d+)'
            rf'\s*,\s*LOD1\s*=\s*(\d+)\s*\}}', module_text)
        if not match:
            return {}
        rows[weapon, "LOD0"] = int(match.group(1))
        rows[weapon, "LOD1"] = int(match.group(2))
    return rows


def render_module(owner, source_commit, rows):
    result = [
        "-- IRON YARD / verified owner-uploaded PBR Model IDs.",
        "-- Generated only after all ten Model uploads passed owner checks.",
        "return {", f"    ownerUserId = {owner},",
        f'    sourceCommit = "{source_commit}",',
        "    modelIds = {",
    ]
    for weapon in WEAPONS:
        result.append(f"        {weapon} = {{ LOD0 = {rows[weapon, 'LOD0']['assetId']},"
                      f" LOD1 = {rows[weapon, 'LOD1']['assetId']} }},")
    return "\n".join(result + ["    },", "}", ""])


def checkpoint_write(path, owner, source_commit, rows):
    # The registry checkpoint contains asset IDs and source hashes only, no secret.
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_rows = {}
    for (weapon, lod), row in rows.items():
        if "assetId" in row:
            safe_rows[f"{weapon}/{lod}"] = {
                "sha256": row["sha256"], "assetId": row["assetId"],
            }
    content = {"ownerUserId": owner, "sourceCommit": source_commit,
               "models": safe_rows}
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(content, indent=2) + "\n", "utf-8")
    temporary.replace(path)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--owner-user-id", type=int, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--module", type=Path, required=True)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args(argv)
    require(args.owner_user_id > 0, "Creator user ID must be positive")
    require(re.fullmatch(r"[0-9a-f]{40}", args.source_commit),
            "Source commit must be a forty-character lowercase SHA")
    existing = args.module.read_text("utf-8")
    require(re.search(r"ownerUserId\s*=\s*" + str(args.owner_user_id) + r"\b",
                      existing) is not None,
            "Owner does not match the game's committed owner registry")
    rows = sources(args.assets)

    if not args.publish:
        for weapon in WEAPONS:
            for lod in LODS:
                row = rows[weapon, lod]
                print(f"Verified {weapon}/{lod}: {row['bytes']} bytes; "
                      f"{row['triangles']} triangles")
        print("DRY RUN: no Roblox request, file or registry update")
        return 0

    key = os.environ.get("ROBLOX_OPEN_CLOUD_ASSETS_KEY", "")
    require(bool(key), "ROBLOX_OPEN_CLOUD_ASSETS_KEY is not configured")
    already = matching_committed_ids(existing, args.source_commit)
    previous = {}
    if args.checkpoint.is_file():
        saved = json.loads(args.checkpoint.read_text("utf-8"))
        if saved.get("ownerUserId") == args.owner_user_id and (
                saved.get("sourceCommit") == args.source_commit):
            previous = saved.get("models", {})

    for weapon in WEAPONS:
        for lod in LODS:
            row = rows[weapon, lod]
            cached = previous.get(f"{weapon}/{lod}", {})
            committed = already.get((weapon, lod))
            if committed is not None and committed > 0:
                if verify_existing(committed, args.owner_user_id, key):
                    row["assetId"] = committed
            elif cached.get("sha256") == row["sha256"] and isinstance(
                    cached.get("assetId"), int):
                # A checkpoint alone cannot authorize arbitrary model IDs.
                if verify_existing(cached["assetId"], args.owner_user_id, key):
                    row["assetId"] = cached["assetId"]
            if "assetId" not in row:
                row["assetId"] = upload_model(
                    args.owner_user_id, weapon, lod, row["raw"], key)
            checkpoint_write(args.checkpoint, args.owner_user_id,
                             args.source_commit, rows)
            print(f"Roblox confirmed {weapon}/{lod} asset ID {row['assetId']}")

    require(all("assetId" in row for row in rows.values()),
            "Incomplete weapon asset set; registry remains unchanged")
    new_module = render_module(args.owner_user_id, args.source_commit, rows)
    staging = args.module.with_suffix(".tmp")
    staging.write_text(new_module, "utf-8")
    staging.replace(args.module)
    print("All ten owner-owned Model IDs confirmed; registry ready for Rojo build")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError, TimeoutError) as error:
        print("Weapon asset activation incomplete: " + str(error), file=sys.stderr)
        sys.exit(1)
