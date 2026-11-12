#!/usr/bin/env python3
"""Verify Luau PBR ADS values against real Blender weaponforge geometry.

Runs without Blender / bpy by invoking only the generator's pure shape
declarations with no-op mesh primitives. This does not replace Studio QA.
"""
import ast
import math
import re
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POSITIONS = {}


def box(name, pos, *args, **kwargs):
    POSITIONS[name] = pos
    return name


def cylinder(name, pos, *args, **kwargs):
    POSITIONS[name] = pos
    return name


def joined(parts, name):
    return name


MATS = {k: k for k in ("gunmetal", "carbon", "armor", "accent_sand")}
long_guns = runpy.run_path(str(ROOT / "tools/weaponforge/long_guns.py"))
source = ROOT / "tools/weaponforge/build_weapons.py"
tree = ast.parse(source.read_text(encoding="utf8"), filename=str(source))
pistol_node = next(
    node for node in tree.body
    if isinstance(node, ast.FunctionDef) and node.name == "pistol"
)
# Do not import build_weapons: its bpy dependency requires Blender.
scope = {"box": box, "cylinder": cylinder, "joined": joined}
exec(compile(ast.Module(body=[pistol_node], type_ignores=[]),
             str(source), "exec"), scope)
geometry = {}
for weapon, method in (
    ("AssaultRifle", lambda: long_guns["assault_rifle"](
        MATS, True, box, cylinder, joined)),
    ("Pistol", lambda: scope["pistol"](MATS, True)),
    ("Shotgun", lambda: long_guns["shotgun"](
        MATS, True, box, cylinder, joined)),
):
    POSITIONS.clear()
    method()
    rear_name = "Rear notch" if weapon == "Shotgun" else "Rear sight"
    front_name = "Bead front sight" if weapon == "Shotgun" else "Front sight"
    geometry[weapon] = (POSITIONS[rear_name], POSITIONS[front_name])

luau = (ROOT / "src/shared/WeaponAimPose.luau").read_text(encoding="utf8")
start = luau.split("local IMPORTED_PROFILES = {", 1)[1].split("\n}", 1)[0]
for weapon, (rear, front) in geometry.items():
    match = re.search(r"\b" + re.escape(weapon) + r"\s*=\s*\{([^{}]+)\}",
                      start)
    assert match, f"No imported ADS profile for {weapon}"
    values = {k: float(v) for k, v in re.findall(
        r"(\w+)\s*=\s*(-?(?:\d+(?:\.\d*)?|\.\d+))", match.group(1))}
    # Blender (x, forward-y, height-z) => Roblox (x, z, -y).
    rx, ry, rz = rear[0], rear[2], -rear[1]
    fx, fy, fz = front[0], front[2], -front[1]
    assert abs(rx - fx) < 1e-12, f"{weapon} needs horizontal yaw too"
    for key, expected in (
        ("sightX", rx), ("sightY", ry), ("sightZ", rz),
        ("frontY", fy), ("frontZ", fz),
    ):
        assert abs(values[key] - expected) < 1e-9, (
            f"{weapon} {key} differs from Blender source: "
            f"{values[key]} != {expected}"
        )
    angle = -math.atan2(fy - ry, rz - fz)
    c, s = math.cos(angle), math.sin(angle)
    tx = -rx
    ty = -(c * ry - s * rz)
    tz = -values["eyeRelief"] - (s * ry + c * rz)
    def transform(point):
        x, y, z = point
        return tx + x, ty + c * y - s * z, tz + s * y + c * z
    rear_position = transform((rx, ry, rz))
    front_position = transform((fx, fy, fz))
    assert max(abs(rear_position[0]), abs(rear_position[1]),
               abs(front_position[0]), abs(front_position[1])) < 1e-9
    assert abs(rear_position[2] + values["eyeRelief"]) < 1e-9
    assert front_position[2] < rear_position[2]
    assert -0.05 < angle < 0
    print(f"IRON YARD {weapon}: Blender PBR sight axis corrected by "
          f"{math.degrees(angle):.3f} degrees")
print("IRON YARD Blender-authored 3-gun PBR ADS geometry: OK")
