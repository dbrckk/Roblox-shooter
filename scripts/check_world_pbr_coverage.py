#!/usr/bin/env python3
"""Contract: every uploaded world PBR family has live map geometry coverage.

These are real authoritative colliders, not decorative or invisible mocks.
MaterialVariant assignments do not change part geometry or hitbox behavior.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
map_code = (ROOT / "src/server/MapService.luau").read_text(encoding="utf-8")
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

assert "WorldPbr.start()" in map_code
assert map_code.index("WorldPbr.start()") < map_code.index("buildArena(folder)")
assert 'if not ready or not part or not part:IsA("BasePart")' in material
assert 'part.Material == Enum.Material[style.base]' in material
assert 'part.MaterialVariant = Policy.variantName(key)' in material
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "FALLBACK")' in material
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "CONFIGURED")' in material
assert 'low:SetAttribute("MantleTarget", true)' in map_code
assert 'collision:SetAttribute("MantleTarget", true)' in map_code
print("IRON YARD: 3 approved world PBR families mapped to gameplay geometry")
