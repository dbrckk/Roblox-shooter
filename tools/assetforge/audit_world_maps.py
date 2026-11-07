#!/usr/bin/env python3
"""Decode and verify authored world PBR appearance; export a visual contact sheet.

Standard library only. This is an aesthetic/physical plausibility gate in
addition to the separate Roblox image integrity and owner checks.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

from generate_maps import write_png
from generate_world_maps import CHANNELS, MATERIALS


def require(value, message):
    if not value:
        raise ValueError(message)


def decode_png(path, side):
    raw = path.read_bytes()
    require(raw.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid PNG signature: " + str(path))
    pos = 8
    packed = []
    seen_ihdr = False
    seen_end = False
    while pos + 12 <= len(raw):
        length = struct.unpack_from(">I", raw, pos)[0]
        tag = raw[pos+4:pos+8]
        require(length <= 20_000_000 and pos+12+length <= len(raw),
                "Invalid PNG chunk length: " + str(path))
        data = raw[pos+8:pos+8+length]
        crc = struct.unpack_from(">I", raw, pos+8+length)[0]
        require((zlib.crc32(tag + data) & 0xffffffff) == crc,
                "PNG CRC mismatch: " + str(path))
        pos += 12 + length
        if tag == b"IHDR":
            require(len(data) == 13
                    and struct.unpack(">IIBBBBB", data) ==
                    (side, side, 8, 6, 0, 0, 0),
                    "Unexpected dimensions or non-RGBA PNG: " + str(path))
            seen_ihdr = True
        elif tag == b"IDAT":
            packed.append(data)
        elif tag == b"IEND":
            seen_end = True
            break
    require(seen_end and seen_ihdr and packed and pos == len(raw),
            "Incomplete PNG: " + str(path))
    expected = side * (1 + 4 * side)
    stream = zlib.decompressobj()
    pixels = stream.decompress(b"".join(packed), expected + 1)
    require(stream.eof and len(pixels) == expected and not stream.unconsumed_tail,
            "Unexpected inflated image payload: " + str(path))
    row_size = 1 + side * 4
    require(all(pixels[y * row_size] == 0 for y in range(side)),
            "Only explicit unfiltered RGBA rows supported: " + str(path))
    return pixels, raw


def channel_stats(pixels, side):
    stride = 1 + side * 4
    step = max(1, side // 128)
    sampled = []
    for y in range(0, side, step):
        start = y * stride + 1
        for x in range(0, side, step):
            sampled.append(pixels[start + 4*x])
    return {
        "average": round(sum(sampled) / len(sampled), 2),
        "minimum": min(sampled),
        "maximum": max(sampled),
        "sampleCount": len(sampled),
        "above170": sum(v > 170 for v in sampled),
    }


def check_seams(pixels, side, name):
    row_size = 1 + side * 4
    max_delta = 0
    for y in range(side):
        left = y * row_size + 1
        right = left + (side - 1) * 4
        for channel in range(3):
            max_delta = max(max_delta,
                            abs(pixels[left+channel] - pixels[right+channel]))
    for x in range(side):
        top = 1 + x * 4
        bottom = (side - 1) * row_size + 1 + x * 4
        for channel in range(3):
            max_delta = max(max_delta,
                            abs(pixels[top+channel] - pixels[bottom+channel]))
    require(max_delta <= 16, "Visible tile seam on " + name)
    return max_delta


def inspect_material(name, raw_maps, side):
    metrics = {}
    for channel, pixels in raw_maps.items():
        stats = channel_stats(pixels, side)
        stats["edgeMaxDelta"] = check_seams(pixels, side, name + "/" + channel)
        metrics[channel] = stats

    color = metrics["ColorMap"]
    normal = metrics["NormalMap"]
    rough = metrics["RoughnessMap"]
    metal = metrics["MetalnessMap"]
    require(color["maximum"] - color["minimum"] > 18,
            "Color texture too flat: " + name)
    require(normal["average"] > 110 and normal["average"] < 145,
            "Normal x-component is biased/unphysical: " + name)
    require(rough["average"] > 95, "Unrealistically smooth environment: " + name)
    if name == "freight_steel":
        require(metal["average"] < 70,
                "Painted freight steel must be predominantly dielectric")
        require(metal["above170"] > metal["sampleCount"] * 0.001,
                "Paint chips must reveal occasional metallic substrate")
        require(rough["average"] > 145,
                "Painted freight steel needs a worn, rough finish")
    elif name == "warehouse_steel":
        require(metal["average"] > 145,
                "Exposed warehouse steel must remain mostly metallic")
    elif name == "yard_asphalt":
        require(metal["average"] < 20 and rough["average"] > 180,
                "Asphalt is a rough dielectric, never polished metal")
    return metrics


def make_preview(preview, channel_images, side):
    tile = min(256, side)
    width, height = tile * len(CHANNELS), tile * len(MATERIALS)
    stride = 1 + width * 4
    sheet = bytearray()
    for _ in range(height):
        sheet.append(0)
        sheet.extend(b"\x22\x2a\x2d\xff" * width)
    for row, material in enumerate(MATERIALS):
        for col, channel in enumerate(CHANNELS):
            image = channel_images[material][channel]
            src_stride = 1 + side * 4
            for y in range(tile):
                src_y = (y * side) // tile
                src_row = src_y * src_stride + 1
                target = (row * tile + y) * stride + 1 + col * tile * 4
                for x in range(tile):
                    src_x = (x * side) // tile
                    src = src_row + src_x * 4
                    dst = target + x * 4
                    sheet[dst:dst+4] = image[src:src+4]
    preview.parent.mkdir(parents=True, exist_ok=True)
    write_png(preview, width, height, sheet)
    return {
        "file": preview.name,
        "sha256": hashlib.sha256(preview.read_bytes()).hexdigest(),
        "size": [width, height],
        "rows": list(MATERIALS),
        "columns": list(CHANNELS),
    }


def audit(folder, preview=None, report=None, require_1k=False):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    resolution = manifest.get("resolution")
    require(isinstance(resolution, list) and len(resolution) == 2
            and resolution[0] == resolution[1]
            and isinstance(resolution[0], int)
            and 64 <= resolution[0] <= 2048,
            "Unsupported world PBR preview resolution")
    side = resolution[0]
    require(not require_1k or side == 1024,
            "Production Roblox world assets must be 1024x1024")
    require(manifest.get("sets") == list(MATERIALS)
            and manifest.get("channels") == list(CHANNELS),
            "World PBR manifest inventory mismatch")
    inspected = {}
    images = {}
    for material in MATERIALS:
        images[material] = {}
        for channel in CHANNELS:
            path = folder / (material + "_" + channel + ".png")
            pixels, raw = decode_png(path, side)
            pinned = manifest["files"][material][channel]
            require(len(raw) == pinned.get("bytes")
                    and hashlib.sha256(raw).hexdigest() == pinned.get("sha256"),
                    "World material hash mismatch: " + path.name)
            images[material][channel] = pixels
        inspected[material] = inspect_material(material, images[material], side)
    result = {
        "resolution": resolution,
        "materials": inspected,
        "preview": make_preview(preview, images, side) if preview else None,
    }
    if report:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", type=Path, required=True)
    ap.add_argument("--preview", type=Path)
    ap.add_argument("--report", type=Path)
    ap.add_argument("--require-1k", action="store_true")
    args = ap.parse_args()
    result = audit(args.assets, args.preview, args.report, args.require_1k)
    print("IRON YARD world PBR material audit: OK ("
          + str(result["resolution"][0]) + "px, 3 materials, 12 maps)")
    for name, channels in result["materials"].items():
        print(name + ": average metalness "
              + str(channels["MetalnessMap"]["average"])
              + ", roughness " + str(channels["RoughnessMap"]["average"]))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, zlib.error) as exc:
        raise SystemExit("World PBR visual audit failed: " + str(exc))
