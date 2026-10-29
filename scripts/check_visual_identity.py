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

    art = source("src/server/ArenaArt.luau")
    for part in ("side flute", "locking rod", "door seam", "FreightSerial"):
        check(part in art, "Container modeling missing: " + part)
    check('Enum.Material.Neon' not in art, "Container art must remain industrial daylight")
    check("p.CanCollide = false" in art and "p.CanQuery = false" in art,
          "Decorative art must not change collision or raycasts")

    # These build-time checks prevent attractive world detailing from silently
    # becoming extra collision or bullet-blocking geometry on Android.
    for name in ("warehouseArchitecture", "catwalkSafety", "gantryRigging"):
        check("local function " + name + "(parent)" in art,
              "Missing industrial architecture: " + name)
        check(art.count(name + "(decor)") == 1,
              "Decorative architecture must be built once: " + name)
    for name in ("p.CanCollide = false", "p.CanQuery = false",
                 "p.CanTouch = false", 'p:SetAttribute("NeonArtTier"'):
        check(name in art, "Missing art physics / LOD contract: " + name)
    check("p.CanCollide = true" not in art and "p.CanQuery = true" not in art,
          "The decorative module must never take over authoritative gameplay geometry")

    lod = source("src/client/BotLOD.client.luau")
    hud = source("src/client/HudController.luau")
    effects = source("src/client/WeaponVisuals.luau")
    for preset in ("ECO", "BALANCED", "QUALITY"):
        check('"' + preset + '"' in hud,
              "Graphics option missing in client HUD: " + preset)
    # BALANCED is intentionally the fallback branch of the LOD selector;
    # only ECO and QUALITY need explicit comparisons.
    for preset in ("ECO", "QUALITY"):
        check('"' + preset + '"' in lod,
              "Graphics option missing in client LOD: " + preset)
    check("else:" not in lod, "Luau LOD selector must use Lua syntax")
    check("artHideBeyond = isTouch and 110 or 195" in lod,
          "Missing default balanced LOD distance")
    for name in ("IronYardGraphicsPreset", "NeonArtTier"):
        check(name in lod, "Visual detail budget mismatch: " + name)
    check("function WeaponVisuals:drawImpact(" in effects,
          "Surface-specific visual impacts must remain client-only")
    check("drawImpact" not in source("src/server/WeaponService.luau"),
          "Server should not own short-lived cosmetic impact objects")


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

    asset_registry = source("src/shared/VanguardAssetIds.luau")
    loader = source("src/server/VanguardAssetLoader.luau")
    init_server = source("src/server/init.server.luau")
    for color in PALETTES:
        check(color + " = " in asset_registry, "Missing owner-controlled PBR palette ID: " + color)
    for key in ("game.CreatorType", "game.CreatorId", "InsertService:LoadAsset",
                "SurfaceAppearance", "CanQuery = false", "CanCollide = false",
                "staging.Parent = ServerStorage"):
        check(key in loader, "Owner-controlled asset loader missing: " + key)
    for key in ("task.spawn(loadConfiguredPbr)", "IronYardPbrStatus",
                "hasCompleteTemplateSet(", "IronYardPbrTemplatesLoaded"):
        check(key in loader, "Non-blocking verified PBR import is missing: " + key)
    check("requiresPbrUpgrade" in source("src/server/BotService.luau"),
          "Bots must acquire imported PBR meshes at a safe round boundary")
    check("VanguardAssetLoader.start()" in init_server,
          "Server must initialize optional imported PBR kit before spawning bots")

    print("IRON YARD visual identity / four PBR palettes / public UI: OK")

if __name__ == "__main__":
    main()
