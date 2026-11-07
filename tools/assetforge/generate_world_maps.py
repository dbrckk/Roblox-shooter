#!/usr/bin/env python3
"""Original 1K, four-channel tileable Roblox world PBR textures.

Three distinct authored materials: painted corrugated freight steel,
warm steel warehouse cladding and granular industrial asphalt. No third-party
textures or Blender dependencies; deterministic RGBA PNG outputs and hashes.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from generate_maps import clamp, hash_noise, write_png

MATERIALS = {
    "freight_steel": {"base": (124, 141, 142), "metal": 225, "rough": 128, "seed": 17},
    "warehouse_steel": {"base": (160, 159, 145), "metal": 222, "rough": 155, "seed": 43},
    "yard_asphalt": {"base": (115, 117, 110), "metal": 4, "rough": 230, "seed": 91},
}
CHANNELS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")


def sample(name, x, y, size, cfg):
    seed = cfg["seed"]
    grain = (hash_noise(x // 3, y // 3, seed) - 127.5) / 127.5
    coarse = (hash_noise(x // 19, y // 17, seed + 29) - 127.5) / 127.5
    brush = math.sin((y + seed) * 0.13) * 0.28
    if name == "yard_asphalt":
        # Aggregate and rough microstones, with no false gridded panel seams.
        stone = hash_noise(x // 6, y // 6, seed + 71) > 207
        raise_height = (grain * 2.7 + coarse * 3.0 + (3 if stone else 0))
        delta = grain * 13 + coarse * 10 + (18 if stone else 0)
        rough = cfg["rough"] - (20 if stone else 0) + grain * 6
        metal = cfg["metal"]
    else:
        # Long folded sheet ribs: aligned across repeated 1024px tiles.
        pitch = max(16, size // 8)
        offset = x % pitch
        seam = offset <= 2 or offset >= pitch - 3
        raised = offset in (3, 4, pitch - 5, pitch - 4)
        scratch = ((x * 5 + y + seed * 11) % 311 < 2
            and hash_noise(x // 31, y // 21, seed + 13) > 151)
        oxide = (hash_noise(x // 21, y // 29, seed + 57) > 242)
        raise_height = grain * 1.2 + coarse * 2.0 + (6 if raised else 0)
        raise_height -= (12 if seam else 0) + (4 if scratch else 0)
        delta = grain * 7 + coarse * 8 + brush * 3
        delta += -21 if seam else (8 if raised else 0)
        delta += -14 if scratch else 0
        delta += -18 if oxide else 0
        rough = cfg["rough"] + (32 if oxide else 0) + grain * 7
        metal = cfg["metal"] - (145 if oxide else 0)
    return raise_height, delta, rough, metal


def make_material(name, cfg, out, size):
    height = [0.0] * (size * size)
    pixels = {channel: bytearray(size * size * 4) for channel in CHANNELS}
    for y in range(size):
        for x in range(size):
            elevation, delta, rough, metal = sample(name, x, y, size, cfg)
            i = y * size + x
            height[i] = elevation
            p = 4 * i
            base = cfg["base"]
            pixels["ColorMap"][p:p+4] = bytes((
                clamp(base[0] + delta),
                clamp(base[1] + delta),
                clamp(base[2] + delta),
                255,
            ))
            r = clamp(rough)
            m = clamp(metal)
            pixels["RoughnessMap"][p:p+4] = bytes((r, r, r, 255))
            pixels["MetalnessMap"][p:p+4] = bytes((m, m, m, 255))

    normals = pixels["NormalMap"]
    strength = 0.069 if name != "yard_asphalt" else 0.082
    for y in range(size):
        north = max(0, y - 1) * size
        south = min(size - 1, y + 1) * size
        for x in range(size):
            left = max(0, x - 1)
            right = min(size - 1, x + 1)
            dx = (height[y * size + left] - height[y * size + right]) * strength
            dy = (height[north + x] - height[south + x]) * strength
            length = math.sqrt(dx * dx + dy * dy + 1)
            p = (y * size + x) * 4
            normals[p:p+4] = bytes((
                clamp((dx / length * 0.5 + 0.5) * 255),
                clamp((dy / length * 0.5 + 0.5) * 255),
                clamp((1 / length * 0.5 + 0.5) * 255),
                255,
            ))

    hashes = {}
    for channel, rgba in pixels.items():
        scans = bytearray()
        for y in range(size):
            scans.append(0)
            scans.extend(rgba[4*y*size:4*(y+1)*size])
        path = out / f"{name}_{channel}.png"
        write_png(path, size, size, scans)
        raw = path.read_bytes()
        hashes[channel] = {"sha256": hashlib.sha256(raw).hexdigest(),
                           "bytes": len(raw)}
    return hashes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--size", type=int, default=1024)
    args = parser.parse_args()
    if args.size < 64 or args.size > 2048 or args.size & (args.size-1):
        parser.error("size must be power-of-two in [64, 2048]")
    args.out.mkdir(parents=True, exist_ok=True)
    hashes = {name: make_material(name, cfg, args.out, args.size)
              for name, cfg in MATERIALS.items()}
    (args.out / "manifest.json").write_text(json.dumps({
        "license": "Original authored textures for IRON YARD",
        "resolution": [args.size, args.size],
        "sets": list(MATERIALS),
        "channels": list(CHANNELS),
        "files": hashes,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Validated source output: {len(MATERIALS)} original 4-map materials at {args.size}px")


if __name__ == "__main__":
    main()
