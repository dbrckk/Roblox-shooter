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
remote_budget = load("src/shared/RemoteCombatFxBudget.luau")

def requires(src, needles, label):
    for needle in needles:
        assert needle in src, f"{label}: missing {needle!r}"

requires(policy, (
    "function Feedback.actualDamage(before, after)",
    "function Feedback.readout(kind, damage, headshot)",
    "function Feedback.markerStyle(priority)",
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
    "local damageAllowed = canDamage(player, opponent, model)",
    'if not targetPlayer and targetCharacter:GetAttribute("IsArenaBot") ~= true then',
    "if damageAllowed and SpawnService.isProtected(model) then",
    "struckShield = true",
    "if not anyHit and struckShield then",
    "sendProtected(player, weaponId)",
    "FeedbackPolicy.actualDamage(healthBefore, targetHumanoid.Health)",
    "FeedbackPolicy.actualDamage(oldHealth, humanoid.Health)",
    "message.epoch = weaponRoundEpoch",
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

feedback_handler = client.split("remotes.WeaponFeedback.OnClientEvent:Connect", 1)[1].split(
    "remotes.WeaponFx.OnClientEvent:Connect", 1
)[0]
combat = feedback_handler.split('elseif message.kind == "Ammo"', 1)[0]
guard = combat.index("FireEpochPolicy.acceptFeedback(message.epoch,")
for effect in ("hud:showHitFeedback", "visuals:drawConfirmedHit", "hud:showProtectedFeedback"):
    assert guard < combat.index(effect), "Old combat packets must be rejected before any cue"
assert feedback_handler.count("advanceFeedbackEpoch(message.epoch)") == 2
assert "advanceFeedbackEpoch(epoch)" in client.split(
    'workspace:GetAttributeChangedSignal("IronYardFireEpoch"):Connect(function()', 1
)[1].split("end)", 1)[0]
reset = hud.split("function HudController:resetCombatFeedback()", 1)[1].split(
    "function HudController:showProtectedFeedback()", 1
)[0]
requires(reset, (
    "self.hitToken += 1",
    "self.damageReadoutToken += 1",
    "self.eliminationToken += 1",
    "self.hitMarker.Visible = false",
    "self.damageReadout.Visible = false",
    "self.eliminationConfirmation.Visible = false",
    "self.hitConfirmSound:Stop()",
), "Round transition clears and invalidates HUD cues")

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
    'markerLine("HitArm"',
    'markerLine("EliminationArm"',
    'markerLine("HeadshotChevron"',
    "previous and previous.duration",
    "self.hitMarkerPulse:Play()",
    "hitSound.Parent = SoundService",
    "self.hitConfirmSound = hitSound",
    "FeedbackPolicy.soundVolume(style, self.hitSoundLevel)",
    "if volume > 0 then",
    "if not readoutText then return end",
    "self.hitToken == token",
), "Public HUD")

hit_cue = hud.split("function HudController:showHitFeedback(message)", 1)[1]
assert hit_cue.index("self.hitMarker.Visible = true") < hit_cue.index("if not GuiService.ReducedMotionEnabled then")
assert hit_cue.index("if not GuiService.ReducedMotionEnabled then") < hit_cue.index("self.hitMarkerPulse:Play()")
assert "\n    end\n\n    local volume = FeedbackPolicy.soundVolume" in hit_cue
requires(vfx, (
    "function Profile.hitPriority(headshot, killed)",
    "function Profile.shouldDisplayHit(now, lastAt, lastPriority, priority, lowerPriorityHold)",
), "Kill-first short-lived hit priority")
requires(remote_budget, (
    'local Vfx = require("./CombatVfxProfile")',
    'function Budget.allow(state, now, preset, touch, distance, kind)',
    'if not limit or not Vfx.budget(preset, touch, distance) then return false end',
    'bucket.tokens -= 1',
    'PLAYER = { rate = 10, burst = 3 }',
    'BOT = { rate = 7, burst = 3 }',
), "Bounded remote visual groups")
requires(client, (
    'local remoteFxState = RemoteCombatFxBudget.new()',
    'local ownShot = message.shooterUserId == player.UserId',
    'remoteFxState, os.clock(),',
    '(cameraNow.CFrame.Position - message.origin).Magnitude, "PLAYER")',
    'UserInputService.TouchEnabled, visualDistance, "BOT")',
    'if remoteAccepted then',
    '(ownShot or remoteAccepted) and typeof(message.pelletImpacts) == "table"',
), "Human/bot remote group admissions and unthrottled own-shot feedback")
assert client.count('RemoteCombatFxBudget.allow(') == 2, (
    "Exactly two remote visuals pathways must be admitted once per group"
)
print("IRON YARD actual damage, spawn-shield readout, kill priority and remote FX quotas: OK")
