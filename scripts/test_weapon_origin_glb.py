#!/usr/bin/env python3
"""Negative tests on actual Blender-exported GLB weapon origin markers.

Uses the generated real binary source (not a fake fixture), corrupting one
JSON chunk at a time while keeping its GLB2 binary and chunk lengths valid.
"""
import json
from pathlib import Path
import struct
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "weaponforge"))
from validate_weapon_exports import ORIGIN_NAME, REQUIRED, inspect  # noqa: E402


def alter(source, operation):
    payload = source.read_bytes()
    assert payload[:4] == b"glTF"
    json_size, kind = struct.unpack_from("<I4s", payload, 12)
    assert kind == b"JSON"
    obj = json.loads(payload[20:20 + json_size])
    operation(obj)
    encoded = json.dumps(obj, separators=(",", ":")).encode("utf8")
    encoded += b" " * ((-len(encoded)) % 4)
    binary = payload[20 + json_size:]
    result = struct.pack("<4sII", b"glTF", 2, 20 + len(encoded) + len(binary))
    return result + struct.pack("<I4s", len(encoded), b"JSON") + encoded + binary


def marker(obj):
    return next(n for n in obj["nodes"] if n.get("name") == ORIGIN_NAME
                and "mesh" in n)


def rejects(source, weapon, change):
    data = alter(source, change)
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "damaged.glb"
        path.write_bytes(data)
        try:
            inspect(path, weapon)
        except (ValueError, KeyError):
            return
        raise AssertionError("Weapon forge accepted a corrupted authored origin")


def main(folder):
    meshes = Path(folder) / "meshes"
    for weapon in REQUIRED:
        for lod in ("LOD0", "LOD1"):
            model = meshes / f"iron_yard_{weapon}_{lod}.glb"
            result = inspect(model, weapon)
            assert result["originMarker"] == ORIGIN_NAME
            assert 12 <= result["originTriangles"] <= 40
    pistol = meshes / "iron_yard_pistol_LOD0.glb"
    sniper = meshes / "iron_yard_sniper_LOD1.glb"
    rejects(pistol, "pistol", lambda j: marker(j).update({"name": "Omitted"}))
    rejects(pistol, "pistol",
            lambda j: marker(j).update({"translation": [0, 1, 0]}))
    rejects(sniper, "sniper",
            lambda j: marker(j).update({"scale": [2, 1, 1]}))
    def oversize(j):
        source = marker(j)["mesh"]
        accessor = j["meshes"][source]["primitives"][0]["attributes"]["POSITION"]
        j["accessors"][accessor]["max"][0] = 3.0
    rejects(sniper, "sniper", oversize)
    print("IRON YARD: all 10 real GLBs anchored; missing, moved, scaled and "
          "oversized origins rejected")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: test_weapon_origin_glb.py <weapon-kit-directory>")
    main(sys.argv[1])
