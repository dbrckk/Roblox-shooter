#!/usr/bin/env python3
"""Deep structural audit of original VANGUARD glTF 2.0/PBR archives.

No Blender/Roblox runtime or third-party Python dependencies. This parses the
actual GLB JSON and image buffer views, not merely the magic header.
"""
import argparse
import json
from pathlib import Path
import struct

PALETTES = ("olive", "sand", "slate", "rust")
PIECES = ("torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "rifle")


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def inspect(path):
    payload = path.read_bytes()
    require(len(payload) > 2048, f"Empty GLB: {path}")
    magic, version, byte_length = struct.unpack_from("<4sII", payload)
    require(magic == b"glTF" and version == 2 and byte_length == len(payload),
            f"Invalid glTF 2.0 wrapper: {path}")
    cursor = 12
    chunks = {}
    while cursor < len(payload):
        require(cursor + 8 <= len(payload), f"Truncated GLB chunk: {path}")
        chunk_length, kind = struct.unpack_from("<I4s", payload, cursor)
        cursor += 8
        require(cursor + chunk_length <= len(payload), f"Bad chunk bounds: {path}")
        require(kind not in chunks, f"Duplicate GLB chunk: {path}")
        chunks[kind] = payload[cursor:cursor + chunk_length]
        cursor += chunk_length
    require(b"JSON" in chunks and b"BIN\x00" in chunks,
            f"Expected embedded JSON and BIN chunks: {path}")

    metadata = json.loads(chunks[b"JSON"].decode("utf-8").strip(" \x00"))
    require(metadata.get("asset", {}).get("version") == "2.0",
            f"glTF schema version incorrect: {path}")
    nodes = metadata.get("nodes", [])
    meshes = metadata.get("meshes", [])
    materials = metadata.get("materials", [])
    textures = metadata.get("textures", [])
    images = metadata.get("images", [])
    views = metadata.get("bufferViews", [])
    require(len(meshes) >= 7, f"Fewer than seven geometric parts: {path}")
    require(len(materials) >= 4 and len(textures) >= 4 and len(images) >= 4,
            f"Missing real PBR material/texture inventory: {path}")

    names = [str(node.get("name", "")).lower().replace(".", "_")
             for node in nodes if isinstance(node, dict)]
    for piece in PIECES:
        require(any("vanguard_" + piece in name for name in names),
                f"Missing Blender original named mesh component {piece}: {path}")

    base = any(isinstance(mat.get("pbrMetallicRoughness", {}).get("baseColorTexture"), dict)
               for mat in materials)
    roughness_metal = any(
        isinstance(mat.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture"), dict)
        for mat in materials)
    normals = any(isinstance(mat.get("normalTexture"), dict) for mat in materials)
    require(base and roughness_metal and normals,
            f"GLB does not contain albedo + packed metal/roughness + normal textures: {path}")

    binary = chunks[b"BIN\x00"]
    for image in images:
        if "bufferView" not in image:
            require("uri" in image, f"GLB image missing data reference: {path}")
            continue
        idx = image["bufferView"]
        require(type(idx) is int and 0 <= idx < len(views),
                f"Invalid embedded image buffer view: {path}")
        view = views[idx]
        start = view.get("byteOffset", 0)
        size = view.get("byteLength", 0)
        require(type(start) is int and type(size) is int
                and size > 0 and start >= 0 and start + size <= len(binary),
                f"Texture data falls outside GLB BIN chunk: {path}")
        require(image.get("mimeType") in ("image/png", "image/jpeg", "image/webp"),
                f"Unknown embedded texture type: {path}")
    for mesh in meshes:
        primitives = mesh.get("primitives", [])
        require(len(primitives) > 0, f"Empty geometry in {path}")
        for primitive in primitives:
            require("POSITION" in primitive.get("attributes", {}),
                    f"Triangle primitive has no positions: {path}")
    return {
        "bytes": len(payload),
        "mesh_parts": len(meshes),
        "materials": len(materials),
        "images": len(images),
        "normal_maps": sum("normalTexture" in mat for mat in materials),
        "metal_rough_maps": sum("metallicRoughnessTexture" in
                                mat.get("pbrMetallicRoughness", {}) for mat in materials),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args()
    for name in PALETTES:
        path = args.assets / "meshes" / f"vanguard_{name}_LOD0.glb"
        info = inspect(path)
        require(info["bytes"] <= 20_000_000,
                f"LOD0 upload exceeds 20 MB Open Cloud limit: {path}")
        print(name + ": " + json.dumps(info, sort_keys=True))
    print("IRON YARD four real GLB/PBR material and texture inventories: OK")


if __name__ == "__main__":
    main()
