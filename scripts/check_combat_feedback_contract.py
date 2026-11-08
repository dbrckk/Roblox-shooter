#!/usr/bin/env python3
"""Contract check for authenticated client combat readouts.

Pure Luau validates real-health-loss math. This checks the actual server/client
wiring without pretending to run Roblox humanoid damage or render the HUD.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def load(path):
    return (root / path).read_text(encoding="utf-8")

server = load("src/server/WeaponService.luau")
client = load("src/client/init.client.luau")
hud = load("src/client/HudController.luau")
policy = load("src/shared/CombatFeedbackPolicy.luau")
vfx = load("src/shared/CombatVfxProfile.luau")

def requires(src, needles, label):
    for needle in needles:
        assert needle in src, f"{label}: missing {needle!r}"

requires(policy, (
    "function Feedback.actualDamage(before, after)",
    "function Feedback.readout(kind, damage, headshot)",
    "if kind == \"Protected\" then return \"SPAWN SHIELD\" end",
    'if kind ~= "Hit" or not finite(damage) or damage <= 0 then return nil end',
), "Pure feedback")
requires(server, (
    'local FeedbackPolicy = require(shared:WaitForChild("CombatFeedbackPolicy"))',
    "local function sendProtected(player, weaponId)",
    "state.nextProtectedNoticeAt = now + 0.45",
    'sendFeedback(player, { kind = "Protected", weaponId = weaponId })',
    "if SpawnService.isProtected(targetCharacter) then",
    "sendProtected(attacker, weaponId)",
    "if (opponent or model:GetAttribute(\"IsArenaBot\") == true)",
    "and SpawnService.isProtected(model) then",
    "struckShield = true",
    "if not anyHit and struckShield then",
    "sendProtected(player, weaponId)",
    "FeedbackPolicy.actualDamage(healthBefore, targetHumanoid.Health)",
    "FeedbackPolicy.actualDamage(oldHealth, humanoid.Health)",
    "remotes.WeaponFeedback:FireClient(player, message)",
    "humanoid:TakeDamage(damage)",
    "targetHumanoid:TakeDamage(damage)",
), "Server-owned combat")
assert 'kind = "Miss"' not in server, (
    "Do not replicate unused miss messages on every accepted rifle/shotgun shot"
)
requires(client, (
    'message.kind == "Hit"',
    'message.kind == "Protected"',
    "hud:showHitFeedback(message)",
    "hud:showProtectedFeedback()",
    "visuals:drawConfirmedHit(message.hitPosition, message.headshot, message.killed)",
), "Client reception")
requires(hud, (
    'local FeedbackPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatFeedbackPolicy"))',
    'local CombatVfxProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatVfxProfile"))',
    'readout.Name = "DamageReadout"',
    "function HudController:showHitFeedback(message)",
    "function HudController:showProtectedFeedback()",
    'FeedbackPolicy.readout("Hit", message.damage, headshot)',
    'FeedbackPolicy.readout("Protected")',
    "CombatVfxProfile.shouldDisplayHit(now,",
    "self.lastConfirmedHudHitPriority = priority",
    "self.damageReadoutToken == token",
    'self.hitMarker.Text = "×"',
), "Public HUD")
requires(vfx, (
    "function Profile.hitPriority(headshot, killed)",
    "function Profile.shouldDisplayHit(now, lastAt, lastPriority, priority)",
), "Kill-first short-lived hit priority")
print("IRON YARD actual damage, spawn-shield readout, kill-priority and no miss spam: OK")
