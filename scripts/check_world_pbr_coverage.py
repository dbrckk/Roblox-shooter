#!/usr/bin/env python3
"""Contract: every uploaded world PBR family has live map geometry coverage.

The original three PBR material families must cover live gameplay geometry.
Two additional warehouse roof sheets are visual-only (no hitboxes/raycasts).
MaterialVariant assignments never change geometry or hitbox behavior.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
map_code = (ROOT / "src/server/MapService.luau").read_text(encoding="utf-8")
art_code = (ROOT / "src/server/ArenaArt.luau").read_text(encoding="utf-8")
material = (ROOT / "src/server/WorldPbrMaterials.luau").read_text(encoding="utf-8")
policy = (ROOT / "src/shared/WorldPbrPolicy.luau").read_text(encoding="utf-8")
registry = (ROOT / "src/shared/WorldPbrAssetIds.luau").read_text(encoding="utf-8")

expected = {
    "freight_steel": ['WorldPbr.apply(base, "freight_steel")'],
    "warehouse_steel": [
        'WorldPbr.apply(low, "warehouse_steel")',
        'WorldPbr.apply(cover, "warehouse_steel")',
        'WorldPbr.apply(stair, "warehouse_steel")',
        'WorldPbr.apply(collision, "warehouse_steel")',
    ],
    "yard_asphalt": ['WorldPbr.apply(floor, "yard_asphalt")'],
}
for name, usages in expected.items():
    assert f'key = "{name}"' in policy, f"Missing policy {name}"
    assert f'{name} = ' in registry, f"Missing approved registry {name}"
    for usage in usages:
        assert usage in map_code, f"Missing in-world PBR application: {usage}"

# The 2 large roof sheets now use an already approved warehouse_steel
# variant. Their existing collisionless, raycast-free geometry is unchanged.
assert 'local WorldPbr = require(script.Parent:WaitForChild("WorldPbrMaterials"))' in art_code
assert 'WorldPbr.apply(sheet, "warehouse_steel")' in art_code
assert 'for _, side in ipairs({ -1, 1 }) do' in art_code
assert 'local sheet = prop(parent, "ROOF / pitched corrugated shell " .. side,' in art_code
assert 'sheet.CastShadow = false' in art_code
for needle in ('p.CanCollide = false', 'p.CanQuery = false', 'p.CanTouch = false'):
    assert needle in art_code, f"Roof art must remain visual-only: {needle}"

assert "WorldPbr.start()" in map_code
assert map_code.index("    WorldPbr.start()") < map_code.index("    buildArena(folder)")
assert 'if not ready or not part or not part:IsA("BasePart")' in material
assert 'part.Material == Enum.Material[style.base]' in material
assert 'part.MaterialVariant = Policy.variantName(key)' in material
assert 'part:SetAttribute("IronYardPbrMaterial", key)' in material
assert 'CollectionService:AddTag(part, "IronYardWorldPbr")' in material
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "FALLBACK")' in material
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "CONFIGURED")' in material
assert 'low:SetAttribute("MantleTarget", true)' in map_code
assert 'collision:SetAttribute("MantleTarget", true)' in map_code
print("IRON YARD: 3 approved world PBR families on colliders, plus 2 visual-only warehouse roof sheets")
