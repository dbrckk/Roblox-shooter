#!/usr/bin/env python3
"""IRON YARD VANGUARD — original, deterministic 2D PBR texture bake.

Generates physically consistent tangent-space normal gradients from procedural
height samples, panel joins, chamfer wear, brushed metal and localized scuffs.
No third-party textures or external dependencies.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import zlib

PALETTES = {
    "olive": (124, 145, 91),
    "sand": (205, 180, 135),
    "slate": (105, 128, 142),
    "rust": (168, 99, 74),
}
# RGBA base + metallic / roughness scalar, 0-255.
BASES = {
    "armor": (109, 115, 104, 152, 143),
    "carbon": (44, 50, 45, 12, 203),
    "gunmetal": (88, 97, 97, 211, 107),
    "visor": (58, 78, 85, 7, 72),
}

def clamp(number):
    return max(0, min(255, int(round(number))))

def write_png(path, width, height, pixels):
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
    compressed = zlib.compress(pixels, level=8)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n" +
        chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
        chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    )

def hash_noise(x, y, seed):
    # Independent of Python's randomized hash seed, stable in CI on every machine.
    value = ((x * 374761393) ^ (y * 668265263) ^ (seed * 1442695041)) & 0xffffffff
    value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
    return (value ^ (value >> 16)) & 255

def material_sample(x, y, seed, size, accent, category):
    # Physical panel grid: panel boundaries have a darker, lower relief seam.
    cell = max(32, size // 4)
    px = x % cell
    py = y % cell
    seam = px <= 2 or py <= 2
    # Three-pixel chamfers produce highlights without requiring additional geometry.
    bevel = px in (3, 4, cell - 2, cell - 3) or py in (3, 4, cell - 2, cell - 3)
    micro = (hash_noise(x, y, seed) - 127.5) / 127.5
    grain = (hash_noise(x // 4, y // 3, seed + 37) - 127.5) / 127.5
    # Brushed-direction bands are subtle, with different amplitudes for fabric/visor.
    brushed = math.sin(y * 0.18 + seed * 0.07) * (0.55 if category == "gunmetal" else 0.23)
    # Intermittent scratches follow a diagonal stroke and are spatially gated.
    stroke = ((x * 7 + y * 3 + seed * 11) % 173) < 2
    scratch = (not accent and category != "visor" and stroke and
               hash_noise(x // 29, y // 17, seed + 129) > 171)
    # Small flakes are constrained to a few patches, not white-noise everywhere.
    chip = (not accent and category != "carbon" and
            hash_noise(x // 5, y // 5, seed + 17) > 248 and
            hash_noise(x // 11, y // 13, seed + 67) > 182)
    if accent:
        # Light strips are intentionally glossy and mostly smooth.
        height = micro * 0.4 + brushed * 0.2
        delta = micro * 2
        rough_delta = micro * 4
        metallic_delta = 0
    else:
        height = (micro * 3 + grain * 2 + brushed * 2.1 -
                  (19 if seam else 0) + (7 if bevel else 0) -
                  (10 if scratch else 0) - (6 if chip else 0))
        delta = (micro * 7 + grain * 5 + brushed * 4 -
                 (20 if seam else 0) + (15 if bevel else 0) +
                 (16 if scratch else 0) + (21 if chip else 0))
        rough_delta = (micro * 6 + grain * 5 +
                       (38 if seam else 0) + (22 if scratch else 0) +
                       (25 if chip else 0))
        metallic_delta = -(24 if seam else 0) - (26 if chip else 0)
    return height, delta, rough_delta, metallic_delta

def generate(name, base, out, size, accent=False):
    r, g, b, metal, rough = base
    tracks = {key: bytearray() for key in
              ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")}
    seed = sum(ord(char) for char in name)

    # Heightmap stored as one compact numeric plane. Normals use actual height
    # differences, unlike arbitrarily assigned RGB normal components.
    height = [0.0] * (size * size)
    albedo = bytearray(size * size * 4)
    rough_pixels = bytearray(size * size * 4)
    metal_pixels = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            i = y * size + x
            surface, color_delta, rough_delta, metal_delta = material_sample(
                x, y, seed, size, accent, name
            )
            height[i] = surface
            pos = i * 4
            albedo[pos:pos + 4] = bytes((
                clamp(r + color_delta),
                clamp(g + color_delta),
                clamp(b + color_delta),
                255,
            ))
            rough_val = clamp(rough + rough_delta)
            metal_val = clamp(metal + metal_delta)
            rough_pixels[pos:pos + 4] = bytes((rough_val, rough_val, rough_val, 255))
            metal_pixels[pos:pos + 4] = bytes((metal_val, metal_val, metal_val, 255))

    normal_pixels = bytearray(size * size * 4)
    strength = 0.030 if accent else 0.060
    for y in range(size):
        north = max(0, y - 1) * size
        south = min(size - 1, y + 1) * size
        for x in range(size):
            left = max(0, x - 1)
            right = min(size - 1, x + 1)
            idx = y * size + x
            dx = (height[y * size + left] - height[y * size + right]) * strength
            dy = (height[north + x] - height[south + x]) * strength
            norm = math.sqrt(dx * dx + dy * dy + 1)
            pos = idx * 4
            normal_pixels[pos:pos + 4] = bytes((
                clamp((dx / norm * 0.5 + 0.5) * 255),
                clamp((dy / norm * 0.5 + 0.5) * 255),
                clamp((1.0 / norm * 0.5 + 0.5) * 255),
                255,
            ))

    payloads = {
        "ColorMap": albedo,
        "NormalMap": normal_pixels,
        "RoughnessMap": rough_pixels,
        "MetalnessMap": metal_pixels,
    }
    for channel, rgba in payloads.items():
        scanlines = bytearray()
        for y in range(size):
            scanlines.append(0)  # PNG row filter None
            scanlines.extend(rgba[y * size * 4:(y + 1) * size * 4])
        write_png(out / (name + "_" + channel + ".png"),
                  size, size, scanlines)

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
        generate("accent_" + name, (*color, 24, 145), out, args.size, accent=True)
    (out / "texture_manifest.json").write_text(json.dumps({
        "license": "Original textures authored for IRON YARD",
        "resolution": [args.size, args.size],
        "palettes": PALETTES,
        "channel_maps": ["ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"],
        "sets": list(BASES) + ["accent_" + key for key in PALETTES],
        "techniques": [
            "physically linked tangent-space normal gradients",
            "panel grooves and bevel edge wear",
            "directional brushed microtexture",
            "localized scratches and plating chips",
            "per-material roughness and metallic variability",
        ],
    }, indent=2), encoding="utf-8")
    print("Generated", len(BASES) + len(PALETTES), "PBR materials at", args.size)

if __name__ == "__main__":
    main()
