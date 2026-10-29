#!/usr/bin/env python3
"""Optional owner-authorized Open Cloud importer for original VANGUARD GLB kits.

Uploads FOUR finished Blender GLBs as Roblox *Model* assets, never claiming
that uploaded MeshParts are usable until Roblox finishes processing them.
No account cookie required. No key is printed or accepted as a CLI argument.
Only an explicitly authorized user ID and four pinned palette names are used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys
import time
import urllib.error
import urllib.request
import uuid

from audit_vanguard_glb import inspect as inspect_glb

API = "https://apis.roblox.com/assets/v1"
PALETTES = ("olive", "sand", "slate", "rust")
MAX_MODEL_BYTES = 20_000_000


def require(condition, message):
    if not condition:
        raise ValueError(message)


def model_info(folder, palette):
    path = folder / "meshes" / f"vanguard_{palette}_LOD0.glb"
    require(path.is_file(), f"Missing original GLB model: {path}")
    raw = path.read_bytes()
    require(1024 < len(raw) <= MAX_MODEL_BYTES,
            f"Roblox model upload must be below 20 MB: {path} ({len(raw)} bytes)")
    magic, version, length = struct.unpack_from("<4sII", raw)
    require(magic == b"glTF" and version == 2 and length == len(raw),
            f"Corrupted or non-GLB2 model: {path}")
    # Check the ACTUAL GLB mesh parts and all physically based material maps
    # before spending any owner-authorized Roblox upload budget.
    inspect_glb(path)
    return path, raw, hashlib.sha256(raw).hexdigest()


def request_json(url, key, *, payload=None, content_type=None):
    headers = {"x-api-key": key, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=payload, headers=headers,
                                 method="POST" if payload is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=75) as res:
            require(res.status in (200, 201, 202), f"Unexpected HTTP {res.status}")
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        # Never echo API keys or raw multipart contents on an upload failure.
        raise RuntimeError(f"Roblox asset API returned HTTP {err.code}") from None


def upload_one(owner, palette, raw, key):
    boundary = "IY-" + uuid.uuid4().hex
    info = json.dumps({
        "assetType": "Model",
        "displayName": f"IRON YARD VANGUARD {palette.upper()} LOD0 PBR",
        "description": "Original modular seven-piece tactical model with authored 1K PBR maps.",
        "creationContext": {"creator": {"userId": owner}},
    }, separators=(",", ":")).encode("utf-8")
    beginning = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="request"\r\n'
        "Content-Type: application/json\r\n\r\n"
    ).encode("ascii") + info + b"\r\n" + (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileContent"; filename="vanguard_{palette}.glb"\r\n'
        "Content-Type: model/gltf-binary\r\n\r\n"
    ).encode("ascii")
    multipart = beginning + raw + f"\r\n--{boundary}--\r\n".encode("ascii")
    operation = request_json(API + "/assets", key, payload=multipart,
                             content_type=f"multipart/form-data; boundary={boundary}")
    path = operation.get("path", "")
    require(isinstance(path, str) and re.fullmatch(r"operations/[A-Za-z0-9_./-]+", path),
            "Roblox response did not include a valid asset operation path")
    # Asset creation can be asynchronous; poll the documented operation API.
    for _ in range(45):
        if operation.get("done"):
            if operation.get("error"):
                raise RuntimeError("Roblox asset processing rejected the upload")
            response = operation.get("response")
            require(isinstance(response, dict), "Completed operation missing asset response")
            asset_id = int(response.get("assetId", 0))
            require(asset_id > 0, "Completed operation returned no valid asset ID")
            moderation = (response.get("moderationResult") or {}).get("moderationState")
            require(moderation in (None, "MODERATION_STATE_APPROVED"),
                    "Asset is not yet approved; avoid activating it automatically")
            creator = (response.get("creationContext") or {}).get("creator") or {}
            require(str(creator.get("userId")) == str(owner),
                    "Roblox asset creator differs from confirmed owner")
            return asset_id
        time.sleep(3)
        operation = request_json(API + "/" + path, key)
    raise TimeoutError("Model asset processing has not completed; no asset IDs activated")


def render_registry(owner, source_commit, models):
    lines = [
        "-- IRON YARD / confirmed uploaded VANGUARD Model asset IDs.",
        "-- These are owned assets; never edit them using client-supplied data.",
        "return {",
        f"    ownerUserId = {owner},",
        f'    sourceCommit = "{source_commit}",',
        "    paletteModelIds = {",
    ]
    for palette in PALETTES:
        lines.append(f"        {palette} = {models[palette]['assetId']},")
    return "\n".join(lines + ["    },", "}", ""])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--owner-user-id", type=int, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--module", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    require(args.owner_user_id > 0, "A real Roblox creator user ID is required")
    require(re.fullmatch(r"[0-9a-f]{40}", args.source_commit),
            "Source commit must be a verified forty-hex Git SHA")
    manifest = json.loads((args.assets / "manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("palette") == list(PALETTES),
            "The Blender archive does not contain the approved four skin palettes")
    tex = json.loads((args.assets / "textures" / "texture_manifest.json").read_text(encoding="utf-8"))
    require(tex.get("resolution") == [1024, 1024], "Source textures are not 1K PBR")

    models = {}
    for palette in PALETTES:
        _, raw, digest = model_info(args.assets, palette)
        models[palette] = {"sha256": digest, "bytes": len(raw)}
    if args.dry_run:
        print("Validated four VANGUARD GLB2 files (1024px PBR), dry-run only.")
        for palette, info in models.items():
            print(f"  {palette}: {info['bytes']} bytes, sha256={info['sha256']}")
        print("No Roblox request made; no asset IDs or completed upload claimed.")
        return 0

    key = os.environ.get("ROBLOX_OPEN_CLOUD_ASSETS_KEY", "")
    require(key != "", "GitHub secret ROBLOX_OPEN_CLOUD_ASSETS_KEY is not configured")
    require(args.module.exists(), "Expected versioned client asset registry is missing")
    current = args.module.read_text(encoding="utf-8")
    require(f"ownerUserId = {args.owner_user_id}" in current,
            "Selected Roblox owner differs from the repository's verified owner")

    # The registry is checkpointed after EACH successful upload to make failures
    # inspectable. Do not switch the game's model IDs until ALL FOUR succeeded.
    previous = {}
    if args.registry.is_file():
        old = json.loads(args.registry.read_text(encoding="utf-8"))
        if old.get("ownerUserId") == args.owner_user_id and old.get("sourceCommit") == args.source_commit:
            previous = old.get("models", {})
    for palette in PALETTES:
        row = previous.get(palette, {})
        if row.get("sha256") == models[palette]["sha256"] and int(row.get("assetId", 0)) > 0:
            models[palette]["assetId"] = int(row["assetId"])
            continue
        _, raw, _ = model_info(args.assets, palette)
        models[palette]["assetId"] = upload_one(args.owner_user_id, palette, raw, key)
        args.registry.parent.mkdir(parents=True, exist_ok=True)
        args.registry.write_text(json.dumps({
            "ownerUserId": args.owner_user_id,
            "sourceCommit": args.source_commit,
            "models": models,
        }, indent=2) + "\n", encoding="utf-8")
        print(f"Roblox Model asset created for {palette}; ID confirmed by Open Cloud.")

    require(all(int(models[x].get("assetId", 0)) > 0 for x in PALETTES),
            "Incomplete VANGUARD upload; not activating models")
    args.module.write_text(render_registry(args.owner_user_id, args.source_commit, models),
                           encoding="utf-8")
    print("Four owner-authorized GLB Model assets confirmed; Lua model registry generated.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, RuntimeError, TimeoutError) as exc:
        print("VANGUARD upload not completed: " + str(exc), file=sys.stderr)
        sys.exit(1)
