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
# The GLB file slugs are lowercase; Roblox gameplay IDs are not.
# A wrong key silently leaves all ten uploaded models inactive.
RUNTIME_NAMES = {
    "pistol": "Pistol",
    "knife": "Knife",
    "assault_rifle": "AssaultRifle",
    "shotgun": "Shotgun",
    "sniper": "Sniper",
}
assert set(RUNTIME_NAMES) == set(WEAPONS)
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


def model_display_name(weapon, lod):
    require(weapon in WEAPONS and lod in LODS, "Unknown authored weapon / LOD")
    return f"IRON YARD {weapon} {lod} Original PBR"


def confirmed_asset(response, owner, expected_name=None):
    asset_id = validated_identity(response, owner, expected_name)
    state = (response.get("moderationResult") or {}).get("moderationState")
    require(state in ("MODERATION_STATE_APPROVED", "Approved"),
            "Asset moderation is not explicitly approved")
    return asset_id


OPERATION_PATH = re.compile(r"operations/[A-Za-z0-9_-]{1,160}\Z")
POLL_ATTEMPTS = 45


def safe_operation_path(path):
    require(isinstance(path, str) and OPERATION_PATH.fullmatch(path) is not None,
            "Unsafe or missing Roblox operation ID")
    return path


def validated_identity(response, owner, expected_name=None):
    """Verify asset identity, owner, type and optionally exact authored variant."""
    require(isinstance(response, dict), "Asset operation missing response")
    asset_id = response.get("assetId")
    # int(1.5) silently becomes 1; bool is also an int in Python. Neither
    # is a legitimate Roblox asset identifier. Accept only decimal digits.
    require(not isinstance(asset_id, bool)
            and (isinstance(asset_id, int)
                 or (isinstance(asset_id, str) and asset_id.isascii()
                     and asset_id.isdecimal())),
            "Asset operation did not return a valid numeric ID")
    asset_id = int(asset_id)
    require(0 < asset_id <= 9223372036854775807, "Invalid Roblox asset ID")
    require(response.get("assetType") in ("Model", "ASSET_TYPE_MODEL"),
            "Asset did not resolve to a Model")
    creator = (response.get("creationContext") or {}).get("creator") or {}
    require(str(creator.get("userId")) == str(owner),
            "Asset creator is not the configured experience owner")
    if expected_name is not None:
        require(response.get("displayName") == expected_name,
                "Verified Roblox Model name differs from the authored weapon/LOD")
    return asset_id


def poll_operation(path, owner, key, initial=None, *, expected_name=None):
    """Resume a previously created operation. Never POST a second time.

    Roblox can finish file processing before moderation is approved. Treat
    a pending moderation result as an incomplete upload, never as success.
    """
    path = safe_operation_path(path)
    for attempt in range(POLL_ATTEMPTS):
        if attempt == 0 and initial is not None:
            operation = initial
        else:
            operation = request_json(API + "/" + path, key)
        require(isinstance(operation, dict), "Malformed operation response")
        if operation.get("done"):
            if operation.get("error"):
                raise RuntimeError("Roblox rejected the existing asset operation")
            response = operation.get("response")
            asset_id = validated_identity(response, owner, expected_name)
            state = (response.get("moderationResult") or {}).get("moderationState")
            if state in ("MODERATION_STATE_APPROVED", "Approved"):
                return asset_id
            if state in ("MODERATION_STATE_REJECTED", "Rejected"):
                raise RuntimeError("Roblox explicitly rejected this model")
            # Operation is done, but asynchronous asset moderation has not
            # necessarily finished. Query by already-verified owner asset ID.
            refreshed = request_json(API + "/assets/" + str(asset_id), key)
            try:
                return confirmed_asset(refreshed, owner, expected_name)
            except ValueError as exc:
                if str(exc) != "Asset moderation is not explicitly approved":
                    raise
                new_state = (refreshed.get("moderationResult") or {}).get(
                    "moderationState")
                if new_state in ("MODERATION_STATE_REJECTED", "Rejected"):
                    raise RuntimeError("Roblox rejected this pending model") from None
        if attempt + 1 < POLL_ATTEMPTS:
            time.sleep(3)
    raise TimeoutError("Roblox operation is still processing/moderating: " + path)


def upload_model(owner, weapon, lod, raw, key, *, operation_path=None,
                 on_started=None):
    """POST only for an unknown model; persist the path before first poll."""
    expected_name = model_display_name(weapon, lod)
    if operation_path is not None:
        return poll_operation(operation_path, owner, key,
                              expected_name=expected_name)
    boundary = "IY-" + uuid.uuid4().hex
    metadata = json.dumps({
        "assetType": "Model",
        "displayName": expected_name,
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
    operation = request_json(API + "/assets", key, payload=payload,
                             content_type=f"multipart/form-data; boundary={boundary}")
    require(isinstance(operation, dict), "Missing Roblox upload operation")
    path = safe_operation_path(operation.get("path"))
    if on_started is not None:
        on_started(path)
    return poll_operation(path, owner, key, initial=operation,
                          expected_name=expected_name)


def verify_existing(asset_id, owner, key, weapon, lod):
    require(isinstance(asset_id, int) and asset_id > 0, "Bad saved asset ID")
    response = request_json(API + "/assets/" + str(asset_id), key)
    require(confirmed_asset(response, owner, model_display_name(weapon, lod))
            == asset_id, "Roblox returned a different asset ID")
    return True


def matching_committed_ids(module_text, source_commit):
    # Re-running the same verified forge must not upload ten duplicate assets.
    # These source-controlled IDs are still rechecked against Roblox live data.
    if not re.search(r'sourceCommit\s*=\s*"' + source_commit + r'"',
                     module_text):
        return {}
    rows = {}
    for weapon in WEAPONS:
        match = re.search(
            rf'\b{RUNTIME_NAMES[weapon]}\s*=\s*\{{\s*LOD0\s*=\s*(\d+)'
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
        result.append(f"        {RUNTIME_NAMES[weapon]} = {{ LOD0 = {rows[weapon, 'LOD0']['assetId']},"
                      f" LOD1 = {rows[weapon, 'LOD1']['assetId']} }},")
    return "\n".join(result + ["    },", "}", ""])


def checkpoint_write(path, owner, source_commit, rows):
    # Checkpoint holds source hashes, approved asset IDs and pending operation IDs only (never the API key).
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_rows = {}
    for (weapon, lod), row in rows.items():
        if "assetId" in row or "operationPath" in row:
            saved = {"sha256": row["sha256"]}
            if "assetId" in row:
                saved["assetId"] = row["assetId"]
            if "operationPath" in row:
                saved["operationPath"] = safe_operation_path(row["operationPath"])
            safe_rows[f"{weapon}/{lod}"] = saved
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
                # A committed Model ID that fails owner, moderation, name or
                # identity checks is NOT permission to silently create a new
                # asset. Stop the release before wasting another Open Cloud
                # upload (or replacing the live registry with the wrong kit).
                require(verify_existing(committed, args.owner_user_id, key,
                                        weapon, lod),
                        "Committed Roblox asset could not be reverified")
                row["assetId"] = committed
            elif cached.get("sha256") == row["sha256"]:
                if isinstance(cached.get("assetId"), int):
                    # Checkpoints can contain arbitrary IDs. Verify identity
                    # and the precise weapon/LOD, never just the creator.
                    require(verify_existing(cached["assetId"],
                                            args.owner_user_id, key,
                                            weapon, lod),
                            "Checkpoint asset could not be reverified")
                    row["assetId"] = cached["assetId"]
                elif "operationPath" in cached:
                    # Never repeat an upload while its operation is pending.
                    row["operationPath"] = safe_operation_path(
                        cached["operationPath"])
            if "assetId" not in row:
                def record_started(path):
                    row["operationPath"] = safe_operation_path(path)
                    checkpoint_write(args.checkpoint, args.owner_user_id,
                                     args.source_commit, rows)

                row["assetId"] = upload_model(
                    args.owner_user_id, weapon, lod, row["raw"], key,
                    operation_path=row.get("operationPath"),
                    on_started=record_started)
                row.pop("operationPath", None)
            checkpoint_write(args.checkpoint, args.owner_user_id,
                             args.source_commit, rows)
            print(f"Roblox confirmed {weapon}/{lod} asset ID {row['assetId']}")

    require(all("assetId" in row for row in rows.values()),
            "Incomplete weapon asset set; registry remains unchanged")
    ids = [rows[weapon, lod]["assetId"] for weapon in WEAPONS for lod in LODS]
    require(len(set(ids)) == len(ids),
            "Multiple authored weapons point to the same Roblox asset ID")
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
