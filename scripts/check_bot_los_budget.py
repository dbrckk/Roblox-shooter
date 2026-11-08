#!/usr/bin/env python3
"""Build-time guard for shared bot LOS selection/aim and client bot VFX LOD.

It does NOT substitute for measuring Roblox raycast cost or client frame time.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bot = (ROOT / "src/server/BotService.luau").read_text(encoding="utf-8")
selector = (ROOT / "src/shared/BotTargetSelection.luau").read_text(encoding="utf-8")
client = (ROOT / "src/client/init.client.luau").read_text(encoding="utf-8")

def required(source, fragments, area):
    for fragment in fragments:
        assert fragment in source, f"{area} missing: {fragment}"

required(bot, (
    "local visibleAimPoint = nil",
    "visibleAimPoint = head.Position",
    "if visible then visibleAimPoint = torsoPoint end",
    "aimPoint = visible and visibleAimPoint or nil",
    "local best, seenPosition, aimPoint = BotTargetSelection.choose(",
    "return best, aimPoint",
    "local target, aimPoint = nil, nil",
    "target, aimPoint = getTargetModel(bot, config.MaximumSightDistance)",
    "if phase == \"LIVE\" and target and aimPoint then",
    "local shotParams = rayParams(bot.model)",
    "Workspace:Raycast(origin, direction, shotParams)",
    "Workspace:Raycast(origin, rayDirection * config.MaximumAttackDistance, shotParams)",
), "bot combat LOS")
assert "local function visibleAimPoint(bot, model)" not in bot, (
    "Duplicate target LOS must not be reintroduced as a second aim pass"
)
acquisition = bot.split("local function getTargetModel(bot, limit)", 1)[1].split(
    "\nlocal function rayParams(ignore)", 1
)[0]
assert acquisition.count("Workspace:Raycast(") == 2, (
    "Head and optional torso acquisition must be the only LOS probes per candidate"
)
assert "if direction.Magnitude <= limit then" in acquisition
assert "if not visible then" not in acquisition or "memoryDistance" in acquisition
assert "if SpawnService.isProtected(model) then return end" in acquisition
assert "memoryDistance = (bot.lastKnownTargetPosition - bot.root.Position).Magnitude" in acquisition

required(selector, (
    "local best, highest, verified, verifiedAim",
    "previousAim = visible and entry.aimPoint or nil",
    "verifiedAim = visible and entry.aimPoint or nil",
    "return previous, previousPosition, previousAim",
    "return best, verified, verifiedAim",
    "local distance = visible and entry.distance or entry.memoryDistance",
), "target/aim association")
required(client, (
    'local CombatVfxProfile = require(shared:WaitForChild("CombatVfxProfile"))',
    "local botFxBudget = CombatVfxProfile.budget(",
    'player:GetAttribute("IronYardGraphicsPreset")',
    "UserInputService.TouchEnabled, visualDistance",
    "and botFxBudget",
    'message.kind == "BotTracer"',
    'visuals:drawTracer(message.origin, message.direction.Unit, distance, accent)',
), "client bot tracer effect gating")

print("IRON YARD same-sighting bot aim, muzzle validation and graphics-tier bot FX: OK")
