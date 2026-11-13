#!/usr/bin/env python3
"""Verify all twelve already-approved Roblox Image IDs before invoking a retry.

A complete owner/source/checksum-pinned checkpoint is mandatory. The existing
upload script will then use GET /assets/{id} for each row and issue ZERO POSTs.
"""
import argparse
import json
from pathlib import Path

OWNER = 9774173158
SOURCE = "903deaafacc29011972b86cbea117bd52d211b76"
MATERIALS = ("freight_steel", "warehouse_steel", "yard_asphalt")
CHANNELS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")


def verify(saved, manifest):
    if saved.get("ownerUserId") != OWNER or saved.get("sourceCommit") != SOURCE:
        raise ValueError("Wrong Roblox owner or original source SHA")
    if (manifest.get("resolution") != [1024, 1024] or
            manifest.get("sets") != list(MATERIALS) or
            manifest.get("channels") != list(CHANNELS)):
        raise ValueError("Incorrect original 1K PBR source manifest")
    files = manifest.get("files")
    assets = saved.get("assets")
    if (not isinstance(files, dict) or set(files) != set(MATERIALS)
            or not isinstance(assets, dict) or set(assets) != set(MATERIALS)):
        raise ValueError("Missing or unexpected world PBR materials")
    ids = set()
    for material in MATERIALS:
        if set(files[material]) != set(CHANNELS) or set(assets[material]) != set(CHANNELS):
            raise ValueError("Missing or unexpected PBR channel")
        for channel in CHANNELS:
            item = assets[material][channel]
            original = files[material][channel]
            if (item.get("sha256") != original.get("sha256") or
                    item.get("bytes") != original.get("bytes")):
                raise ValueError("Image differs from the original audited source")
            n = item.get("assetId")
            if not isinstance(n, int) or isinstance(n, bool) or n <= 0 or n in ids:
                raise ValueError("Unconfirmed or duplicate Roblox Image ID")
            if item.get("moderation") != "APPROVED":
                raise ValueError("This Roblox Image was not approved")
            ids.add(n)
    if len(ids) != 12:
        raise ValueError("A partial image upload would attempt new POSTs")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, required=True)
    args = ap.parse_args()
    saved = json.loads(args.checkpoint.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    verify(saved, manifest)
    print("Twelve distinct already-approved Roblox IDs; safe checkpoint replay.")


if __name__ == "__main__":
    main()
