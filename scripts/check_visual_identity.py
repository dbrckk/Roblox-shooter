#!/usr/bin/env python3
"""Build-time identity guard for IRON YARD (no Roblox runtime required).

This is a static consistency check, not a substitute for Studio / Android playtests.
The old Neon* network attributes and folder IDs are intentionally retained for
backwards compatibility; only the public-facing direction is checked.
"""
import ast
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PALETTES = ["olive", "sand", "slate", "rust"]

def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

def check(condition, message):
    if not condition:
        raise AssertionError(message)

def find_lua_palette(code, field):
    expr = re.search(r"local\s+" + re.escape(field) + r"\s*=\s*\{([^{}]*)\}", code)
    check(expr is not None, "Luau palette not found: " + field)
    return re.findall(r'"([a-z]+)"', expr.group(1))

def find_py_palette(code, field):
    expr = re.search(r"^" + re.escape(field) + r"\s*=\s*(\[[^\]]+\])", code, re.MULTILINE)
    check(expr is not None, "Python palette not found: " + field)
    return ast.literal_eval(expr.group(1))

def main():
    project = json.loads(source("default.project.json"))
    check("IRON YARD" in project["name"], "Place title does not match art direction")

    for filename in (
        "src/server/MapService.luau",
        "src/server/ArenaArt.luau",
        "src/client/MatchHud.client.luau",
        "src/client/Briefing.client.luau",
    ):
        content = source(filename)
        check("NEON STRIKE" not in content, "Legacy public branding: " + filename)
        check("Enum.Material.Neon" not in content, "Legacy neon material: " + filename)

    map_source = source("src/server/MapService.luau")
    check('ArenaTheme", "IRON_YARD_DAYLIGHT"' in map_source,
          "Expected daylight theme attribute")
    check("Lighting.ClockTime = 13.8" in map_source,
          "Sunlight changed unexpectedly")

    bot = find_lua_palette(source("src/server/BotVisuals.luau"), "importedPalette")
    studio = find_lua_palette(source("tools/studio/install_vanguard.lua"), "palettes")
    blender = find_py_palette(source("tools/assetforge/build_vanguard.py"), "COLORS")
    validate = None
    validate_expr = re.search(r"^    names = (\[[^\]]+\])", source("tools/assetforge/validate_exports.py"), re.MULTILINE)
    if validate_expr:
        validate = ast.literal_eval(validate_expr.group(1))
    check(bot == PALETTES, "Bot mesh palette mismatch")
    check(studio == PALETTES, "Studio importer palette mismatch")
    check(blender == PALETTES, "Blender palette mismatch")
    check(validate == PALETTES, "Export validator palette mismatch")

    for name in PALETTES:
        check('"' + name + '"' in source("tools/assetforge/generate_maps.py"),
              "Missing PBR texture palette: " + name)

    print("IRON YARD visual identity / four PBR palettes / public UI: OK")

if __name__ == "__main__":
    main()
