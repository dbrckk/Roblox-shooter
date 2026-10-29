#!/usr/bin/env python3
"""Regression fixture for GLB structural/PBR parser. Zero network calls."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("iy_deep_glb", ROOT / "scripts/audit_vanguard_glb.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def glb(complete=True):
    nodes = [{"name": "VANGUARD_" + piece, "mesh": i}
             for i, piece in enumerate(audit.PIECES)]
    images = [{"bufferView": i, "mimeType": "image/png"} for i in range(4)]
    data = {
        "asset": {"version": "2.0", "generator": "IRON YARD fixture"},
        "scenes": [{"nodes": list(range(7))}],
        "scene": 0,
        "nodes": nodes,
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]} for _ in nodes],
        "accessors": [{"componentType": 5126, "count": 3, "type": "VEC3"}],
        "materials": [{
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicRoughnessTexture": {"index": 1},
            },
            **({"normalTexture": {"index": 2}} if complete else {}),
        }] * 4,
        "textures": [{"source": i} for i in range(4)],
        "images": images,
        "bufferViews": [{"byteOffset": 1024 * i, "byteLength": 1024} for i in range(4)],
        "buffers": [{"byteLength": 4096}],
    }
    js = json.dumps(data, separators=(",", ":")).encode("utf-8")
    js += b" " * ((-len(js)) % 4)
    binary = bytes(4096)
    payload = (struct.pack("<I4s", len(js), b"JSON") + js
               + struct.pack("<I4s", len(binary), b"BIN\x00") + binary)
    return struct.pack("<4sII", b"glTF", 2, 12 + len(payload)) + payload


with tempfile.TemporaryDirectory() as directory:
    file = Path(directory) / "original.glb"
    file.write_bytes(glb())
    result = audit.inspect(file)
    assert result["mesh_parts"] == 7 and result["normal_maps"] >= 1
    assert result["metal_rough_maps"] >= 1
    file.write_bytes(glb(False))
    try:
        audit.inspect(file)
    except AssertionError:
        pass
    else:
        raise AssertionError("Textureless model must not pass GLB PBR review")
    file.write_bytes(b"not a glb" * 700)
    try:
        audit.inspect(file)
    except AssertionError:
        pass
    else:
        raise AssertionError("Invalid GLB header must be rejected")

print("IRON YARD GLB/PBR structural audit fixtures: OK")
