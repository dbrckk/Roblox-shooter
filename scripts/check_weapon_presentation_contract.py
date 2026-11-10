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
scope_fov = get("src/shared/ScopeFovPolicy.luau")
hud = get("src/client/HudController.luau")
crosshair = get("src/shared/CrosshairFeedbackPolicy.luau")

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

# The cosmetic reload must use real server Ammo state and no new animation loop.
reload_visual = get("src/shared/ShotgunReloadVisual.luau")
for needle in (
    "function Visual.sample(progress, reloading, graphicsPreset)",
    'graphicsPreset == "ECO"',
    'reloading ~= true',
):
    assert needle in reload_visual, f"Shotgun loading policy missing: {needle}"
for needle in (
    'WaitForChild("ShotgunReloadVisual")',
    '"ShotgunEjectionPort"',
    '"ShotgunLoadingPort"',
    '"CarrierShellBody" .. i',
    '"CarrierShellBrass" .. i',
    '"LoadingShellBody"',
    '"LoadingShellBrass"',
    'shellX, shellY, shellZ, shellRoll = ShotgunReloadVisual.sample(',
    'local targetAlpha = shellX and not self.lastViewmodelHidden and 0 or 1',
    'if entry.part.Transparency ~= targetAlpha then',
):
    assert needle in visuals, f"Shotgun reload model / visible mechanism missing: {needle}"
assert 'Shotgun = { anchor = "ShotgunEjectionPort"' in ejection
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1
assert 'FireServer' not in reload_visual and 'Instance.new' not in reload_visual
assert 'return {' not in reload_visual, "No per-frame allocation of shell pose tables"
assert 'local loadingShell = self.currentWeaponId' not in visuals, (
    "Shotgun reload viewmodel must consume scalar motion, not tables")

# Scoped rifle and AR-24 viewmodels gained deterministic detail geometry.
# These create geometry only on equip, never in combat frame callbacks.
for needle in (
    '"ScopeRingFront"',
    '"ScopeRingRear"',
    '"ScopeEyepiece"',
    '"BoltHandle"',
    '"BoltHandleKnob"',
    'or partName == "BoltHandleKnob") and self.currentWeaponId == "Sniper"',
    '"ReceiverDeflector"',
    '"SelectorDial"',
    '"GasBlock"',
    '"VentLeft" .. i',
    '"VentRight" .. i',
    '"RailTooth" .. i',
    'for i = 1, 3 do',
):
    assert needle in visuals, f"Detailed 3D firearm part missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Precision models must not add a second frame loop"
)
# The material-detail loops are authored inside equip-time constructor functions.
assert visuals.index('"VentLeft" .. i') < visuals.index('function WeaponVisuals:_createShotgun')
assert visuals.index('"ScopeRingFront"') < visuals.index('function WeaponVisuals:_createAssaultRifle')

# Reproducible first-person mechanical detailing is device-L0D bounded.
detail_plan = get("src/shared/WeaponDetailPlan.luau")
for needle in (
    'function Plan.tier(preset, touch)',
    'function Plan.get(weapon, preset, touch)',
    'CACHE[weapon][tier] = allowed',
    'if preset == "ECO" then return 1 end',
    'if touch == true and preset ~= "QUALITY" then return 2 end',
):
    assert needle in detail_plan, f"Weapon detail tier plan missing: {needle}"
for needle in (
    'WaitForChild("WeaponDetailPlan")',
    'function WeaponVisuals:_addDetailGeometry(model, weaponId)',
    'self:_addDetailGeometry(model, "Pistol")',
    'self:_addDetailGeometry(model, "Knife")',
    'or string.sub(partName, 1, 11) == "SlideDetail"',
    'self.parts[#self.parts].finishRole = spec.finish',
):
    assert needle in visuals, f"Viewmodel cosmetic detail rendering missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Details must use the existing viewmodel renderer"
)

# Mechanically linked pieces share transforms in the existing frame loop.
for needle in (
    '"MagazineBase", Vector3.new(0.22, 0.09, 0.20)',
    '"Extractor", Vector3.new(0.035, 0.032, 0.14)',
    'local supportMotion = self.currentWeaponId == "Shotgun"',
    'localOffset = localOffset * workingHand * supportMotion',
    '(partName == "Magazine" or partName == "MagazineBase")',
    '(partName == "Slide" or partName == "EjectionPort"',
    'or partName == "Extractor"',
    'or string.sub(partName, 1, 11) == "SlideDetail")',
    'and self.currentWeaponId == "Pistol" then',
):
    assert needle in visuals, f"Moving first-person weapon part missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Mechanical motion must reuse the existing single frame loop"
)
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
assert "function Scope.fieldOfView(baseFov, scoped, config)" in scope_fov
for needle in (
    'WaitForChild("ScopeFovPolicy")',
    "ScopeFovPolicy.fieldOfView(baseFieldOfView, scoped, config)",
    "local function applyCameraFov()",
    "if camera.FieldOfView ~= target then",
    "local function setScoped(enabled)",
    "if enabled == scoped then",
    "setScoped(false)\n\t\tenforceFirstPerson()",
    'workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()',
    "task.defer(enforceFirstPerson)",
):
    assert needle in client, f"Camera FOV and respawn resilience missing: {needle}"
assert "if camera and not scoped then" not in client, (
    "Camera replacement must also restore scoped magnification")
assert "if not camera then\n\t\treturn\n\tend\n\n\tlocal config" not in client, (
    "Missing camera must not prevent scope state cleanup")
assert "visuals:playFireSound(weaponId, ray.Origin, true)" in client, (
    "Locally predicted shot must never be culled as a remote shot"
)
assert "visuals:playFireSound(message.weaponId, message.origin)" in client, (
    "Remote gun audio must pass through spatial voice budget"
)
assert "self.recoil - deltaTime * 5.5" not in visuals, (
    "Generic 5.5/s recoil no longer belongs in weapon handling"
)
for needle in (
    'scopeRing.Size = UDim2.fromScale(0.55, 0.55)',
    'Instance.new("UIAspectRatioConstraint")',
    'aspect.DominantAxis = Enum.DominantAxis.Height',
    'Instance.new("UISizeConstraint")',
    'sizeLimit.MinSize = Vector2.new(150, 150)',
    'sizeLimit.MaxSize = Vector2.new(350, 350)',
    'segment("ScopeLeftStadia"', 'segment("ScopeRightStadia"',
    'segment("ScopeTopStadia"', 'segment("ScopeBottomStadia"',
    'segment("ScopeCenterDot"', 'segment("ScopeWindageTick"',
    'segment("ScopeElevationTick"', 'self.hitMarker.ZIndex = 4',
    'self.damageReadout.ZIndex = 4', 'self.eliminationConfirmation.ZIndex = 4',
    'self.scopeOverlay.Visible = scoped and isOptical',
    'self.scopeRing.Visible = scoped and isOptical',
):
    assert needle in hud, f"Missing optically scoped UI element: {needle}"
assert 'scopeRing.Size = UDim2.fromOffset(310, 310)' not in hud
assert 'RenderStepped:Connect' not in hud, "Sniper UI must not add a frame loop"
for needle in (
    "function Policy.kick(weaponId, previous)",
    "function Policy.recover(previous, dt)",
    "function Policy.radius(weaponId, moveAmount, sprinting, kick)",
    "function Policy.shouldDraw(now, previousAt, previousRadius, radius)",
):
    assert needle in crosshair, f"Cosmetic crosshair policy missing: {needle}"
for needle in (
    'WaitForChild("CrosshairFeedbackPolicy")',
    'function HudController:registerPredictedShot(weaponId)',
    'function HudController:updateCrosshair(dt, moving, running)',
    'CrosshairFeedback.shouldDraw(now,',
    'self.crosshair.Visible = not scoped',
    'self.adsDot.Visible = scoped and not isOptical',
    'self.crosshairLines[1].Position = UDim2.new(0.5, 0, 0.5, -radius)',
    'self.adsDot.BackgroundColor3 = color',
):
    assert needle in hud, f"Adaptive hip-fire / ADS UI missing: {needle}"
assert 'hud:registerPredictedShot(weaponId)' in client
assert 'hud:updateCrosshair(deltaTime, moveAmount, sprinting)' in client
assert client.index('hud:registerPredictedShot(weaponId)') < (
    client.index('remotes.FireWeapon:FireServer({', client.index('local function fireWeapon(')))
assert client.count('RenderStepped:Connect') == 1, (
    "Hip-fire responsiveness must reuse the existing frame callback")
assert "FireServer" not in crosshair and "Instance.new" not in crosshair

assert "targetHumanoid:TakeDamage(damage)" in server
assert "fireCooldown = 0.115" in config, "Server/weapon cadence not rewritten"
print("IRON YARD five original viewmodels and bounded spatial audio wiring: OK")
