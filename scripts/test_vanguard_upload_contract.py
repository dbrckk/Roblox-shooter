#!/usr/bin/env python3
"""Offline smoke test for VANGUARD uploader: no API key, Roblox calls or real assets."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/upload_vanguard_models.py"


def check(condition, label):
    if not condition:
        raise AssertionError(label)


def main():
    spec = importlib.util.spec_from_file_location("iy_asset_uploader", SCRIPT)
    uploader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(uploader)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        (root / "meshes").mkdir()
        (root / "textures").mkdir()
        (root / "manifest.json").write_text(
            json.dumps({"palette": ["olive", "sand", "slate", "rust"]}))
        (root / "textures" / "texture_manifest.json").write_text(
            json.dumps({"resolution": [1024, 1024]}))
        # A tiny but structurally correct seven-part GLB/PBR fixture; the
        # uploader now requires actual JSON geometry and PBR texture channels.
        from audit_vanguard_glb import PIECES
        metadata = {
            "asset": {"version": "2.0"},
            "nodes": [{"name": "VANGUARD_" + name, "mesh": i}
                      for i, name in enumerate(PIECES)],
            "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}
                       for _ in PIECES],
            "accessors": [{"componentType": 5126, "count": 3, "type": "VEC3"}],
            "materials": [{
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicRoughnessTexture": {"index": 1},
                },
                "normalTexture": {"index": 2},
            }] * 4,
            "textures": [{"source": i} for i in range(4)],
            "images": [{"bufferView": i, "mimeType": "image/png"}
                       for i in range(4)],
            "bufferViews": [{"byteOffset": 1024*i, "byteLength": 1024}
                            for i in range(4)],
            "buffers": [{"byteLength": 4096}],
        }
        json_bytes = json.dumps(metadata, separators=(",", ":")).encode("utf-8")
        json_bytes += b" " * (-len(json_bytes) % 4)
        binary = bytes(4096)
        chunks = (struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
                  + struct.pack("<I4s", len(binary), b"BIN\x00") + binary)
        content = struct.pack("<4sII", b"glTF", 2, 12 + len(chunks)) + chunks
        for palette in uploader.PALETTES:
            (root / "meshes" / f"vanguard_{palette}_LOD0.glb").write_bytes(content)

        module = root / "VanguardAssetIds.luau"
        module.write_text("return { ownerUserId = 9774173158 }")
        options = [
            sys.executable, str(SCRIPT), "--assets", str(root),
            "--owner-user-id", "9774173158",
            "--source-commit", "f" * 40,
            "--registry", str(root / "checkpoint.json"),
            "--module", str(module),
        ]
        completed = subprocess.run(options + ["--dry-run"],
                                   text=True, capture_output=True, check=False)
        check(completed.returncode == 0, completed.stderr)
        check("No Roblox request made" in completed.stdout,
              "Dry-run must explicitly avoid uploading")
        check(not (root / "checkpoint.json").exists(),
              "Dry-run must never claim asset registration")
        check("sourceCommit" not in module.read_text(),
              "Dry-run must not change the live Roblox model registry")
        # Deliberately break the first GLB. Upload validation must fail
        # without an API key before any Roblox network call or registry edit.
        first = root / "meshes" / "vanguard_olive_LOD0.glb"
        first.write_bytes(b"fake" * 1200)
        damaged = subprocess.run(options + ["--dry-run"],
                                 text=True, capture_output=True, check=False)
        check(damaged.returncode != 0,
              "Corrupt or textureless GLB must fail import preflight")
        first.write_bytes(content)

        invalid = subprocess.run(options[:options.index("--owner-user-id") + 1] +
                                 ["0"] + options[options.index("--owner-user-id") + 2:] +
                                 ["--dry-run"], text=True, capture_output=True, check=False)
        check(invalid.returncode != 0, "Invalid creator ID should fail closed")

        ids = {name: {"assetId": 100000 + i}
               for i, name in enumerate(uploader.PALETTES)}
        registry = uploader.render_registry(9774173158, "f" * 40, ids)
        check(all(f"{name} = {100000 + i}" in registry
                  for i, name in enumerate(uploader.PALETTES)),
              "Confirmed four model IDs must remain mapped to original palettes")
        check('ownerUserId = 9774173158' in registry,
              "Versioned asset registry loses creator ownership")
    print("IRON YARD Open Cloud asset importer offline security tests: OK")


if __name__ == "__main__":
    main()
