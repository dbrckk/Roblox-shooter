#!/usr/bin/env python3
"""Owner-authorized, checkpointed Open Cloud upload of world PBR Image assets.

Never accepts an API key on the command line and never activates partial maps.
The 12 images must be original, verified 1024x1024 RGBA8 PNGs with their
generated SHA-256 manifest and explicit owner confirmation.
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
import uuid
import zlib

from upload_vanguard_models import request_json
from asset_moderation import verify_asset, await_approval

BASE = "https://apis.roblox.com/assets/v1"
MATERIALS = ("freight_steel", "warehouse_steel", "yard_asphalt")
CHANNELS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
LIMIT = 20_000_000
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def require(ok, label):
    if not ok:
        raise ValueError(label)


def verify_png(raw):
    require(100 < len(raw) <= LIMIT and raw.startswith(PNG_SIGNATURE),
            "Invalid PNG or image exceeds Roblox 20MB asset limit")
    offset = 8
    width = height = 0
    chunks = []
    ended = False
    while offset + 12 <= len(raw):
        length = struct.unpack_from(">I", raw, offset)[0]
        tag = raw[offset+4:offset+8]
        offset += 8
        require(length <= LIMIT and offset + length + 4 <= len(raw),
                "Malformed PNG chunk size")
        payload = raw[offset:offset+length]
        crc = struct.unpack_from(">I", raw, offset+length)[0]
        require(zlib.crc32(tag + payload) & 0xffffffff == crc,
                "PNG CRC integrity failure")
        offset += length + 4
        if tag == b"IHDR":
            require(len(payload) == 13, "Invalid IHDR")
            width, height, depth, kind, comp, filter_type, interlace = struct.unpack(
                ">IIBBBBB", payload)
            require((width, height) == (1024, 1024)
                    and (depth, kind, comp, filter_type, interlace) == (8, 6, 0, 0, 0),
                    "Roblox world map must be exactly 1024x1024 RGBA8 PNG")
        elif tag == b"IDAT":
            chunks.append(payload)
        elif tag == b"IEND":
            ended = True
            break
    require(ended and offset == len(raw) and chunks,
            "Truncated, extra-data or missing PNG image content")
    inflater = zlib.decompressobj()
    expected = 1024 * (1024 * 4 + 1)
    pixels = inflater.decompress(b"".join(chunks), expected + 1)
    require(inflater.eof and not inflater.unconsumed_tail
            and len(pixels) == expected and len(inflater.flush()) == 0,
            "Incorrect or oversized decompressed RGBA scanlines")
    for y in range(1024):
        require(pixels[y * (1024*4+1)] == 0,
                "Unexpected PNG row filter")
    return True


def inspect_assets(folder):
    manifest_path = folder / "manifest.json"
    require(manifest_path.is_file(), "Missing generated 1K world PBR manifest")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(manifest.get("resolution") == [1024, 1024]
            and manifest.get("sets") == list(MATERIALS)
            and manifest.get("channels") == list(CHANNELS),
            "Only three pinned 1K four-map world materials may be uploaded")
    result = {}
    for material in MATERIALS:
        result[material] = {}
        for channel in CHANNELS:
            name = material + "_" + channel
            file = folder / (name + ".png")
            require(file.is_file(), "Missing original PNG: " + name)
            raw = file.read_bytes()
            verify_png(raw)
            digest = hashlib.sha256(raw).hexdigest()
            expected = manifest.get("files", {}).get(material, {}).get(channel, {})
            require(digest == expected.get("sha256")
                    and len(raw) == expected.get("bytes"),
                    "PBR PNG manifest hash mismatch: " + name)
            result[material][channel] = {"sha256": digest, "bytes": len(raw)}
    return result


def upload_one(key, owner, material, channel, raw):
    boundary = "IY-" + uuid.uuid4().hex
    meta = json.dumps({
        "assetType": "Image",
        "displayName": "IRON YARD " + material.upper() + " " + channel,
        "description": "Original 1024px industrial world PBR image.",
        "creationContext": {"creator": {"userId": owner}},
    }, separators=(",", ":")).encode("utf-8")
    request = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="request"\r\n'
        "Content-Type: application/json\r\n\r\n"
    ).encode("ascii") + meta + b"\r\n" + (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="fileContent"; filename="{material}_{channel}.png"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode("ascii") + raw + f"\r\n--{boundary}--\r\n".encode("ascii")
    op = request_json(BASE + "/assets", key, payload=request,
                      content_type="multipart/form-data; boundary=" + boundary)
    path = op.get("path", "")
    require(isinstance(path, str)
            and re.fullmatch(r"operations/[A-Za-z0-9_./-]+", path),
            "Roblox returned no valid Image processing operation")
    for _ in range(45):
        if op.get("done"):
            if op.get("error"):
                raise RuntimeError("Roblox Image processing rejected the uploaded map")
            row = op.get("response")
            require(isinstance(row, dict), "Completed Image operation missing response")
            asset_id = int(row.get("assetId", 0))
            require(asset_id > 0, "Image operation returned invalid ID")
            moderation = verify_asset(row, asset_id, owner)
            return asset_id, moderation
        time.sleep(3)
        op = request_json(BASE + "/" + path, key)
    raise TimeoutError("Roblox Image processing still pending, activation withheld")


def render_registry(owner, source_commit, assets):
    lines = [
        "-- IRON YARD / twelve owner-approved world PBR Image IDs.",
        "-- Generated only after successful full Open Cloud processing.",
        "return {",
        f"    ownerUserId = {owner},",
        f'    sourceCommit = "{source_commit}",',
        "    materials = {",
    ]
    for material in MATERIALS:
        lines.append("        " + material + " = {")
        for channel in CHANNELS:
            lines.append(f"            {channel} = {int(assets[material][channel]['assetId'])},")
        lines.append("        },")
    return "\n".join(lines + ["    },", "}", ""])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", required=True, type=Path)
    ap.add_argument("--owner-user-id", required=True, type=int)
    ap.add_argument("--source-commit", required=True)
    ap.add_argument("--registry", required=True, type=Path)
    ap.add_argument("--module", required=True, type=Path)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    require(args.owner_user_id > 0 and
            re.fullmatch(r"[a-f0-9]{40}", args.source_commit),
            "World PBR requires verified Roblox owner and source commit")
    assets = inspect_assets(args.assets)
    if args.dry_run:
        print("Validated 12 original 1K PBR PNG maps; no Roblox request made.")
        return 0

    key = os.environ.get("ROBLOX_OPEN_CLOUD_ASSETS_KEY", "")
    require(key != "", "Secret ROBLOX_OPEN_CLOUD_ASSETS_KEY is not configured")
    require(args.module.is_file()
            and f"ownerUserId = {args.owner_user_id}" in
            args.module.read_text(encoding="utf-8"),
            "PBR registry owner must match authorized Roblox creator")

    previous = {}
    if args.registry.is_file():
        saved = json.loads(args.registry.read_text(encoding="utf-8"))
        if (saved.get("ownerUserId") == args.owner_user_id
                and saved.get("sourceCommit") == args.source_commit):
            previous = saved.get("assets", {})

    def checkpoint():
        args.registry.parent.mkdir(parents=True, exist_ok=True)
        args.registry.write_text(json.dumps({
            "ownerUserId": args.owner_user_id,
            "sourceCommit": args.source_commit,
            "assets": assets,
        }, indent=2) + "\n", encoding="utf-8")

    for material in MATERIALS:
        for channel in CHANNELS:
            row = previous.get(material, {}).get(channel, {})
            item = assets[material][channel]
            if (row.get("sha256") == item["sha256"]
                    and isinstance(row.get("assetId"), int) and row["assetId"] > 0):
                asset_id = row["assetId"]
                item["assetId"] = asset_id
                item["moderation"] = row.get("moderation", "REVIEWING")
                checkpoint()
                await_approval(BASE, asset_id, args.owner_user_id, key, request_json)
            else:
                raw = (args.assets / f"{material}_{channel}.png").read_bytes()
                asset_id, status = upload_one(key, args.owner_user_id,
                                              material, channel, raw)
                item["assetId"] = asset_id
                item["moderation"] = status
                checkpoint()
                print(f"Roblox Image {material}/{channel}: created "
                      f"assetId={asset_id}, moderation={status}")
                if status != "APPROVED":
                    await_approval(BASE, asset_id, args.owner_user_id,
                                   key, request_json)
            item["moderation"] = "APPROVED"
            checkpoint()
            print("Image approved: " + material + "/" + channel)
    require(all(int(assets[m][c].get("assetId", 0)) > 0
                and assets[m][c].get("moderation") == "APPROVED"
                for m in MATERIALS for c in CHANNELS),
            "Incomplete or unapproved twelve-image PBR upload")
    args.module.write_text(render_registry(
        args.owner_user_id, args.source_commit, assets), encoding="utf-8")
    print("All 12 Roblox Image IDs confirmed; world PBR registry generated.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, RuntimeError, TimeoutError,
            json.JSONDecodeError, zlib.error) as exc:
        print("World PBR upload not completed: " + str(exc), file=sys.stderr)
        sys.exit(1)
