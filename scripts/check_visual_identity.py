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
    clientLighting = source("src/client/EnvironmentLighting.client.luau")
    profile = source("src/shared/EnvironmentProfile.luau")
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
    for needle in ("local function industrialLightFixtures(parent)",
                   "local function groundWear(parent)",
                   'lens:SetAttribute("IronYardLightFixture", true)',
                   "industrialLightFixtures(decor)", "groundWear(decor)"):
        check(needle in art, "Missing non-colliding industrial illumination or ground wear: " + needle)
    for needle in ("function EnvironmentProfile.get(",
                   "function EnvironmentProfile.activeFixtureIndices(",
                   "function EnvironmentProfile.activeExhaustIndices(",
                   "exhausts = 0", "exhausts = 1", "exhausts = 4",
                   "lamps = 0", "lamps = 2", "lamps = 8"):
        check(needle in profile, "Missing bounded graphics quality policy: " + needle)
    for needle in ("Lighting.ExposureCompensation = settings.exposure",
                   'Profile.fixtureStyle(role,',
                   'tuneLocalSpot(entry.lamp, entry.part)',
                   "Lighting.EnvironmentDiffuseScale",
                   "bloom.Enabled = settings.bloom",
                   "Profile.activeFixtureIndices(distances,",
                   'lamp.Face = Enum.NormalId.Bottom',
                   "lamp.Shadows = false",
                   'player:GetAttributeChangedSignal("IronYardGraphicsPreset")'):
        check(needle in clientLighting, "Client-only preset-aware lighting is missing: " + needle)
    for needle in ('base:SetAttribute("IronYardExhaustVent", true)',
                   '"ROOF / louver blade "'):
        check(needle in art, "Missing non-colliding rooftop exhaust identity")
    exhaust = source("src/client/ExhaustAmbient.client.luau")
    for needle in ("Profile.activeExhaustIndices(", 'puff.CanQuery = false',
                   'puff.CanCollide = false', "Debris:AddItem(puff,",
                   'part:GetAttribute("IronYardExhaustVent") ~= true'):
        check(needle in exhaust, "Missing local-only exhaust/culling protection: " + needle)
    warehouse_cladding = source("src/server/WarehouseCladding.luau")
    for needle in ("WarehouseCladding.decorate(decor)",
                   'local WarehouseCladding = require(script.Parent:WaitForChild("WarehouseCladding"))',
                   'lens:SetAttribute("IronYardLightRole", role)'):
        check(needle in art, "Warehouse cladding / lighting role integration missing: " + needle)
    for needle in ('function Cladding.decorate(decor)',
                   '"CLADDING / "', 'p.CanCollide = false',
                   'p.CanQuery = false', 'p.CanTouch = false',
                   'p.CastShadow = false',
                   'p:SetAttribute("NeonArtTier", tier or "Detail")',
                   'Plan.sidePanels()', 'Plan.bulkheadPanels()',
                   'WarehouseBerthSerial'):
        check(needle in warehouse_cladding, "Warehouse material safety/detail missing: " + needle)
    cladding_plan = source("src/shared/WarehouseCladdingPlan.luau")
    for needle in ("function Plan.sidePanels()", "function Plan.bulkheadPanels()"):
        check(needle in cladding_plan, "Cladding layout must be testable")
    # All extra surfaces are purely cosmetic, with no second bullet collider.
    freight_art = source("src/server/FreightSurfaceArt.luau")
    freight_plan = source("src/shared/FreightSurfacePlan.luau")
    for needle in ('local FreightSurfaceArt = require(script.Parent:WaitForChild("FreightSurfaceArt"))',
                   "FreightSurfaceArt.decorate(decor)"):
        check(needle in art, "Freight and asphalt appearance wiring missing: " + needle)
    for needle in ('function FreightSurfaceArt.decorate(decor)',
                   'Plan.containers()', 'Plan.repairs()',
                   'p.CanCollide = false', 'p.CanQuery = false',
                   'p.CanTouch = false', 'p.CastShadow = false',
                   'p:SetAttribute("NeonArtTier", tier)',
                   '"freight corner casting "',
                   '"freight painted stripe "',
                   '"freight roof service runner "',
                   '"yard asphalt patch "'):
        check(needle in freight_art, "Freight structural surface or physics contract missing: " + needle)
    for needle in ('function Plan.containers()', 'function Plan.repairs()',
                   'column * 100', 'row * 103',
                   '15 + ((row + column + 6) % 3) * 6'):
        check(needle in freight_plan, "Freight art must match server container grid: " + needle)
    check('Instance.new("SpotLight")' not in art
          and 'Instance.new("PointLight")' not in art,
          "Replicated arena art must never instantiate dynamic fixtures")

    # Optional owner-controlled PBR maps are an atomic 12-image batch.
    world_pbr = source("src/server/WorldPbrMaterials.luau")
    world_policy = source("src/shared/WorldPbrPolicy.luau")
    world_ids = source("src/shared/WorldPbrAssetIds.luau")
    for needle in ("function WorldPbr.start()", "function WorldPbr.apply(",
                   "game.CreatorType ~= Enum.CreatorType.User",
                   "Policy.ready(Registry, game.CreatorId)",
                   'Instance.new("MaterialVariant")',
                   "variant.Parent = MaterialService"):
        check(needle in world_pbr, "World PBR runtime missing: " + needle)
    for needle in ("function Policy.ready(", "function Policy.variantName(",
                   '"ColorMap"', '"NormalMap"', '"RoughnessMap"', '"MetalnessMap"'):
        check(needle in world_policy, "Incomplete PBR map whitelist: " + needle)
    check("sourceCommit" in world_ids and "ownerUserId" in world_ids,
          "Missing owner-pinned PBR registry")
    world_gen = source("tools/assetforge/generate_world_maps.py")
    world_upload = source("scripts/upload_world_pbr_images.py")
    for needle in ('"freight_steel"', '"warehouse_steel"', '"yard_asphalt"',
                   '"ColorMap"', '"NormalMap"', '"RoughnessMap"', '"MetalnessMap"'):
        check(needle in world_gen, "Missing original world PBR generator material: " + needle)
        check(needle in world_upload, "World PBR uploader inventory mismatch: " + needle)
    for needle in ("verify_png(raw)", 'manifest.get("resolution") == [1024, 1024]',
                   'require(digest == expected.get("sha256")',
                   "if args.dry_run:", "render_registry(", "ROBLOX_OPEN_CLOUD_ASSETS_KEY"):
        check(needle in world_upload, "World PBR upload security preflight: " + needle)
    for needle in ('WorldPbr.start()', 'WorldPbr.apply(base, "freight_steel")',
                   'WorldPbr.apply(floor, "yard_asphalt")'):
        check(needle in map_source, "Map collider PBR hook missing: " + needle)
    for needle in ('WorldPbr.apply(sheet, "warehouse_steel")',
                   'WorldPbr.apply(plate, "warehouse_steel")'):
        check(needle in warehouse_cladding, "Warehouse PBR hook missing: " + needle)
    for needle in ('WorldPbr.apply(p, "yard_asphalt")', 'p.CanQuery = false'):
        check(needle in freight_art, "Cosmetic asphalt PBR hook unsafe: " + needle)

    # High-visibility native 3D upgrades are an honest playable fallback
    # while the real PBR asset registry is still unpopulated.
    for needle in (
        "local function warehouseRoof(parent)",
        '"ROOF / pitched corrugated shell "',
        '"ROOF / skylight glass "',
        '"ROOF / extraction duct "',
        '"SKYLINE / dock shutter "',
        "warehouseRoof(decor)",
        "sheet.CastShadow = false",
        "pane.CastShadow = false",
    ):
        check(needle in art, "Native visual warehouse fidelity regression: " + needle)
    native_props = source("src/server/IndustrialProps.luau")
    for needle in (
        '"hydraulic cylinder "', '"hydraulic ram "',
        '" / fork tip "', 'Instance.new("WedgePart")',
        '"wheel lug "', '"cab steering wheel"',
        '"rear counterweight"', '"rear signal "',
        'wedge.CanCollide = false', 'wedge.CanQuery = false',
        'wedge:SetAttribute("NeonArtTier", "Detail")',
    ):
        check(needle in native_props,
              "Native forklift PBR-fallback detail or physics safety missing: " + needle)

    # Two full-size elevated decks and ten stair skins must follow the
    # real gameplay colliders, not second coordinates or new player hitboxes.
    catwalk_plan = source("src/shared/CatwalkDeckPlan.luau")
    catwalk_art = source("src/server/CatwalkDeckArt.luau")
    for needle in ('function Plan.forCollider(', 'function Plan.deckStrips()',
                   '"CATWALK / loading platform -1"',
                   '"CATWALK / loading platform 1"',
                   '"^CATWALK / access stair (%-?1):([1-5])$"',
                   "math.huge"):
        check(needle in catwalk_plan,
              "Catwalk exact collider whitelist or art budget missing: " + needle)
    for needle in ('local CatwalkDeckArt = require(script.Parent:WaitForChild("CatwalkDeckArt"))',
                   "CatwalkDeckArt.decorate(decor, arena)"):
        check(needle in art, "Catwalk deck renderer not integrated: " + needle)
    for needle in ('function Art.decorate(decor, arena)',
                   'Plan.forCollider(collider.Name,',
                   'collider.Size.X, collider.Size.Y, collider.Size.Z',
                   'p.CanCollide = false', 'p.CanQuery = false',
                   'p.CanTouch = false', 'p.CastShadow = false',
                   'p:SetAttribute("NeonArtTier", tier)',
                   '"diamondplate deck "', '"deck end girder "',
                   '"deck orientation stencil "', '"stair diamondplate "',
                   '"stair warning nose "', "decks ~= 2 or steps ~= 10"):
        check(needle in catwalk_art,
              "Catwalk native metal skins or physics contract missing: " + needle)
    check('Instance.new("SpotLight")' not in catwalk_art,
          "Catwalk decking must not add realtime server lights")

    # Production forklift visuals follow authoritative colliders, not a
    # second set of hardcoded coordinates; styles and art remain nonblocking.
    forklift_plan = source("src/shared/ForkliftVisualPlan.luau")
    forklift_details = source("src/server/ForkliftDetailArt.luau")
    for needle in ('function Plan.forCollider(', '"FREIGHT_LIFTER"',
                   '"YARD_HANDLER"', "math.huge", "validNumber("):
        check(needle in forklift_plan,
              "Forklift plan whitelist/physical measurements missing: " + needle)
    for needle in ('collision:SetAttribute("IronYardForkliftFleet", forklift.fleet)',
                   'collision:SetAttribute("IronYardForkliftYaw", forklift.yaw)'):
        check(needle in map_source, "Fleet ID and pose must come from colliders: " + needle)
    for needle in ('ForkliftVisualPlan.forCollider(', 'ForkliftDetailArt.decorate(folder, collider, plan)',
                   'forklift(folder, collider, machine)',
                   'collider.CFrame * CFrame.new(0, -collider.Size.Y * 0.5, 0)',
                   'collider:GetAttribute("IronYardForkliftFleet")',
                   'collider:GetAttribute("IronYardForkliftYaw")',
                   'forkliftCount ~= 2'):
        check(needle in native_props,
              "Forklift 3D alignment to live game colliders missing: " + needle)
    check('forklift(folder, "12", -72' not in native_props
          and 'forklift(folder, "27", 72' not in native_props,
          "Forklift render cannot use duplicated world coordinates")
    for needle in ('function DetailArt.decorate(folder, collider, plan)',
                   '"operator diamondplate footwell"',
                   '"work lamp housing "', '"freight lifting crosshead"',
                   '"freight radiator fin "', '"yard cooling louver "',
                   'p.CanCollide = false', 'p.CanQuery = false',
                   'p.CanTouch = false', 'p.CastShadow = false',
                   'p:SetAttribute("NeonArtTier", tier)'):
        check(needle in forklift_details,
              "Forklift mechanical detail or physics safety missing: " + needle)
    check('Instance.new("PointLight")' not in forklift_details,
          "Forklift detailing must not add global realtime light work")

    # Distinctive pallet cargo must follow actual server collision bodies.
    # Additional cargo can only be visual: no new query, touch or collisions.
    pallet_plan = source("src/shared/PalletVisualPlan.luau")
    for needle in ('function Plan.forCollider(', '"TIMBER_CRATE"',
                   '"WRAPPED_FREIGHT"', '"STEEL_CAGE"',
                   'value == value', 'math.huge'):
        check(needle in pallet_plan,
              "Pallet model placement/variation safety missing: " + needle)
    for needle in ('PalletVisualPlan.forCollider(', 'collider:IsA("BasePart")',
                   'collider.Size.X, collider.Size.Y, collider.Size.Z',
                   'palletStacks(folder, collider, plan)',
                   'collider.CFrame * CFrame.new(0, -collider.Size.Y * 0.5, 0)',
                   '" / timber diagonal "', '"shrinkwrap side "',
                   '"cage upright "', '"freight identity plate"',
                   'p.CanCollide = false', 'p.CanTouch = false',
                   'p.CanQuery = false'):
        check(needle in native_props,
              "Pallet 3D styling or collision contract missing: " + needle)
    check("Vector2.new(0, -128)" not in native_props,
          "Pallet art must not duplicate map coordinates")

    # All surface replacements are visibly attached to ACTUAL colliders and
    # never author additional bullet or movement collision volumes.
    cover = source("src/server/CoverArt.luau")
    cover_plan = source("src/shared/CoverSurfacePlan.luau")
    for needle in ("CoverArt.build(folder)", 'local CoverArt = require(script.Parent:WaitForChild("CoverArt"))'):
        check(needle in map_source, "World cover facade integration is missing: " + needle)
    for needle in ("function CoverArt.build(arena)",
                   'folder.Name = "IronYardCoverSkins"',
                   'item:IsA("BasePart")',
                   "Plan.forCollider(item.Name, size.X, size.Y, size.Z)",
                   "part.CanCollide = false", "part.CanTouch = false",
                   "part.CanQuery = false",
                   'part:SetAttribute("NeonArtTier", tier)'):
        check(needle in cover, "Combat cover render safety/LOD regression: " + needle)
    for needle in ('"CAST_CONCRETE"', '"ARMED_ROADBLOCK"', '"CARGO_BARRIER"',
                   "function CoverSurfacePlan.forCollider("):
        check(needle in cover_plan, "Missing deterministic combat cover style: " + needle)
    # Only 32 real combat covers receive decoration: 16 container barriers,
    # 13 live radial roadblocks and the three warehouse/vault covers.
    # Wayfinding must be bounded, legible and nonphysical on Android.
    for needle in ('function roadblockExists(index)', 'index > 16',
                   'math.cos(angle)', 'math.sin(angle)',
                   'dimension(x, 13)', 'dimension(y, 5.5)',
                   '"^COVER / concrete barrier (%-?%d+):(%-?%d+):(%-?%d+)$"',
                   '"^COVER / movable roadblock (%d+)$"',
                   'marked = flank == 1', 'marked = index % 3 == 1',
                   'serial = marked and serial or nil'):
        check(needle in cover_plan,
              "Authoritative combat-cover whitelist or signage budget missing: " + needle)
    for needle in ('local function stencil(plate, message)',
                   '"CoverFreightIdentification"',
                   'surface.Face = Enum.NormalId.Front',
                   '"cast expansion seam "', '"diamondplate strike shield "',
                   '"cargo shutter rib "', '"freight serial plate"',
                   'if plan.serial then', 'return part'):
        check(needle in cover,
              "Combat cover distinctive skins and ID decals missing: " + needle)
    check('Instance.new("PointLight")' not in cover
          and 'Instance.new("SpotLight")' not in cover,
          "Cover facades must not add server-side real-time lights")
    lod_source = source("src/client/BotLOD.client.luau")
    check('"IronYardCoverSkins"' in lod_source,
          "Cover detail must have mobile visibility culling")

    # Visual-only gantries must be separate client-animated assemblies, with
    # absolutely no real player collision, raycast or server tween workload.
    industrialMotion = source("src/client/IndustrialMotion.client.luau")
    gantryMotion = source("src/shared/GantryMotion.luau")
    for needle in ('assembly:SetAttribute("IronYardGantryMover", true)',
                   'assembly:SetAttribute("IronYardGantryIndex", i)',
                   'beacon:SetAttribute("IronYardGantryBeacon", true)'):
        check(needle in art, "Moving industrial gantry assembly missing: " + needle)
    for needle in ("function GantryMotion.pose(", 'preset == "ECO"',
                   'preset == "QUALITY"', "math.sin(seconds"):
        check(needle in gantryMotion, "Bounded crane animation missing: " + needle)
    for needle in ('Motion.pose(elapsed, rig.index, quality, distance)',
                   'model:PivotTo(rig.base * CFrame.new(travel, lift, 0))',
                   'RunService.Heartbeat:Connect(', 'PointLight',
                   'distance < 150', 'local interval = UserInputService.TouchEnabled'):
        check(needle in industrialMotion, "Client-only crane animation missing: " + needle)
    check("RunService" not in art and "TweenService" not in art,
          "Server should not drive per-frame cosmetic crane motion")

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
                "staging.Parent = ServerStorage"):
        check(key in loader, "Owner-controlled asset loader missing: " + key)
    policy = source("src/shared/VanguardMeshPolicy.luau")
    kit = source("src/server/VanguardMeshKit.luau")
    studio = source("tools/studio/install_vanguard.lua")
    bot_visuals = source("src/server/BotVisuals.luau")
    for needle in ("function Policy.identifyPiece(", "function Policy.mapsReady(",
                   "function Policy.keepChild(", '"ColorMap"', '"NormalMap"',
                   '"RoughnessMap"', '"MetalnessMap"'):
        check(needle in policy, "Strict PBR mesh selection or material validation missing: " + needle)
    for needle in ("function Kit.isRenderable(mesh)", "function Kit.cleanClone(source)",
                   "Policy.mapsReady(maps(appearance))", "clone:GetDescendants()",
                   "Policy.keepChild(child.ClassName, child.Parent == clone,",
                   "child:Destroy()", "clone.CanQuery = false"):
        check(needle in kit, "Untrusted owner-controlled PBR package bypasses sanitization: " + needle)
    for needle in ("MeshKit.isRenderable(mesh)", "MeshKit.cleanClone(selected[name])",
                   "Policy.identifyPiece(item.Name)", "loaded:Destroy()"):
        check(needle in loader, "Owner-controlled asset loader lacks verified safe extraction: " + needle)
    for needle in ("MeshKit.isRenderable(mesh)", "MeshKit.cleanClone(source[partName])",
                   'model:SetAttribute("NeonVisualSource", "PROCEDURAL_PARTS")'):
        check(needle in bot_visuals, "Bots must preserve safe procedural fallback: " + needle)
    for needle in ("assert(completeMaps(", "local function safeClone(mesh)",
                   "clone:GetDescendants()", "item:Destroy()",
                   "if previous then previous:Destroy() end"):
        check(needle in studio, "Studio PBR installation is unsafe or not atomic: " + needle)
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
