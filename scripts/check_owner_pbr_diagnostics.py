#!/usr/bin/env python3
"""Owner-only live PBR appearance introspection must not affect public gameplay."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
overlay = (ROOT / "src/client/PerfOverlay.client.luau").read_text()
weapon_loader = (ROOT / "src/server/WeaponAssetLoader.luau").read_text()
weapon_plan = (ROOT / "src/shared/WeaponAssetLoadPlan.luau").read_text()
bot = (ROOT / "src/server/BotVisuals.luau").read_text()
loader = (ROOT / "src/server/VanguardAssetLoader.luau").read_text()
world = (ROOT / "src/server/WorldPbrMaterials.luau").read_text()
ci = (ROOT / ".github/workflows/rojo-build.yml").read_text()
art = (ROOT / "src/server/ArenaArt.luau").read_text()

for required in (
    'if not RunService:IsStudio() and not (',
    'player.UserId == game.CreatorId',
    'local function pbrSnapshot()',
    'bot:GetAttribute("IsArenaBot") == true',
    'bot:GetAttribute("NeonVisualSource") == "PBR_MESH"',
    'child:IsA("MeshPart")',
    'child:GetAttribute("NeonCosmeticTier") == "Detail"',
    'child.LocalTransparencyModifier < 0.5',
    'for _, bot in ipairs(folder:GetChildren()) do',
    'for _, child in ipairs(bot:GetDescendants()) do',
    'Workspace:GetAttribute("IronYardPbrStatus")',
    'Workspace:GetAttribute("IronYardWorldPbrStatus")',
    'if not active then return end',
):
    assert required in overlay, "Missing secure owner diagnostic: " + required
for needle in (
    "local function weaponDeliverySnapshot()",
    '"IronYardWeaponState_" .. weaponId',
    'Workspace:GetAttribute("IronYardWeaponMeshReadyCount")',
    'label.AutomaticSize = Enum.AutomaticSize.Y',
    'scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y',
    'panel.Size = UDim2.new(0, 300, 1, -110)',
    'panelLimit.MaxSize = Vector2.new(300, 485)',
    '.. weaponDeliverySnapshot()',
):
    assert needle in overlay, f"Owner-only PBR delivery / safe-scroll diagnosis missing: {needle}"
for needle in (
    'Plan.MAX_FETCH_ATTEMPTS = 3',
    'function Plan.retryDelay(failedAttempt)',
):
    assert needle in weapon_plan, f"Unsafe or missing bounded retry: {needle}"
for needle in (
    'local function fetchOwnedModel(assetId)',
    'AssetService:LoadAssetAsync(assetId)',
    'if attempt < LoadPlan.MAX_FETCH_ATTEMPTS then',
    'task.wait(LoadPlan.retryDelay(attempt))',
    'error("ASSET_DELIVERY_FAILED: " .. lastError, 0)',
    '"DELIVERY_FAILED" or "VALIDATION_FAILED"',
    'publishWeaponState(job.weaponId, "LOADING")',
    'publishWeaponState(job.weaponId, finalState)',
    'validPair(root:FindFirstChild(job.weaponId)',
):
    assert needle in weapon_loader, f"Weapon import fail-closed recovery missing: {needle}"
assert weapon_loader.index('local package = fetchOwnedModel(assetId)') < (
    weapon_loader.index('local selected = Layout.collect(package,')
), "Never retry model content validation or bypass owner whitelists"
for needle in (
    'local WorldPbrPolicy = require(Shared:WaitForChild("WorldPbrPolicy"))',
    'for _, style in ipairs(WorldPbrPolicy.Materials) do',
    'local group = type(key) == "string" and byFamily[key] or nil',
    'part.MaterialVariant == WorldPbrPolicy.variantName(key)',
    '"ROOF / pitched corrugated shell"',
    'Roof: %d/%d',
    'table.concat(familyLines, "\\n")',
):
    assert needle in overlay, f"Missing live owner-only material coverage: {needle}"
assert 'WorldPbr.apply(sheet, "warehouse_steel")' in art
assert overlay.count('.. pbrSnapshot() .. localSwapSummary()') == 2, (
    "Include PBR readiness both before and after server telemetry is available")
assert 'model:SetAttribute("NeonVisualSource", "PBR_MESH")' in bot
assert 'Workspace:SetAttribute("IronYardPbrStatus", "READY")' in loader
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "CONFIGURED")' in world
assert 'python3 scripts/check_owner_pbr_diagnostics.py' in ci
print("IRON YARD mobile owner-private PBR runtime observability: OK")
