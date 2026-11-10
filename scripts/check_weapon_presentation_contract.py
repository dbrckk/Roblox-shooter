#!/usr/bin/env python3
"""Validate live client integration of deterministic weapon feel and audio.

Pure Luau tests verify profiles. This checks source wiring, not Roblox rendering
or final sound licensing; all audio still uses existing bundled Roblox sounds.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def get(path):
    return (root / path).read_text(encoding="utf-8")

feel = get("src/shared/WeaponFeelProfile.luau")
audio = get("src/shared/WeaponAudioPolicy.luau")
visuals = get("src/client/WeaponVisuals.luau")
client = get("src/client/init.client.luau")
server = get("src/server/WeaponService.luau")
config = get("src/shared/WeaponConfig.luau")
ejection = get("src/shared/CartridgeEjectionPolicy.luau")
ads = get("src/shared/WeaponAimPose.luau")

for needle in (
    "function Feel.get(id)", "function Feel.kick(id, current, added)",
    "function Feel.recover(id, current, dt)",
    "function Feel.shotEnvelope(id, age)", "function Feel.mechanism(id, age)",
):
    assert needle in feel, f"Pure weapon feel missing: {needle}"

for needle in (
    "function Audio.select(preset, mobile, distance, localShot, activeVoices, weaponId)",
    "if localShot then", "activeVoices >= maxVoices",
    "distance > maxDistance", "layers = far and 1 or 2",
    "REACH[weaponId] or 1",
    "function Audio.needsOcclusion(distance, localShot)",
    "function Audio.occludedMix(mix, blocked)",
    "volume = mix.volume * 0.40",
    "highGain = -24", "midGain = -12",
    "highGain = far and -10 or 0",
):
    assert needle in audio, f"Audio admission missing: {needle}"

for needle in (
    'WaitForChild("WeaponFeelProfile")',
    'WaitForChild("WeaponAudioPolicy")',
    "self.recoil = WeaponFeel.kick(weaponId, self.recoil, config.recoilKick or 0.08)",
    "self.recoil = WeaponFeel.recover(self.currentWeaponId, self.recoil, deltaTime)",
    "WeaponFeel.shotEnvelope(self.currentWeaponId,",
    "WeaponFeel.mechanism(self.currentWeaponId, shotAge)",
    "function WeaponVisuals:_syncScopeVisibility()",
    "ViewmodelRenderPolicy.needsUpdate(",
    "ViewmodelRenderPolicy.transparency(",
    "feel.reloadPitch * reloadingPose",
    "feel.handTravel",
    'partName == "ChargingHandle"',
    'partName == "PumpAction"',
    'partName == "Bolt"',
    'partName == "Slide"',
    "function WeaponVisuals:playFireSound(weaponId, origin, localShot)",
    "WeaponAudio.select(",
    "UserInputService.TouchEnabled, distance, ownShot, #self.remoteSoundEmitters, weaponId)",
    "self.remoteSoundEmitters = {}",
    "table.insert(self.remoteSoundEmitters, emitter)",
    "if index > mix.layers then break end",
    "Debris:AddItem(emitter, mix.lifetime)",
    "if WeaponAudio.needsOcclusion(distance, ownShot) then",
    "params.RespectCanCollide = true",
    "params.IgnoreWater = true",
    "workspace:Raycast(",
    "mix = WeaponAudio.occludedMix(mix, cover ~= nil)",
    'Instance.new("EqualizerSoundEffect")',
    'eq.Name = "IronYardDistanceFilter"',
    "eq.HighGain = mix.highGain or 0",
    "eq.MidGain = mix.midGain or 0",
    "eq.LowGain = mix.lowGain or 0",
    "if (mix.highGain or 0) < 0 or (mix.midGain or 0) < 0 then",
):
    assert needle in visuals, f"Weapon visuals not wired: {needle}"

for needle in (
    "function Policy.plan(weaponId, preset, touch, shotNumber)",
    'preset == "ECO"', "function Policy.arc(progress, height)",
    "AssaultRifle =", "Pistol =", "Shotgun =", "Sniper =",
):
    assert needle in ejection, f"Spent-shell policy missing: {needle}"
for needle in (
    'WaitForChild("CartridgeEjectionPolicy")',
    "function WeaponVisuals:_ejectCartridge(plan)",
    'name = "IronYardSpentCartridge"',
    "shape = Enum.PartType.Cylinder",
    "priority = 1",
    "slot.arcHeight = spec.arcHeight or 0",
    "slot.spinAngle = spec.spinAngle or 0",
    "CartridgeEjection.arc(t, slot.arcHeight)",
    "local pending = self.pendingCartridge",
    "self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap",
    "function WeaponVisuals:kick(weaponId)",
    "CartridgeEjection.plan(weaponId,",
    "self:_ejectCartridge(pending.plan)",
):
    assert needle in visuals, f"Client casings not wired: {needle}"
assert visuals.count("function WeaponVisuals:_ejectCartridge(plan)") == 1
assert visuals.index("self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap") < (
    visuals.index("function WeaponVisuals:_ejectCartridge(plan)"))
assert "FireServer" not in ejection and "Instance.new" not in ejection
for needle in (
    "function Pose.get(id)", "function Pose.damping(blend)",
    "sightX = 0, sightY = 0.32, sightZ = -0.05",
    "sightX = 0, sightY = 0.30, sightZ = 0.10",
    "sightX = 0, sightY = 0.24, sightZ = -0.28",
):
    assert needle in ads, f"ADS policy missing: {needle}"
for needle in (
    'WaitForChild("WeaponAimPose")',
    "WeaponAimPose.damping(self.aimBlend)",
    "self.aimPose = pose and CFrame.new(pose.x, pose.y, pose.z) or nil",
    "offset:Lerp(self.aimPose, self.aimBlend)",
    '"ScopeAdjustmentTurret"', '"ScopeAdjustmentCap"',
    '"RearSight", Vector3.new(0.19, 0.09, 0.14)',
):
    assert needle in visuals, f"Sight geometry or pose missing: {needle}"
assert "local aimOffset = CFrame.new(-0.40, 0.13, -0.14)" not in visuals
assert "if currentWeaponId ~= weaponId and scoped then" in client
assert client.index("if currentWeaponId ~= weaponId and scoped then") < client.index(
    "currentWeaponId = weaponId", client.index("local function equipWeapon("))
assert "visuals:playFireSound(weaponId, ray.Origin, true)" in client, (
    "Locally predicted shot must never be culled as a remote shot"
)
assert "visuals:playFireSound(message.weaponId, message.origin)" in client, (
    "Remote gun audio must pass through spatial voice budget"
)
assert "self.recoil - deltaTime * 5.5" not in visuals, (
    "Generic 5.5/s recoil no longer belongs in weapon handling"
)
assert "targetHumanoid:TakeDamage(damage)" in server
assert "fireCooldown = 0.115" in config, "Server/weapon cadence not rewritten"
print("IRON YARD five original viewmodels and bounded spatial audio wiring: OK")
