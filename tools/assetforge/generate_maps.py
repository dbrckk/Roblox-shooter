#!/usr/bin/env python3
"""Original, deterministic VANGUARD PBR image maps. Python standard library only.
NormalMap = linear-ish tangent XYZ as RGB, RoughnessMap = grayscale, MetalnessMap = grayscale.
The combined M/R texture required by glTF is assembled by the glTF exporter from node inputs.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import zlib

PALETTES = {
    "cyan": (46, 209, 239),
    "amber": (247, 151, 61),
    "violet": (175, 120, 250),
    "emerald": (93, 235, 146),
}
BASES = {
    "armor": (56, 73, 91, 212, 78),
    "carbon": (22, 31, 43, 35, 186),
    "gunmetal": (88, 103, 115, 220, 93),
    "visor": (16, 36, 52, 96, 52),
}

def write_png(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    compressed = zlib.compress(pixels, level=8)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
        chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
        chunk(b"IDAT", compressed) + chunk(b"IEND", b""))

def hash_noise(x, y, seed):
    v = ((x * 374761393) ^ (y * 668265263) ^ (seed * 1442695041)) & 0xffffffff
    v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
    return (v ^ (v >> 16)) & 255

def clamp(x):
    return max(0, min(255, int(x)))

def generate(name, base, out, size, is_accent=False):
    r, g, b, metal, rough = base
    tracks = {key: bytearray() for key in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")}
    seed = sum(ord(c) for c in name)
    for y in range(size):
        for track in tracks.values():
            track.append(0)  # PNG filter byte: none
        for x in range(size):
            n = (hash_noise(x, y, seed) - 127.5) / 127.5
            grain = math.sin((y + x * 0.065) * 0.21) * 0.32
            seam_x = x % 128
            seam_y = y % 128
            seam = seam_x < 3 or seam_y < 3
            subtle = int((n * 0.6 + grain) * 15)
            darken = -15 if seam and not is_accent else 0
            color = (clamp(r + subtle + darken), clamp(g + subtle + darken), clamp(b + subtle + darken), 255)
            normal = (
                clamp(128 + n * (3 if is_accent else 12)),
                clamp(128 + math.cos((x + y * 0.09) * 0.09) * (2 if is_accent else 9)),
                255, 255,
            )
            rough_val = clamp(rough + n * 13 + (15 if seam else 0))
            metal_val = clamp(metal - (12 if seam else 0))
            tracks["ColorMap"].extend(color)
            tracks["NormalMap"].extend(normal)
            tracks["RoughnessMap"].extend((rough_val, rough_val, rough_val, 255))
            tracks["MetalnessMap"].extend((metal_val, metal_val, metal_val, 255))
    for channel, pixels in tracks.items():
        write_png(out / (name + "_" + channel + ".png"), size, size, pixels)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--size", type=int, default=512)
    args = parser.parse_args()
    if args.size < 64 or args.size > 2048 or args.size & (args.size - 1):
        parser.error("size must be a power of two from 64 to 2048")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for name, base in BASES.items():
        generate(name, base, out, args.size)
    for name, color in PALETTES.items():
        generate("accent_" + name, (*color, 24, 55), out, args.size, is_accent=True)
    (out / "texture_manifest.json").write_text(json.dumps({
        "license": "Original textures, NEON STRIKE",
        "resolution": [args.size, args.size],
        "palettes": PALETTES,
        "channel_maps": ["ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"],
        "sets": list(BASES) + ["accent_" + x for x in PALETTES],
    }, indent=2), encoding="utf-8")
    print("Wrote", len(BASES) + len(PALETTES), "PBR sets to", out)

if __name__ == "__main__":
    main()
