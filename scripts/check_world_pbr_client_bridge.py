#!/usr/bin/env python3
"""Guard owner-approved server tags -> streamed client MaterialVariant wiring."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
server = (ROOT / "src/server/WorldPbrMaterials.luau").read_text()
client = (ROOT / "src/client/WorldPbrClient.client.luau").read_text()
policy = (ROOT / "src/shared/WorldPbrPolicy.luau").read_text()
overlay = (ROOT / "src/client/PerfOverlay.client.luau").read_text()
ci = (ROOT / ".github/workflows/rojo-build.yml").read_text()
for text, requirements in (
    (server, [
        'Policy.ready(Registry, game.CreatorId)',
        'key == style.key and part.Material == Enum.Material[style.base]',
        'part:SetAttribute("IronYardPbrMaterial", key)',
        'CollectionService:AddTag(part, "IronYardWorldPbr")',
    ]),
    (client, [
        'Policy.clientVariant(part:GetAttribute(KEY)',
        'part.MaterialVariant = desired',
        'MaterialService:GetMaterialVariant(part.Material, desired)',
        'Workspace:GetAttribute("IronYardWorldPbrStatus") ~= "CONFIGURED"',
        'CollectionService:GetInstanceAddedSignal(TAG)',
        'CollectionService:GetInstanceRemovedSignal(TAG)',
        'part:GetAttributeChangedSignal(KEY)',
        'part:GetPropertyChangedSignal("Material")',
        'part.AncestryChanged',
        'if Policy.isOwnedVariant(part.MaterialVariant) then',
        'if desired == "" and not Policy.isOwnedVariant(part.MaterialVariant) then',
        'if Policy.isOwnedVariant(current) then',
        'player:GetAttributeChangedSignal("IronYardGraphicsPreset")',
        'MaterialService.ChildAdded',
        'MaterialService.ChildRemoved',
        'script.Destroying:Connect',
    ]),
    (policy, [
        'function Policy.clientVariant(key, baseName, preset)',
        'function Policy.isOwnedVariant(name)',
        'if name == Policy.variantName(style.key) then return true end',
        'if key == style.key and baseName == style.base then',
        'if preset == "ECO" then return "" end',
        'return nil',
    ]),
    (overlay, [
        'CollectionService:GetTagged("IronYardWorldPbr")',
        'worldRendered, worldTagged',
    ]),
    (ci, [
        './luau scripts/test_world_pbr_policy.luau',
        'python3 scripts/check_world_pbr_client_bridge.py',
    ]),
):
    for needle in requirements:
        assert needle in text, f"Missing client PBR bridge guarantee: {needle}"
print("IRON YARD world PBR: approved tag replication, client fallback, ECO and streaming contract OK")
