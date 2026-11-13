#!/usr/bin/env python3
"""Owner-only live PBR appearance introspection must not affect public gameplay."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
overlay = (ROOT / "src/client/PerfOverlay.client.luau").read_text()
bot = (ROOT / "src/server/BotVisuals.luau").read_text()
loader = (ROOT / "src/server/VanguardAssetLoader.luau").read_text()
world = (ROOT / "src/server/WorldPbrMaterials.luau").read_text()
ci = (ROOT / ".github/workflows/rojo-build.yml").read_text()

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
assert overlay.count('.. pbrSnapshot() .. localSwapSummary()') == 2, (
    "Include PBR readiness both before and after server telemetry is available")
assert 'model:SetAttribute("NeonVisualSource", "PBR_MESH")' in bot
assert 'Workspace:SetAttribute("IronYardPbrStatus", "READY")' in loader
assert 'Workspace:SetAttribute("IronYardWorldPbrStatus", "CONFIGURED")' in world
assert 'python3 scripts/check_owner_pbr_diagnostics.py' in ci
print("IRON YARD mobile owner-private PBR runtime observability: OK")
