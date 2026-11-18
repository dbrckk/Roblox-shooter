#!/usr/bin/env python3
"""Offline UI-wiring regression for private, touch-safe public combat HUD.

Luau layout tests exercise actual geometry; these source contracts verify
that the live Roblox controls consume those positions and settings.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(name):
    return (root / name).read_text(encoding="utf-8")

layout = read("src/shared/TouchLayout.luau")
boost_policy = read("src/shared/BoostMeterPolicy.luau")
combat_policy = read("src/shared/CombatReadoutPolicy.luau")
controller = read("src/client/HudController.luau")
client = read("src/client/init.client.luau")
match = read("src/client/MatchHud.client.luau")
tactical = read("src/client/TacticalHud.client.luau")
briefing = read("src/client/Briefing.client.luau")
kill_feed = read("src/client/KillFeed.client.luau")
damage_direction = read("src/client/DamageDirection.client.luau")
round_results = read("src/client/RoundResults.client.luau")
defeat = read("src/client/DefeatScreen.client.luau")
defeat_presentation = read("src/shared/DefeatPresentation.luau")

for needle in (
    'Layout.PRESETS = { "COMPACT", "STANDARD", "LARGE" }',
    "Layout.MENU_BUTTONS =",
    'local factor = FACTORS[preset or "STANDARD"]',
    'assert(factor, "Unknown touch size preset")',
    'if intersects(r, menu) then',
):
    assert needle in layout, f"Broken mobile geometry/preset: {needle}"

for needle in (
    'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TouchLayout"))',
    'self.touchSizeIndex = 2',
    'self.player:SetAttribute("IronYardTouchSizePreset"',
    'self.touchSizeValueLabel = self:_makeStepper(panel, "BUTTON SIZE"',
    'self.sensitivityValueLabel = self:_makeStepper(panel, "MOUSE SENS"',
    'local settingsRect = TouchLayout.MENU_BUTTONS.Settings',
    'self.gui.DisplayOrder = open and 50 or self.defaultDisplayOrder',
    'SetAttribute("IronYardSettingsOpen", open)',
    'settingsGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets',
    'self.fireAimValueLabel = self:_makeStepper(panel, "FIRE DRAG"',
    'self.hitSoundValueLabel = self:_makeStepper(panel, "HIT SOUND"',
    'self.hitSoundValueLabel.Text = HIT_SOUND_LABELS[self.hitSoundLevel]',
    'if self.hitSoundLevel == 1 then self.hitConfirmSound:Stop() end',
    'panel.SelectionGroup = true',
    'GuiService.MenuClosed:Connect(syncSelection)',
    'GuiService.SelectedObject = self.settingsFocus',
):
    assert needle in controller, f"Mobile settings wiring missing: {needle}"

for needle in (
    'local preset = player:GetAttribute("IronYardTouchSizePreset")',
    "TouchLayout.compute(viewport.X, viewport.Y, preset, jumpBounds)",
    "nativeJumpButton.AbsolutePosition - touchRoot.AbsolutePosition",
    'player:GetAttributeChangedSignal("IronYardTouchSizePreset"):Connect(layoutControls)',
    "TouchLayout.check(viewport.X, viewport.Y, positions)",
    'if not valid then',
    'touchGui.Enabled = enabled',
    'touchGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets',
    'UserInputService.TouchEnded:Connect(releaseEndedTouch)',
    'input.UserInputState == Enum.UserInputState.Cancel',
    'TouchAimPolicy.rotation(delta.X, delta.Y',
):
    assert needle in client, f"Touch control sizing not wired: {needle}"

for needle in (
    'top.Visible = playerGui:GetAttribute("IronYardBriefingOpen") ~= true',
    'gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets',
    'local rect = TouchLayout.MENU_BUTTONS.Duel',
    'playerGui:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(function()',
    '    update()\n    duelLabel()\nend)',
):
    assert needle in match, f"Score overlay still collides with briefing: {needle}"

for needle in (
    'panel.Position = UDim2.new(0.5, 0, 0, 8)',
    'playerGui:GetAttribute("IronYardSettingsOpen") == true',
    'playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(updateGuide)',
    'GuiService.MenuOpened:Connect(updateGuide)',
    'setCardVisible(false)',
):
    assert needle in briefing, f"Briefing obstructs mobile controls: {needle}"

for needle in (
    'WaitForChild("BoostMeterPolicy")',
    'BoostMeterPolicy.shouldDraw(',
    'if not draw then return end',
    'self.lastBoostUpdateAt = now',
    'if self.lastBoostZone ~= zone then',
    'if self.boostTween then self.boostTween:Cancel() end',
    'TweenService:Create(self.boostFill,',
):
    assert needle in controller, f"Boost HUD rendering still allocates per-frame: {needle}"
for needle in ('Policy.MIN_INTERVAL = 0.1',
               'Policy.MIN_DELTA = 0.005',
               'zone ~= Policy.zone(previousRatio)',
               'if ratio == 0 or ratio == 1'):
    assert needle in boost_policy, f"Boost update scheduler lost urgency/budget: {needle}"
assert 'hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)' in client, (
    "Client fuel remains driven by real local movement, not placeholders")
for needle in (
    'WaitForChild("CombatReadoutPolicy")',
    "CombatReadoutPolicy.ammo(loaded, capacity, reloading)",
    "if text ~= self.lastAmmoText then",
    "if tone ~= self.lastAmmoTone then",
    "self.lastAmmoText = nil",
    "self.lastAmmoTone = nil",
    "self.healthBindGeneration = (self.healthBindGeneration or 0) + 1",
    "if self.healthBindGeneration ~= generation",
    "self.player.Character ~= character",
    "CombatReadoutPolicy.health(health, maxHealth)",
    "if ratio ~= self.lastHealthRatio then",
    "if text ~= self.lastHealthText then",
    "if self.healthTween then self.healthTween:Cancel() end",
):
    assert needle in controller, f"Combat readout deduplication missing: {needle}"
for needle in ("function Policy.ammo(", "function Policy.health(",
               '"RELOADING..."', '"CRITICAL"', '"WARNING"'):
    assert needle in combat_policy, f"Combat HUD snapshot policy missing: {needle}"
assert "self:_pulseDamage(self.previousHealth - health)" in controller, (
    "Health UI deduplication must never delay or remove damage feedback")

camera_feel = client.split("local function updateCameraFeel(deltaTime)", 1)[1].split(
    "-- One automatic-fire task", 1
)[0]
assert "followingPlayer and not GuiService.ReducedMotionEnabled" in camera_feel
reduced_camera, standard_camera = camera_feel.split(
    "local grounded = isGrounded(humanoid)", 1
)
for needle in ("cameraRoll = 0", "cameraMotion.descentSpeed = 0",
               "if not motionHumanoid then", "humanoid.CameraOffset = STANDING_CAMERA_OFFSET",
               "followingPlayer and not scoped", "camera.FieldOfView = baseFieldOfView", "return"):
    assert needle in reduced_camera, f"Reduced-motion camera path missing: {needle}"
assert "camera.CFrame *=" not in reduced_camera
assert "camera.CFrame *=" in standard_camera and "baseFieldOfView + fovBonus" in standard_camera
pulse = controller.split("function HudController:_pulseDamage(loss)", 1)[1].split(
    "function HudController:_buildBoostMeter()", 1
)[0]
assert pulse.index("if GuiService.ReducedMotionEnabled then return end") < pulse.index(
    "self.damagePulseFade:Play()")
assert "TweenService:Create" not in pulse, "Repeated damage reuses the fade"
assert 'GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect' in controller
assert "flash.BackgroundTransparency = 1" in controller.split(
    'GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect', 1
)[1].split("end)", 1)[0]
for needle in (
    "if header.Text ~= headerText then header.Text = headerText end",
    "if detail.Text ~= detailText then detail.Text = detailText end",
    "statsGeneration += 1",
    "if statsConnection then",
    "statsConnection:Disconnect()",
    "if generation ~= statsGeneration or stats.Parent ~= player then return end",
    'kills:GetPropertyChangedSignal("Value"):Connect(update)',
):
    assert needle in match, f"Match HUD must reject stale stats and duplicate writes: {needle}"
assert 'stats:WaitForChild("Eliminations", 10)' in match, (
    "Leaderstats replication remains asynchronous, never assume instant availability")
for needle in (
    'local function connectCamera()',
    'if cameraConnection then',
    'cameraConnection:Disconnect()',
    'Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)',
    'if sectorTitle.Text ~= newTitle then',
    'if heading.Text ~= newHeading then',
):
    assert needle in tactical, f"Tactical compass camera lifecycle missing: {needle}"
# The three combat HUD controllers remain alive for the complete match
# session. Camera replacement and 200+ respawns must never accumulate
# connections to old Cameras, Characters or leaderstats IntValues.
for needle in (
    "local cameraConnection = nil",
    "local function reconnectCamera()",
    "cameraConnection:Disconnect()",
    "cameraConnection = nil",
    'Workspace:GetPropertyChangedSignal(\n    "CurrentCamera"):Connect(reconnectCamera)',
    'camera:GetPropertyChangedSignal(\n            "ViewportSize"):Connect(updateFeedLayout)',
    "local killFeedConnection = remotes.KillFeed.OnClientEvent:Connect(addEntry)",
    "killFeedConnection:Disconnect()",
    "currentCameraConnection:Disconnect()",
    "matchConnection:Disconnect()",
    "briefingConnection:Disconnect()",
    "gui:Destroy()",
):
    assert needle in kill_feed, f"Kill feed old-camera/subscription leak: {needle}"
assert kill_feed.count('ViewportSize"):Connect(updateFeedLayout)') == 1, (
    "Only the current camera may own the kill feed ViewportSize listener")
assert kill_feed.count('remotes.KillFeed.OnClientEvent:Connect(addEntry)') == 1

for needle in (
    "local hitConnection = nil",
    "local boundCharacter = nil",
    "local function releaseCharacter()",
    "hitConnection:Disconnect()",
    "boundCharacter = nil",
    "local function clearIndicator()",
    "RunService:UnbindFromRenderStep(RENDER_BINDING)",
    "RunService:BindToRenderStep(RENDER_BINDING, Enum.RenderPriority.Camera.Value + 3, updateIndicator)",
    "Direction.project(offset.X, offset.Z, look.X, look.Z, right.X, right.Z)",
    "Direction.transparency(elapsed, GuiService.ReducedMotionEnabled)",
    "wing.Rotation = side == -1 and 38 or -38",
    "phaseConnection:Disconnect()",
    "pointer.Visible = false",
    'player.CharacterAdded:Connect(bindCharacter)',
    'player.CharacterRemoving:Connect(function(character)',
    "if boundCharacter == character then releaseCharacter() end",
    "if boundCharacter ~= character or player.Character ~= character then return end",
    "addedConnection:Disconnect()",
    "removingConnection:Disconnect()",
    "gui:Destroy()",
):
    assert needle in damage_direction, f"Old character damage UI listener not released: {needle}"
assert damage_direction.count('GetAttributeChangedSignal(\n        "IronYardLastHitTime"):Connect') == 1, (
    "Only the current character's hit timestamp may drive the arrow")

for needle in (
    'DefeatPresentation.labels(',
    'DuelReadout.boutLabel(',
    'phase == "LIVE" or (mode == "DUEL" and phase == "DUEL_BREAK")',
    'if entranceTween then entranceTween:Cancel() end',
    'TweenService:Create(card,',
    'entranceTween:Cancel()',
):
    assert needle in defeat, f"Mode-aware defeat screen missing: {needle}"
for needle in (
    "function Policy.labels(mode, phase, boutSeconds, respawnSeconds, verdict)",
    'and ("NEXT BOUT IN  " .. countdown(boutSeconds) .. "s")',
    '"DUEL  /  NO SECOND LIFE THIS BOUT"',
    '"SPAWN SHIELD 2.5s  /  SHOOT TO CANCEL"',
):
    assert needle in defeat_presentation, f"FFA / duel outcome message missing: {needle}"

for needle in (
    "local activeStats = nil",
    "local statsAddedConnection = nil",
    "local statsRemovedConnection = nil",
    "local statConnections = {}",
    "local statValues = {}",
    "local function releaseStats()",
    "statsAddedConnection:Disconnect()",
    "statsRemovedConnection:Disconnect()",
    "connection:Disconnect()",
    "table.clear(statValues)",
    "activeStats = nil",
    "local function bindValue(value)",
    "if statValues[name] == value then return end",
    "statConnections[name]:Disconnect()",
    "if activeStats == value.Parent and statValues[name] == value then",
    "local function bindStats(stats)",
    "releaseStats()",
    "statsAddedConnection = stats.ChildAdded:Connect(bindValue)",
    "statsRemovedConnection = stats.ChildRemoved:Connect(function(child)",
    "for _, value in ipairs(stats:GetChildren()) do",
    "local playerStatsRemoved = player.ChildRemoved:Connect(function(child)",
    "if child == activeStats then",
    "cameraChangedConnection:Disconnect()",
    "table.clear(attributeConnections)",
    "gui:Destroy()",
):
    assert needle in round_results, f"Round results stale leaderstats or UI listener: {needle}"
assert round_results.count('value:GetPropertyChangedSignal("Value"):Connect(function()') == 1
assert 'value:GetPropertyChangedSignal("Value"):Connect(render)' not in round_results, (
    "Raw stat listeners can fire after a leaderstats container is replaced")
print("IRON YARD combat HUD listeners: current camera, respawn and leaderstats lifecycle: OK")


# Android screenshot regression: cap button typography (including wide
# landscape displays), preserve touch targets, and keep the weapon caption
# compact so it no longer obscures the floor/crosshair.
for needle in (
    'local textLimit = Instance.new("UITextSizeConstraint")',
    'textLimit.MinTextSize = 10',
    'textLimit.MaxTextSize = name == "Fire" and 19 or 16',
    'textLimit.Parent = b',
    'b.TextWrapped = false',
):
    assert needle in client, f"Unbounded Android button text: {needle}"
for needle in (
    'weaponLabel.TextScaled = false',
    'weaponLabel.TextSize = 17',
    'weaponLabel.TextTruncate = Enum.TextTruncate.AtEnd',
):
    assert needle in controller, f"Weapon name obstructs Android view: {needle}"
assert 'b.Size = UDim2.fromOffset(rect.w, rect.h)' in client, (
    "Typography fixes must preserve mobile button hit regions")
bots = read("src/server/BotService.luau")
assert 'marker.AlwaysOnTop = false' in bots, (
    "Bot name and health must not show through opaque walls")
assert 'humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None' in bots, (
    "Roblox native labels must not bypass bot marker occlusion")

print("IRON YARD mobile presets, stable readouts and bounded HUD redraws: OK")
