#!/usr/bin/env python3
"""Offline contract: bot cosmetic streaming LOD never affects combat rigs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
client = (ROOT / "src/client/BotLOD.client.luau").read_text()
pure = (ROOT / "src/shared/BotDetailCache.luau").read_text()
visuals = (ROOT / "src/server/BotVisuals.luau").read_text()

required = (
    'Shared:WaitForChild("BotDetailCache")',
    "local botCache = {}",
    "local function watchBot(model)",
    "model.DescendantAdded:Connect(inspectPart)",
    "model.DescendantRemoving:Connect(function(item)",
    'part:GetAttributeChangedSignal("NeonCosmeticTier")',
    "BotDetailCache.observe(entry.state, part, tier)",
    "BotDetailCache.remove(entry.state, part)",
    "BotDetailCache.decide(entry.state,",
    "entry.state.hidden == true",
    "local function releaseBot(model)",
    "connection:Disconnect()",
    "folder.ChildRemoved:Connect(releaseBot)",
    "local delta = root.Position - from",
    "return delta:Dot(delta)",
    "if not changed then return end",
    "local function updateArt()",
)
for token in required:
    assert token in client, f"Bot streaming LOD cache disconnected: {token}"
assert client.count("model:GetDescendants()") == 1, (
    "Cosmetic inventory must be read ONCE at model registration, never each polling tick")
assert "model:GetDescendants()" not in client.split("local function updateModel(model)")[1].split(
    "-- Server-authored visual art")[0], "Bot update must be O(1) when the mode stays unchanged"
assert 'item.LocalTransparencyModifier = hidden and 1 or 0' not in client, (
    "Do not revert to per-second writes for every bot descendant")
assert 'tier == "Detail"' in client and 'tier == "Detail"' in pure, (
    "Core rig and authoritative hitbox parts must stay visible and collidable")
assert 'part.CanCollide =' not in client and 'part.CanQuery =' not in client, (
    "Client LOD must never alter Roblox collisions or combat query behavior")
assert "local function applyGroupState(group, hidden)" in client, (
    "Unrelated static environment art LOD must be preserved")
assert 'p:SetAttribute("NeonCosmeticTier", tier or "Detail")' in visuals, (
    "Bot cosmetics must continue carrying source-of-truth tier attributes")
print("IRON YARD cached bot visuals: live streaming, core safety and fixed-cost LOD: OK")
