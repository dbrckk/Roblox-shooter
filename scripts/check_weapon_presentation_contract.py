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
):
    assert needle in visuals, f"Weapon visuals not wired: {needle}"

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
