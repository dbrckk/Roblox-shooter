#!/usr/bin/env python3
"""Offline world-PBR source and uploader security regression (no Roblox key)."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "tools/assetforge"))
import upload_world_pbr_images as uploader
from generate_maps import write_png
from generate_world_maps import MATERIALS as WORLD_MATERIALS, CHANNELS as WORLD_CHANNELS, make_material


def check(flag, label):
    if not flag:
        raise AssertionError(label)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        short = root / "sample64"
        cmd = [sys.executable, str(ROOT / "tools/assetforge/generate_world_maps.py"),
               "--out", str(short), "--size", "64"]
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        example = json.loads((short / "manifest.json").read_text(encoding="utf-8"))
        check(example["sets"] == list(uploader.MATERIALS)
              and example["channels"] == list(uploader.CHANNELS),
              "Generator / uploader map inventories drifted")
        check(len(list(short.glob("*.png"))) == 12,
              "Original source exporter must bake exactly 12 images")
        for material in uploader.MATERIALS:
            color = short / (material + "_ColorMap.png")
            raw = color.read_bytes()
            check(hashlib.sha256(raw).hexdigest()
                  == example["files"][material]["ColorMap"]["sha256"],
                  "Source file manifest must pin real PNG bytes")
            check(raw[:8] == uploader.PNG_SIGNATURE,
                  "Expected genuine PNG, not a fake fixture")

        # Validate opposite borders for each actual 64px generated map.
        # Normal gradients must be periodic, not clamp-to-edge artifacts.
        for material in WORLD_MATERIALS:
            for channel in WORLD_CHANNELS:
                raw = (short / (material + "_" + channel + ".png")).read_bytes()
                pos = 8
                chunks = []
                while pos < len(raw):
                    length = int.from_bytes(raw[pos:pos+4], "big")
                    tag = raw[pos+4:pos+8]
                    data = raw[pos+8:pos+8+length]
                    pos += length + 12
                    if tag == b"IDAT":
                        chunks.append(data)
                    if tag == b"IEND":
                        break
                pixels = zlib.decompress(b"".join(chunks))
                stride = 1 + 64 * 4
                for y in range(64):
                    a = y * stride + 1
                    b = a + 63 * 4
                    check(max(abs(pixels[a+c] - pixels[b+c])
                              for c in range(3)) <= 16,
                          "Tileable texture has an obvious horizontal seam: "
                          + material + "/" + channel)
                for x in range(64):
                    a = 1 + x * 4
                    b = 63 * stride + 1 + x * 4
                    check(max(abs(pixels[a+c] - pixels[b+c])
                              for c in range(3)) <= 16,
                          "Tileable texture has an obvious vertical seam: "
                          + material + "/" + channel)

        # The uploader strictly rejects anything below 1024x1024.
        try:
            uploader.inspect_assets(short)
        except ValueError:
            pass
        else:
            raise AssertionError("A small prototype must never be uploaded")

        # Produce flat real 1K PNG fixture bytes without expensive full 1K
        # high-frequency normal generation in the everyday CI regression.
        full = root / "approved"
        full.mkdir()
        manifest = {
            "resolution": [1024, 1024],
            "sets": list(uploader.MATERIALS),
            "channels": list(uploader.CHANNELS),
            "files": {},
        }
        for material in uploader.MATERIALS:
            manifest["files"][material] = {}
            for channel in uploader.CHANNELS:
                filename = full / (material + "_" + channel + ".png")
                rgba = b"\x90\xa0\xa5\xff" if channel == "ColorMap" else b"\x80\x80\xff\xff"
                row = b"\x00" + rgba * 1024
                write_png(filename, 1024, 1024, row * 1024)
                raw = filename.read_bytes()
                manifest["files"][material][channel] = {
                    "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                }
                check(uploader.verify_png(raw), "Flat fixture is a valid 1K image")
        (full / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        info = uploader.inspect_assets(full)
        check(len(info) == 3
              and all(len(v) == 4 for v in info.values()), "Atomic 3x4 inventory")

        module = root / "WorldPbrAssetIds.luau"
        original = "return { ownerUserId = 9774173158 }\n"
        module.write_text(original, encoding="utf-8")
        registry = root / "checkpoint.json"
        args = [
            sys.executable, str(ROOT / "scripts/upload_world_pbr_images.py"),
            "--assets", str(full), "--owner-user-id", "9774173158",
            "--source-commit", "a" * 40,
            "--registry", str(registry), "--module", str(module),
        ]
        safe = subprocess.run(args + ["--dry-run"],
                              text=True, capture_output=True, check=False)
        check(safe.returncode == 0 and "no Roblox request made" in safe.stdout,
              "Dry run must verify 12 maps without any upload")
        check(not registry.exists() and module.read_text() == original,
              "Dry run must never publish partial/fictional image IDs")

        fake_ids = {}
        number = 500
        for material in uploader.MATERIALS:
            fake_ids[material] = {}
            for channel in uploader.CHANNELS:
                number += 1
                fake_ids[material][channel] = {"assetId": number}
        output = uploader.render_registry(9774173158, "a"*40, fake_ids)
        check(output.count("rbxassetid://") == 0
              and all(f"{channel} = " in output for channel in uploader.CHANNELS),
              "Generated Lua registry must use numeric IDs and four maps")

        missing = full / "freight_steel_NormalMap.png"
        missing.write_bytes(missing.read_bytes()[:-12] + b"\x00"*12)
        broken = subprocess.run(args + ["--dry-run"],
                                text=True, capture_output=True, check=False)
        check(broken.returncode != 0 and not registry.exists()
              and module.read_text() == original,
              "Tampering must fail before network or runtime activation")
        unknown_owner = subprocess.run(args[:args.index("--owner-user-id")+1]
            + ["0"] + args[args.index("--owner-user-id")+2:] + ["--dry-run"],
            text=True, capture_output=True, check=False)
        check(unknown_owner.returncode != 0, "Invalid creator must fail closed")
    print("IRON YARD true 1K world PBR generation, integrity and safe Open Cloud dry-run: OK")


if __name__ == "__main__":
    main()
