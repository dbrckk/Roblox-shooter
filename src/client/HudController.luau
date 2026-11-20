local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TouchLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TouchLayout"))
local CombatVfxProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatVfxProfile"))
local FeedbackPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatFeedbackPolicy"))
local BoostMeterPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoostMeterPolicy"))
local CombatReadoutPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatReadoutPolicy"))
local CrosshairFeedback = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrosshairFeedbackPolicy"))
local PracticeMode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
local GamepadCombatPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamepadCombatPolicy"))
local Objectives = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionObjectives"))
local OperatorFinishes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OperatorFinishes"))

local HudController = {}
HudController.__index = HudController

local DEFAULT_FOV = 70
local DEFAULT_SENSITIVITY = 1
local GRAPHICS_PRESETS = { "ECO", "BALANCED", "QUALITY" }
local GRAPHICS_LABELS = { "ECO", "BAL", "HIGH" }
local TOUCH_SIZE_LABELS = { "SMALL", "MED", "LARGE" }
local HIT_SOUND_LABELS = { "OFF", "LOW", "STD" }
local FOOTSTEP_VOLUME_ATTRIBUTE = "IronYardOpponentFootstepVolume"
local FOOTSTEP_VOLUME_STEP = 25
local RELOAD_COLOR = Color3.fromRGB(241, 189, 97)
local RELOAD_BAR_WIDTH = 112
local MARKER_QUADRANTS = {
    { -1, -1, 45 }, { 1, -1, -45 }, { -1, 1, -45 }, { 1, 1, 45 },
}

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function makeText(parent, name, text, position, size, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(247, 244, 235)
	label.TextSize = fontSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(35, 39, 48)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Position = position
	button.Size = size
	button.Text = text
	button.TextColor3 = Color3.fromRGB(247, 244, 235)
	button.TextSize = 14
	button.Parent = parent
	makeCorner(button, 4)
	makeStroke(button, Color3.fromRGB(70, 78, 96), 0.3, 1)
	return button
end

local function clampSetting(value, minValue, maxValue)
	return math.clamp(value, minValue, maxValue)
end

function HudController.new(player, gui, WeaponConfig, options)
	local self = setmetatable({}, HudController)

	self.player = player
	self.gui = gui
    self.defaultDisplayOrder = gui.DisplayOrder
	self.WeaponConfig = WeaponConfig
	self.options = options or {}
	self.currentWeaponId = "AssaultRifle"
	self.hitToken = 0
    self.reticleKick = 0
    self.reticleShotPending = false
    self.reticleKickAt = nil
    self.reticleLastAt = -math.huge
    self.reticleRadius = nil
    self.lastConfirmedHudHitAt = -math.huge
    self.lastConfirmedHudHitPriority = 0
    self.damageReadoutToken = 0
    self.hitSoundLevel = #HIT_SOUND_LABELS
    local storedVolume = player:GetAttribute(FOOTSTEP_VOLUME_ATTRIBUTE)
    self.opponentFootstepVolume = type(storedVolume) == "number" and storedVolume == storedVolume
        and clampSetting(math.round(storedVolume / FOOTSTEP_VOLUME_STEP) * FOOTSTEP_VOLUME_STEP, 0, 100)
        or 100
    player:SetAttribute(FOOTSTEP_VOLUME_ATTRIBUTE, self.opponentFootstepVolume)
	self.settingsOpen = false
	self.baseFov = self.options.baseFov or DEFAULT_FOV
	self.mouseSensitivity = self.options.mouseSensitivity or DEFAULT_SENSITIVITY
    self.touchSizeIndex = 2
    if UserInputService.TouchEnabled then
        self.player:SetAttribute("IronYardTouchSizePreset", TouchLayout.PRESETS[self.touchSizeIndex])
    end
    self.graphicsIndex = UserInputService.TouchEnabled and 2 or 3
    self.player:SetAttribute("IronYardGraphicsPreset", GRAPHICS_PRESETS[self.graphicsIndex])
	self.healthConnections = {}
    self.previousHealth = nil

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	self:_buildCrosshair()
	self:_buildBoostMeter()
	self:_buildHealthBar()
    self:_buildDamagePulse()
	self:_buildWeaponLabel()
    self:_buildAmmoLabel()
	self:_buildScopeOverlay()
	self:_buildSettingsMenu()
	self:_bindHealth(player.Character)

	player.CharacterAdded:Connect(function(character)
		self:_bindHealth(character)
	end)

	return self
end

function HudController:_buildCrosshair()
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundTransparency = 1
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(46, 46)
	crosshair.Parent = self.gui
	self.crosshair = crosshair

	local function addLine(name, size, position)
		local line = Instance.new("Frame")
		line.Name = name
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.fromRGB(247, 244, 235)
		line.BorderSizePixel = 0
		line.Position = position
		line.Size = size
		line.Parent = crosshair
        -- Bright daylight and white sand can wash out plain white crosshairs.
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(31, 37, 36)
        outline.Thickness = 1.2
        outline.Transparency = 0.15
        outline.Parent = line
		return line
	end

	self.crosshairLines = {
        addLine("Top", UDim2.fromOffset(2, 12), UDim2.new(0.5, 0, 0.5, -15)),
        addLine("Bottom", UDim2.fromOffset(2, 12), UDim2.new(0.5, 0, 0.5, 15)),
        addLine("Left", UDim2.fromOffset(12, 2), UDim2.new(0.5, -15, 0.5, 0)),
        addLine("Right", UDim2.fromOffset(12, 2), UDim2.new(0.5, 15, 0.5, 0)),
    }
    -- ADS replaces the four hip-fire bars with a small outlined center dot;
    -- sniper ADS uses the independent calibrated-looking optical reticle.
    local adsDot = Instance.new("Frame")
    adsDot.Name = "IronYardAdsDot"
    adsDot.AnchorPoint = Vector2.new(0.5, 0.5)
    adsDot.Position = UDim2.fromScale(0.5, 0.5)
    adsDot.Size = UDim2.fromOffset(3, 3)
    adsDot.BackgroundColor3 = Color3.fromRGB(235, 235, 222)
    adsDot.BorderSizePixel = 0
    adsDot.Visible = false
    adsDot.Active = false
    adsDot.Parent = self.gui
    makeCorner(adsDot, 999)
    makeStroke(adsDot, Color3.fromRGB(30, 34, 32), 0.08, 1)
    self.adsDot = adsDot

    local hitMarker = Instance.new("Frame")
    hitMarker.Name = "HitMarker"
    hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hitMarker.Position = UDim2.fromScale(0.5, 0.5)
    hitMarker.Size = UDim2.fromOffset(56, 56)
    hitMarker.BackgroundTransparency = 1
    hitMarker.Visible = false
    hitMarker.Parent = self.gui
    self.hitMarker = hitMarker

    local scale = Instance.new("UIScale")
    scale.Parent = hitMarker
    self.hitMarkerScale = scale
    self.hitMarkerPulse = TweenService:Create(scale,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })

    local function markerLine(name, x, y, length, thickness, rotation)
        local line = Instance.new("Frame")
        line.Name = name
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(0.5, x, 0.5, y)
        line.Size = UDim2.fromOffset(length, thickness)
        line.Rotation = rotation
        line.BorderSizePixel = 0
        line.ZIndex = 4
        line.Parent = hitMarker
        makeStroke(line, Color3.fromRGB(24, 28, 27), 0.15, 1)
        return line
    end

    self.hitArms, self.eliminationArms = {}, {}
    for index, direction in ipairs(MARKER_QUADRANTS) do
        local x, y, rotation = table.unpack(direction)
        self.hitArms[index] = markerLine("HitArm", 8 * x, 8 * y, 9, 2, rotation)
        self.eliminationArms[index] = markerLine("EliminationArm", 18 * x, 18 * y, 5, 2, rotation)
    end
    self.headshotChevron = {
        markerLine("HeadshotChevron", -3, -21, 7, 2, -35),
        markerLine("HeadshotChevron", 3, -21, 7, 2, 35),
    }

    local hitSound = Instance.new("Sound")
    hitSound.Name = "IronYardHitConfirm"
    hitSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    hitSound.Parent = SoundService
    self.gui.Destroying:Connect(function() hitSound:Destroy() end)
    self.hitConfirmSound = hitSound

    -- A subtitle beneath the crosshair never obscures the target.
    local elimination = Instance.new("TextLabel")
    elimination.Name = "EliminationConfirmation"
    elimination.AnchorPoint = Vector2.new(0.5, 0.5)
    elimination.Position = UDim2.new(0.5, 0, 0.5, 53)
    elimination.Size = UDim2.fromOffset(230, 28)
    elimination.BackgroundTransparency = 1
    elimination.Font = Enum.Font.GothamBold
    elimination.TextSize = 16
    elimination.TextColor3 = Color3.fromRGB(241, 198, 125)
    elimination.TextStrokeTransparency = 0.35
    elimination.TextStrokeColor3 = Color3.fromRGB(24, 28, 28)
    elimination.Text = ""
    elimination.TextTransparency = 1
    elimination.Visible = false
    elimination.Parent = self.gui
    self.eliminationConfirmation = elimination
    self.eliminationToken = 0

    -- Single reused label: confirmed health loss or spawn shield only.
    -- No per-shot BillboardGui, debris, or UI object allocation.
    local readout = Instance.new("TextLabel")
    readout.Name = "DamageReadout"
    readout.AnchorPoint = Vector2.new(0.5, 0.5)
    readout.Position = UDim2.new(0.5, 0, 0.5, -48)
    readout.Size = UDim2.fromOffset(224, 25)
    readout.BackgroundTransparency = 1
    readout.Font = Enum.Font.GothamBold
    readout.TextSize = 15
    readout.TextColor3 = Color3.fromRGB(227, 234, 218)
    readout.TextStrokeColor3 = Color3.fromRGB(22, 27, 27)
    readout.TextStrokeTransparency = 0.32
    readout.TextXAlignment = Enum.TextXAlignment.Center
    readout.TextTransparency = 1
    readout.Visible = false
    readout.Parent = self.gui
    self.damageReadout = readout
end

function HudController:_buildHealthBar()
	local shell = Instance.new("Frame")
	shell.Name = "HealthBar"
	shell.AnchorPoint = Vector2.new(0, 1)
	shell.BackgroundColor3 = Color3.fromRGB(35, 41, 41)
	shell.BorderSizePixel = 0
	shell.Position = UDim2.new(0, 24, 1, -32)
	shell.Size = UDim2.fromOffset(250, 24)
	shell.Parent = self.gui
	makeCorner(shell, 4)
	makeStroke(shell, Color3.fromRGB(72, 82, 98), 0.25, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(77, 224, 128)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = shell
	makeCorner(fill, 4)

	local text = Instance.new("TextLabel")
	text.Name = "Value"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "100"
	text.TextColor3 = Color3.fromRGB(247, 250, 255)
	text.TextSize = 13
	text.Parent = shell

	self.healthFill = fill
	self.healthText = text
end

function HudController:_buildDamagePulse()
    local flash = Instance.new("Frame")
    flash.Name = "DamagePulse"
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = Color3.fromRGB(177, 60, 50)
    flash.BackgroundTransparency = 1
    flash.BorderSizePixel = 0
    flash.ZIndex = 2
    flash.Active = false
    flash.Parent = self.gui
    self.damagePulse = flash
    self.damagePulseFade = TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1,
    })

    local motionConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
        if not GuiService.ReducedMotionEnabled then return end
        self.damagePulseFade:Cancel()
        flash.BackgroundTransparency = 1
        self.hitMarkerPulse:Cancel()
        self.hitMarkerScale.Scale = 1
    end)
    self.gui.Destroying:Connect(function() motionConnection:Disconnect() end)
end

function HudController:_pulseDamage(loss)
    if GuiService.ReducedMotionEnabled then return end
    self.damagePulseFade:Cancel()
    self.damagePulse.BackgroundTransparency = 1 - math.clamp(loss / 350, 0.05, 0.20)
    self.damagePulseFade:Play()
end

function HudController:_buildBoostMeter()
	local label = Instance.new("TextLabel")
	label.Name = "BoostLabel"
	label.AnchorPoint = Vector2.new(0, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.new(0, 24, 1, -63)
	label.Size = UDim2.fromOffset(74, 16)
	label.Text = "BOOST"
	label.TextColor3 = Color3.fromRGB(235, 198, 135)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = self.gui

	local shell = Instance.new("Frame")
	shell.Name = "BoostMeter"
	shell.AnchorPoint = Vector2.new(0, 1)
	shell.BackgroundColor3 = Color3.fromRGB(35, 41, 41)
	shell.BorderSizePixel = 0
	shell.Position = UDim2.new(0, 84, 1, -66)
	shell.Size = UDim2.fromOffset(190, 10)
	shell.Parent = self.gui
	makeCorner(shell, 4)
	makeStroke(shell, Color3.fromRGB(72, 82, 98), 0.25, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(207, 160, 89)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = shell
	makeCorner(fill, 4)

	self.boostFill = fill
end

function HudController:_buildWeaponLabel()
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.AnchorPoint = Vector2.new(0.5, 1)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Font = Enum.Font.GothamMedium
	weaponLabel.Position = UDim2.new(0.5, 0, 1, -42)
	weaponLabel.Size = UDim2.fromOffset(280, 28)
	weaponLabel.TextColor3 = Color3.fromRGB(247, 244, 235)
	-- Never expand to a billboard-sized heading on high-DPI Android.
	-- The gun name is secondary to crosshair, ammo and touch actions.
	weaponLabel.TextScaled = false
	weaponLabel.TextSize = 17
	weaponLabel.TextXAlignment = Enum.TextXAlignment.Center
	weaponLabel.TextTruncate = Enum.TextTruncate.AtEnd
	weaponLabel.Parent = self.gui
	self.weaponLabel = weaponLabel
end

function HudController:_buildAmmoLabel()
    local t = Instance.new("TextLabel")
    t.Name = "Magazine"
    t.AnchorPoint = Vector2.new(0.5, 1)
    t.Position = UDim2.new(0.5, 0, 1, -12)
    t.Size = UDim2.fromOffset(230, 24)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 15
    t.TextColor3 = Color3.fromRGB(231, 217, 181)
    t.TextStrokeColor3 = Color3.fromRGB(27, 32, 31)
    t.TextStrokeTransparency = 0.4
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.Text = "AMMO  --"
    t.Parent = self.gui
    self.ammoLabel = t

    local track = Instance.new("Frame")
    track.Name = "ReloadProgress"
    track.AnchorPoint = Vector2.new(0.5, 0)
    track.Position = UDim2.new(0.5, 0, 1, 2)
    track.Size = UDim2.fromOffset(RELOAD_BAR_WIDTH, 4)
    track.BackgroundColor3 = Color3.fromRGB(27, 32, 31)
    track.BorderSizePixel = 0
    track.Visible = false
    track.Parent = t
    makeCorner(track, 2)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = RELOAD_COLOR
    fill.BorderSizePixel = 0
    fill.Parent = track
    makeCorner(fill, 2)
    self.reloadTrack = track
    self.reloadFill = fill
end

function HudController:bindTouchReloadButton(button)
    self.touchReloadButton = button
    button.Text = self.touchReloadText or "RLD"

    local track = Instance.new("Frame")
    track.Name = "ReloadProgress"
    track.Position = UDim2.new(0, 4, 1, -6)
    track.Size = UDim2.new(1, -8, 0, 3)
    track.BackgroundColor3 = Color3.fromRGB(27, 32, 31)
    track.BorderSizePixel = 0
    track.Active = false
    track.Visible = self.reloadEndsAt ~= nil
    track.ZIndex = button.ZIndex + 1
    track.Parent = button
    makeCorner(track, 2)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale((self.lastReloadPixels or 0) / RELOAD_BAR_WIDTH, 1)
    fill.BackgroundColor3 = RELOAD_COLOR
    fill.BorderSizePixel = 0
    fill.Active = false
    fill.ZIndex = track.ZIndex + 1
    fill.Parent = track
    makeCorner(fill, 2)
    self.touchReloadTrack = track
    self.touchReloadFill = fill
end

function HudController:updateReloadProgress()
    if not self.reloadEndsAt or self.lastReloadPixels == RELOAD_BAR_WIDTH then return end
    local remaining = self.reloadEndsAt - workspace:GetServerTimeNow()
    local ratio = math.clamp(1 - remaining / self.reloadDuration, 0, 1)
    local pixels = math.max(self.lastReloadPixels or 0, math.floor(ratio * RELOAD_BAR_WIDTH))
    if pixels == self.lastReloadPixels then return end
    self.lastReloadPixels = pixels
    self.reloadFill.Size = UDim2.new(0, pixels, 1, 0)
    if self.touchReloadFill then
        self.touchReloadFill.Size = UDim2.fromScale(pixels / RELOAD_BAR_WIDTH, 1)
    end
end

function HudController:setAmmo(weaponId, loaded, capacity, reloading, reloadEndsAt)
    if weaponId ~= self.currentWeaponId or not self.ammoLabel then return end
    -- Server snapshots may repeat the same loaded/capacity/reload state.
    -- Keep all transitions instant while skipping identical UI writes.
    local text, tone = CombatReadoutPolicy.ammo(loaded, capacity, reloading)
    if tone == "RELOADING" and loaded ~= nil then
        local magazine = CombatReadoutPolicy.ammo(loaded, capacity, false)
        text = magazine .. "  ·  " .. text
    end
    if text ~= self.lastAmmoText then
        self.ammoLabel.Text = text
        self.lastAmmoText = text
    end
    if tone ~= self.lastAmmoTone then
        local color
        if tone == "UNLIMITED" then
            color = Color3.fromRGB(218, 219, 204)
        elseif tone == "RELOADING" then
            color = RELOAD_COLOR
        elseif tone == "UNKNOWN" then
            color = Color3.fromRGB(231, 217, 181)
        elseif tone == "LOW" then
            color = Color3.fromRGB(242, 134, 102)
        else
            color = Color3.fromRGB(231, 224, 200)
        end
        self.ammoLabel.TextColor3 = color
        self.lastAmmoTone = tone
    end

    if tone == "RELOADING" and self.reloadDuration and self.reloadDuration > 0
        and type(reloadEndsAt) == "number" and reloadEndsAt > 0 and reloadEndsAt < math.huge then
        self.reloadEndsAt = reloadEndsAt
        self:updateReloadProgress()
        if not self.reloadTrack.Visible then self.reloadTrack.Visible = true end
    elseif self.reloadEndsAt then
        self.reloadEndsAt = nil
        self.lastReloadPixels = nil
        self.reloadTrack.Visible = false
    end

    local touchText = "RLD"
    if tone == "RELOADING" then
        touchText = "LOAD"
    elseif tone == "UNLIMITED" then
        touchText = "–"
    elseif loaded and capacity and loaded >= capacity then
        touchText = "FULL"
    end
    if touchText ~= self.touchReloadText then
        self.touchReloadText = touchText
        if self.touchReloadButton then self.touchReloadButton.Text = touchText end
    end
    local progressVisible = self.reloadEndsAt ~= nil
    if self.touchReloadTrack and self.touchReloadTrack.Visible ~= progressVisible then
        self.touchReloadTrack.Visible = progressVisible
    end
end

function HudController:_buildScopeOverlay()
    -- A static, client-only optical reticle that adapts to Android viewport sizes.
    local scopeOverlay = Instance.new("Frame")
    scopeOverlay.Name = "ScopeOverlay"
    scopeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scopeOverlay.BackgroundTransparency = 0.76
    scopeOverlay.BorderSizePixel = 0
    scopeOverlay.Size = UDim2.fromScale(1, 1)
    scopeOverlay.Visible = false
    scopeOverlay.ZIndex = 0
    scopeOverlay.Active = false
    scopeOverlay.Parent = self.gui

    local scopeRing = Instance.new("Frame")
    scopeRing.Name = "ScopeRing"
    scopeRing.AnchorPoint = Vector2.new(0.5, 0.5)
    scopeRing.BackgroundTransparency = 1
    scopeRing.BorderSizePixel = 0
    scopeRing.Position = UDim2.fromScale(0.5, 0.5)
    scopeRing.Size = UDim2.fromScale(0.55, 0.55)
    scopeRing.Visible = false
    scopeRing.ZIndex = 2
    scopeRing.Active = false
    scopeRing.Parent = self.gui

    -- The ring fits the smaller screen dimension. Constraints are declarative,
    -- with no per-frame size polling, Tweens, raycasts or extra render loops.
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.DominantAxis = Enum.DominantAxis.Height
    aspect.Parent = scopeRing
    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MinSize = Vector2.new(150, 150)
    sizeLimit.MaxSize = Vector2.new(350, 350)
    sizeLimit.Parent = scopeRing
    makeStroke(scopeRing, Color3.fromRGB(236, 232, 218), 0.13, 2)
    makeCorner(scopeRing, 999)

    local tint = Color3.fromRGB(228, 230, 219)
    local function segment(name, position, size, opacity)
        local part = Instance.new("Frame")
        part.Name = name
        part.AnchorPoint = Vector2.new(0.5, 0.5)
        part.Position = position
        part.Size = size
        part.BackgroundColor3 = tint
        part.BackgroundTransparency = opacity or 0
        part.BorderSizePixel = 0
        part.Active = false
        part.ZIndex = 3
        part.Parent = scopeRing
        return part
    end

    -- Split bars preserve a clean sight picture at point-blank range.
    segment("ScopeLeftStadia", UDim2.fromScale(0.264, 0.5),
        UDim2.new(0.372, 0, 0, 2))
    segment("ScopeRightStadia", UDim2.fromScale(0.736, 0.5),
        UDim2.new(0.372, 0, 0, 2))
    segment("ScopeTopStadia", UDim2.fromScale(0.5, 0.264),
        UDim2.new(0, 2, 0.372, 0))
    segment("ScopeBottomStadia", UDim2.fromScale(0.5, 0.736),
        UDim2.new(0, 2, 0.372, 0))
    local center = segment("ScopeCenterDot", UDim2.fromScale(0.5, 0.5),
        UDim2.fromOffset(3, 3))
    makeCorner(center, 999)
    makeStroke(center, Color3.fromRGB(30, 35, 32), 0.1, 1)
    -- Reference marks are visual cues, not calibrated ballistic holds.
    for _, x in ipairs({ 0.22, 0.32, 0.68, 0.78 }) do
        segment("ScopeWindageTick", UDim2.fromScale(x, 0.5),
            UDim2.fromOffset(1, 9), 0.16)
    end
    for _, y in ipairs({ 0.61, 0.71, 0.81 }) do
        segment("ScopeElevationTick", UDim2.fromScale(0.5, y),
            UDim2.fromOffset(9, 1), 0.16)
    end

    -- Trusted damage confirmation remains visible above the reticle.
    self.hitMarker.ZIndex = 4
    self.damageReadout.ZIndex = 4
    self.eliminationConfirmation.ZIndex = 4
    self.scopeOverlay = scopeOverlay
    self.scopeRing = scopeRing
end
local FIRE_AIM_LABELS = { "LOW", "MID", "HIGH" }

function HudController:_buildFinishCollection(parent)
    local player = self.player
    local status = makeText(parent, "FinishSaveStatus", "", UDim2.fromOffset(22, 40),
        UDim2.fromOffset(296, 16), 11)
    status.ZIndex = 13
    local objectives = makeText(parent, "DailyFfaObjectives", "", UDim2.fromOffset(22, 58),
        UDim2.fromOffset(296, 17), 11)
    objectives.ZIndex = 13
    local rows = {}
    for index = 0, OperatorFinishes.count() + 1 do
        local reward = index > OperatorFinishes.count()
        local finish = reward and OperatorFinishes.sessionReward or OperatorFinishes.atIndex(index)
        local preference = finish and (finish.preference or finish.level) or 0
        local button = makeButton(parent, "Finish" .. preference, "",
            UDim2.fromOffset(22, 80 + index * 40), UDim2.fromOffset(296, 36))
        button.ZIndex = 12
        local name = makeText(button, "FinishName", finish and finish.name or "AUTO · HIGHEST RANK",
            UDim2.fromOffset(10, 0), UDim2.fromOffset(151, 36), 12)
        name.ZIndex = 13
        local state = makeText(button, "FinishState", "", UDim2.fromOffset(207, 0),
            UDim2.fromOffset(82, 36), 10)
        state.TextXAlignment = Enum.TextXAlignment.Right
        state.ZIndex = 13
        if finish then
            for swatch, channels in ipairs({ finish.metal, finish.fabric, finish.accent }) do
                local sample = Instance.new("Frame")
                sample.Name = "Swatch"
                sample.Position = UDim2.fromOffset(158 + (swatch - 1) * 15, 12)
                sample.Size = UDim2.fromOffset(12, 12)
                sample.BackgroundColor3 = Color3.fromRGB(channels[1], channels[2], channels[3])
                sample.BorderSizePixel = 0
                sample.ZIndex = 13
                sample.Parent = button
            end
        end
        rows[index + 1] = { preference = preference, button = button, state = state, reward = reward }
        button.Activated:Connect(function()
            if self.settingsOpen and parent.Visible and button.Interactable
                and player:GetAttribute("IronYardFinishPreference") ~= preference then
                self.options.onCareerFinishChanged(preference)
            end
        end)
    end
    local function update()
        local preference = player:GetAttribute("IronYardFinishPreference")
        local level = player:GetAttribute("IronYardProgressLevel")
        local save = player:GetAttribute("IronYardProgressStatus")
        local saved = player:GetAttribute("IronYardSavedFinishPreference")
        local objective = Objectives.decode(player:GetAttribute(Objectives.ATTRIBUTE))
        local savedObjective = Objectives.decode(player:GetAttribute(Objectives.SAVED_ATTRIBUTE))
        local unlockedReward = player:GetAttribute(Objectives.UNLOCKED_ATTRIBUTE) == true
        objectives.Text = objective and ("DAILY · " .. Objectives.readout(objective)) or Objectives.readout()
        if save == "STUDIO" then
            status.Text = "SESSION ONLY"
        elseif save == "ONLINE" then
            status.Text = preference == nil and "LOADING CAREER"
                or (preference == saved and "SELECTION SAVED" or "SELECTION SAVE PENDING")
        else
            status.Text = (not save or save == "LOADING") and "LOADING CAREER" or "SAVE RETRYING"
        end
        for _, row in ipairs(rows) do
            local unlocked = OperatorFinishes.canSelect(row.preference, level, unlockedReward)
            row.button.Interactable = preference ~= nil and unlocked
                and self.options.onCareerFinishChanged ~= nil
            row.button.Selectable = row.button.Interactable
            if row.reward and unlocked and save ~= "STUDIO" and not (savedObjective and savedObjective.unlocked) then
                row.state.Text = "SAVE PENDING"
            else
                row.state.Text = preference == row.preference and "SELECTED"
                    or (unlocked and "AVAILABLE" or (row.reward and "FFA GOALS" or ("LOCKED · LV " .. row.preference)))
            end
            row.state.TextColor3 = unlocked and Color3.fromRGB(233, 203, 145)
                or Color3.fromRGB(162, 173, 190)
        end
    end
    for _, attribute in ipairs({ "IronYardFinishPreference", "IronYardSavedFinishPreference",
        "IronYardProgressStatus", "IronYardProgressLevel", Objectives.ATTRIBUTE,
        Objectives.SAVED_ATTRIBUTE, Objectives.UNLOCKED_ATTRIBUTE }) do
        player:GetAttributeChangedSignal(attribute):Connect(update)
    end
    update()
end

function HudController:_buildSettingsMenu()
    local touch = UserInputService.TouchEnabled
    local panelHeight = touch and 380 or 361
    local settingsRect = TouchLayout.MENU_BUTTONS.Settings
    local settingsGui = self.gui
    if touch then
        settingsGui = Instance.new("ScreenGui")
        settingsGui.Name = "IronYardTouchSettings"
        settingsGui.IgnoreGuiInset = false
        settingsGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
        settingsGui.DisplayOrder = 32
        settingsGui.ResetOnSpawn = false
        settingsGui.Parent = self.gui.Parent
        self.touchSettingsGui = settingsGui
    end
    local button = makeButton(settingsGui, "SettingsButton",
        touch and "SET" or "M SETTINGS",
        touch and UDim2.fromOffset(settingsRect.x, settingsRect.y)
            or UDim2.new(1, -138, 0, 18),
        touch and UDim2.fromOffset(settingsRect.w, settingsRect.h)
            or UDim2.fromOffset(118, 34))
	self.settingsButton = button

	local panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(18, 21, 28)
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(340, panelHeight)
    -- Adapt to small landscape Android viewports, including notched phones.
    local responsiveScale = Instance.new("UIScale")
    responsiveScale.Parent = panel
    local function fitPanel()
        local camera = workspace.CurrentCamera
        local viewport = touch and settingsGui.AbsoluteSize or (camera and camera.ViewportSize)
        if not viewport or viewport.X <= 0 or viewport.Y <= 0 then return end
        responsiveScale.Scale = math.min(viewport.X / 352, viewport.Y / (panelHeight + 12), 1)
    end
    local viewportConnection
    local function attachCamera()
        if viewportConnection then viewportConnection:Disconnect() end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
        end
        fitPanel()
    end
    if touch then
        settingsGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
        fitPanel()
    else
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
        attachCamera()
    end
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = settingsGui
    panel.SelectionGroup = true
    panel.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
    panel.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
    panel.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
    panel.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	makeCorner(panel, 6)
	makeStroke(panel, Color3.fromRGB(90, 102, 126), 0.15, 1)
	self.settingsPanel = panel

    local settingsPage = Instance.new("Frame")
    settingsPage.Name = "SettingsPage"
    settingsPage.Size = UDim2.fromScale(1, 1)
    settingsPage.BackgroundTransparency = 1
    settingsPage.ZIndex = 11
    settingsPage.Parent = panel
    local collectionPage = Instance.new("Frame")
    collectionPage.Name = "CollectionPage"
    collectionPage.Size = UDim2.fromScale(1, 1)
    collectionPage.BackgroundTransparency = 1
    collectionPage.Visible = false
    collectionPage.ZIndex = 11
    collectionPage.Parent = panel

	local title = makeText(panel, "Title", "SETTINGS", UDim2.fromOffset(22, 14), UDim2.fromOffset(150, 24), 18)
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 11

	local closeButton = makeButton(panel, "Close", "X", UDim2.new(1, -56, 0, 12), UDim2.fromOffset(42, 42))
	closeButton.ZIndex = 12
    self.settingsFocus = closeButton
    local collectionButton = makeButton(panel, "Collection", "COLLECTION",
        UDim2.fromOffset(173, 12), UDim2.fromOffset(104, 32))
    collectionButton.ZIndex = 12
    collectionButton.TextSize = 12
    collectionButton.Activated:Connect(function()
        local open = not collectionPage.Visible
        collectionPage.Visible = open
        settingsPage.Visible = not open
        collectionButton.Text = open and "SETTINGS" or "COLLECTION"
        title.Text = open and "COLLECTION" or "SETTINGS"
    end)
    self:_buildFinishCollection(collectionPage)

	self.fovValueLabel = self:_makeStepper(settingsPage, "FOV", UDim2.fromOffset(22, touch and 58 or 67), 60, 100, 5, function()
		return tostring(self.baseFov)
	end, function(delta)
		self.baseFov = clampSetting(self.baseFov + delta, 60, 100)
		self:_refreshSettingsText()
		if self.options.onFovChanged then
			self.options.onFovChanged(self.baseFov)
		end
	end)

    if touch then
        self.touchSizeValueLabel = self:_makeStepper(settingsPage, "BUTTON SIZE",
            UDim2.fromOffset(22, 102), 1, #TouchLayout.PRESETS, 1, function()
                return TOUCH_SIZE_LABELS[self.touchSizeIndex]
            end, function(delta)
                self.touchSizeIndex = math.clamp(self.touchSizeIndex + delta,
                    1, #TouchLayout.PRESETS)
                self.player:SetAttribute("IronYardTouchSizePreset",
                    TouchLayout.PRESETS[self.touchSizeIndex])
                self:_refreshSettingsText()
            end)
        self.fireAimIndex = 2
        self.fireAimValueLabel = self:_makeStepper(settingsPage, "FIRE DRAG",
            UDim2.fromOffset(22, 146), 1, 3, 1, function()
                return FIRE_AIM_LABELS[self.fireAimIndex]
            end, function(delta)
                self.fireAimIndex = math.clamp(self.fireAimIndex + delta, 1, 3)
                self.player:SetAttribute("IronYardFireAimPreset", self.fireAimIndex)
                self:_refreshSettingsText()
            end)
    else
	self.sensitivityValueLabel = self:_makeStepper(settingsPage, "MOUSE SENS", UDim2.fromOffset(22, 115), 0.3, 2.5, 0.1, function()
		return string.format("%.1f", self.mouseSensitivity)
	end, function(delta)
		self.mouseSensitivity = clampSetting(math.floor((self.mouseSensitivity + delta) * 10 + 0.5) / 10, 0.3, 2.5)
		self:_refreshSettingsText()
		if self.options.onMouseSensitivityChanged then
			self.options.onMouseSensitivityChanged(self.mouseSensitivity)
		end
	end)
    end

    self.graphicsValueLabel = self:_makeStepper(settingsPage, "GRAPHICS",
        UDim2.fromOffset(22, touch and 190 or 163), 1, 3, 1, function()
            return GRAPHICS_LABELS[self.graphicsIndex]
        end, function(delta)
            self.graphicsIndex = math.clamp(self.graphicsIndex + delta, 1, #GRAPHICS_PRESETS)
            self.player:SetAttribute("IronYardGraphicsPreset", GRAPHICS_PRESETS[self.graphicsIndex])
            self:_refreshSettingsText()
        end)

    self.hitSoundValueLabel = self:_makeStepper(settingsPage, "HIT SOUND",
        UDim2.fromOffset(22, touch and 234 or 211), 1, #HIT_SOUND_LABELS, 1, function()
            return HIT_SOUND_LABELS[self.hitSoundLevel]
        end, function(delta)
            self.hitSoundLevel = math.clamp(self.hitSoundLevel + delta, 1, #HIT_SOUND_LABELS)
            if self.hitSoundLevel == 1 then self.hitConfirmSound:Stop() end
            self:_refreshSettingsText()
        end)

    self.opponentFootstepValueLabel = self:_makeStepper(settingsPage, "ENEMY STEP FX",
        UDim2.fromOffset(22, touch and 278 or 259), 0, 100, FOOTSTEP_VOLUME_STEP, function()
            return self.opponentFootstepVolume .. "%"
        end, function(delta, minValue, maxValue)
            self.opponentFootstepVolume = clampSetting(self.opponentFootstepVolume + delta, minValue, maxValue)
            self.player:SetAttribute(FOOTSTEP_VOLUME_ATTRIBUTE, self.opponentFootstepVolume)
            self:_refreshSettingsText()
        end)

    local settingsHint = touch and "Drag on FIRE to aim while shooting" or "Press M to close"
    local hint = makeText(settingsPage, "Hint", settingsHint,
        UDim2.fromOffset(22, 40), UDim2.fromOffset(252, 16), 12)
    hint.TextColor3 = Color3.fromRGB(162, 173, 190)
    hint.ZIndex = 11

    local rangeY = panelHeight - 53
    local rangeButton = makeButton(settingsPage, "PracticeRange", "PRACTICE RANGE",
        UDim2.fromOffset(22, rangeY), UDim2.fromOffset(296, 42))
    local resetButton = makeButton(settingsPage, "ResetPracticeStats", "RESET STATS",
        UDim2.fromOffset(222, rangeY), UDim2.fromOffset(96, 42))
    rangeButton.ZIndex = 12
    resetButton.ZIndex = 12
    rangeButton.TextTruncate = Enum.TextTruncate.AtEnd
    local statsButton = makeButton(settingsPage, "PracticeWeaponStats", "RANGE STATS",
        UDim2.fromOffset(122, rangeY), UDim2.fromOffset(96, 42))
    statsButton.ZIndex = 12

    local statsPage = Instance.new("Frame")
    statsPage.Name = "PracticeWeaponStatsPage"
    statsPage.Size = UDim2.fromScale(1, 1)
    statsPage.BackgroundTransparency = 1
    statsPage.Visible = false
    statsPage.ZIndex = 11
    statsPage.Parent = panel
    local statsBack = makeButton(statsPage, "Back", "BACK TO SETTINGS",
        UDim2.fromOffset(22, rangeY), UDim2.fromOffset(296, 42))
    statsBack.ZIndex = 12
    local refreshWeaponStats = self:_buildPracticeWeaponStats(statsPage)
    local drillSeconds = PracticeMode.DRILL_SECONDS
    local drillButton = makeButton(statsPage, "StartPracticeDrill", "",
        UDim2.fromOffset(174, rangeY), UDim2.fromOffset(144, 42))
    drillButton.ZIndex = 12
    drillButton.Visible = self.options.onPracticeDrillStart ~= nil
    if drillButton.Visible then statsBack.Size = UDim2.fromOffset(144, 42) end
    local drillStatus = makeText(statsPage, "PracticeDrillStatus", "",
        UDim2.fromOffset(22, 260), UDim2.fromOffset(296, 18), 11)
    drillStatus.ZIndex = 12
    drillStatus.TextXAlignment = Enum.TextXAlignment.Center
    drillStatus.Visible = drillButton.Visible
    local drillBest = makeText(statsPage, "PracticeDrillBest", "",
        UDim2.fromOffset(22, 280), UDim2.fromOffset(296, 18), 11)
    drillBest.ZIndex = 12
    drillBest.TextColor3 = Color3.fromRGB(233, 203, 145)
    drillBest.TextXAlignment = Enum.TextXAlignment.Center
    drillBest.Visible = drillButton.Visible

    local pendingDrill
    local function updateDrillControls()
        if not drillButton.Visible then return end
        local session = PracticeMode.session(self.player)
        local drill = PracticeMode.drill(self.player)
        local acknowledged = pendingDrill and session == pendingDrill.session
            and drill and drill.id == pendingDrill.previousId + 1
        if pendingDrill and (acknowledged or session ~= pendingDrill.session) then pendingDrill = nil end
        local active = drill and not drill.finished
        drillButton.Interactable = not active and not pendingDrill
        drillButton.Selectable = drillButton.Interactable
        if pendingDrill then
            drillButton.Text = "STARTING…"
        elseif active then
            drillButton.Text = "DRILL ACTIVE"
        else
            drillButton.Text = string.format(drill and "RETRY %dS DRILL" or "START %dS DRILL", drillSeconds)
        end
        drillStatus.Text = drill and (drill.finished and ("LAST DRILL  ·  " .. PracticeMode.drillReadout(drill))
            or "THE TIMER IS SHOWN IN THE RANGE") or "KNOCK DOWN AS MANY TARGETS AS YOU CAN"
        local best = PracticeMode.drillBest(self.player)
        drillBest.Text = best and ("SESSION BEST  ·  " .. PracticeMode.drillReadout(best)) or "SESSION BEST  ·  —"
        if acknowledged and self.settingsOpen and statsPage.Visible then self:setSettingsOpen(false) end
    end
    drillButton.Activated:Connect(function()
        if not self.settingsOpen or not statsPage.Visible or not drillButton.Visible
            or not drillButton.Interactable or not PracticeMode.active(self.player) then return end
        local drill = PracticeMode.drill(self.player)
        local request = { session = PracticeMode.session(self.player), previousId = drill and drill.id or 0 }
        pendingDrill = request
        updateDrillControls()
        self.options.onPracticeDrillStart(request.session, request.previousId)
        task.delay(3, function()
            if pendingDrill ~= request then return end
            pendingDrill = nil
            updateDrillControls()
        end)
    end)
    self.player:GetAttributeChangedSignal(PracticeMode.DRILL_ATTRIBUTE):Connect(updateDrillControls)
    self.player:GetAttributeChangedSignal(PracticeMode.DRILL_BEST_ATTRIBUTE):Connect(updateDrillControls)
    self.player:GetAttributeChangedSignal(PracticeMode.ATTRIBUTE):Connect(updateDrillControls)
    updateDrillControls()

    local function setWeaponStatsOpen(open)
        local selected = GuiService.SelectedObject
        local previousPage = open and settingsPage or statsPage
        statsPage.Visible = open
        settingsPage.Visible = not open
        collectionButton.Visible = not open
        title.Text = open and "RANGE STATS" or "SETTINGS"
        if open then refreshWeaponStats() end
        if selected and selected:IsDescendantOf(previousPage) then
            GuiService.SelectedObject = open and statsBack or (statsButton.Visible and statsButton or closeButton)
        end
    end
    statsButton.Activated:Connect(function()
        if self.settingsOpen and settingsPage.Visible and statsButton.Visible then
            setWeaponStatsOpen(true)
        end
    end)
    statsBack.Activated:Connect(function()
        if self.settingsOpen and statsPage.Visible then setWeaponStatsOpen(false) end
    end)

    local pendingReset
    local function updateRangeButtons()
        local canEnter = workspace:GetAttribute("IronYardMatchMode") == "FFA"
            and workspace:GetAttribute("IronYardDedicatedDuel") ~= true
        local practicing = PracticeMode.active(self.player)
        local session = PracticeMode.session(self.player)
        local _, _, _, revision = PracticeMode.stats(self.player)
        local notice = self.player:GetAttribute("IronYardPracticeNotice")
        rangeButton.Visible = canEnter and self.options.onPracticeRequested ~= nil
        rangeButton.Selectable = rangeButton.Visible
        statsButton.Visible = rangeButton.Visible and practicing
        statsButton.Selectable = statsButton.Visible
        resetButton.Visible = rangeButton.Visible and practicing and self.options.onPracticeStatsReset ~= nil
        resetButton.Selectable = resetButton.Visible and revision ~= nil
        rangeButton.Size = UDim2.fromOffset(statsButton.Visible and 96 or 296, 42)
        statsButton.Size = UDim2.fromOffset(resetButton.Visible and 96 or 196, 42)
        rangeButton.Text = practicing and "BACK TO FFA" or (notice or "PRACTICE RANGE")
        hint.Text = practicing and notice or settingsHint
        if statsPage.Visible then
            if statsButton.Visible then
                refreshWeaponStats()
            else
                setWeaponStatsOpen(false)
            end
        end

        local completed = pendingReset and session == pendingReset.session
            and revision and revision > pendingReset.revision
        if completed or (pendingReset and (not resetButton.Visible or session ~= pendingReset.session)) then
            pendingReset = nil
        end
        resetButton.Interactable = resetButton.Selectable and not pendingReset
        resetButton.Text = pendingReset and "RESETTING…" or "RESET STATS"
        if completed and self.settingsOpen and settingsPage.Visible then
            self:setSettingsOpen(false)
        end
    end
    rangeButton.Activated:Connect(function()
        if self.settingsOpen and settingsPage.Visible and rangeButton.Visible then
            self.options.onPracticeRequested()
        end
    end)
    resetButton.Activated:Connect(function()
        if not self.settingsOpen or not settingsPage.Visible or not resetButton.Visible
            or not resetButton.Interactable then return end
        local _, _, _, revision = PracticeMode.stats(self.player)
        if revision == nil or not PracticeMode.active(self.player) then return end
        local request = { session = PracticeMode.session(self.player), revision = revision }
        pendingReset = request
        updateRangeButtons()
        self.options.onPracticeStatsReset(request.session, request.revision)
        task.delay(3, function()
            if pendingReset ~= request then return end
            pendingReset = nil
            updateRangeButtons()
        end)
    end)
    self.player:GetAttributeChangedSignal(PracticeMode.ATTRIBUTE):Connect(updateRangeButtons)
    self.player:GetAttributeChangedSignal(PracticeMode.STATS_ATTRIBUTE):Connect(updateRangeButtons)
    self.player:GetAttributeChangedSignal("IronYardPracticeNotice"):Connect(updateRangeButtons)
    workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(updateRangeButtons)
    workspace:GetAttributeChangedSignal("IronYardDedicatedDuel"):Connect(updateRangeButtons)
    updateRangeButtons()

	button.Activated:Connect(function()
		self:setSettingsOpen(not self.settingsOpen)
	end)

	closeButton.Activated:Connect(function()
		self:setSettingsOpen(false)
	end)

    local function syncSelection()
        self:_syncSettingsSelection()
    end
    UserInputService.LastInputTypeChanged:Connect(syncSelection)
    GuiService.MenuOpened:Connect(syncSelection)
    GuiService.MenuClosed:Connect(syncSelection)
	self:_refreshSettingsText()
end

function HudController:_buildPracticeWeaponStats(parent)
    local function cell(name, text, x, y, width, height, fontSize, align)
        local label = makeText(parent, name, text, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height), fontSize)
        label.TextXAlignment = align
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.ZIndex = 12
        return label
    end

    local left, right = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
    local headings = {
        cell("WeaponHeading", "WEAPON", 22, 60, 104, 18, 11, left),
        cell("AccuracyHeading", "ACCURACY", 129, 60, 60, 18, 11, right),
        cell("HitsHeading", "HITS / SHOTS", 195, 60, 72, 18, 11, right),
        cell("TargetsHeading", "DOWN", 273, 60, 45, 18, 11, right),
    }
    for _, heading in ipairs(headings) do
        heading.TextColor3 = Color3.fromRGB(162, 173, 190)
    end

    local rows = {}
    for index, weaponId in ipairs(self.WeaponConfig.Order) do
        local y = 83 + (index - 1) * 36
        local displayName = self.WeaponConfig.Definitions[weaponId].displayName
        local name = displayName:match("^(.-) | ") or displayName
        cell(weaponId .. "Name", name, 22, y, 104, 30, 14, left)
        rows[weaponId] = {
            accuracy = cell(weaponId .. "Accuracy", "", 129, y, 60, 30, 14, right),
            hits = cell(weaponId .. "Hits", "", 195, y, 72, 30, 14, right),
            targets = cell(weaponId .. "Targets", "", 273, y, 45, 30, 14, right),
        }
    end

    return function()
        local stats = PracticeMode.weaponStats(self.player)
        for weaponId, row in pairs(rows) do
            local entry = stats[weaponId]
            local accuracy = entry and PracticeMode.accuracy(entry.shots, entry.hits)
            row.accuracy.Text = accuracy and string.format("%d%%", accuracy) or "—"
            row.hits.Text = entry and string.format("%d/%d", entry.hits, entry.shots) or "0/0"
            row.targets.Text = entry and tostring(entry.targetsDown) or "0"
        end
    end
end

function HudController:_makeStepper(parent, labelText, position, minValue, maxValue, step, getText, onStep)
	local row = Instance.new("Frame")
	row.Name = labelText:gsub("%s+", "") .. "Row"
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromOffset(296, 42)
	row.ZIndex = 11
	row.Parent = parent

	local label = makeText(row, "Label", labelText, UDim2.fromOffset(0, 3), UDim2.fromOffset(128, 32), 14)
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 12

	local minus = makeButton(row, "Minus", "-", UDim2.fromOffset(144, 0), UDim2.fromOffset(42, 42))
	local value = makeText(row, "Value", getText(), UDim2.fromOffset(190, 3), UDim2.fromOffset(54, 30), 14)
	local plus = makeButton(row, "Plus", "+", UDim2.fromOffset(254, 0), UDim2.fromOffset(42, 42))
	minus.ZIndex = 12
	value.ZIndex = 12
	value.TextXAlignment = Enum.TextXAlignment.Center
	plus.ZIndex = 12

	minus.Activated:Connect(function()
		onStep(-step, minValue, maxValue)
	end)

	plus.Activated:Connect(function()
		onStep(step, minValue, maxValue)
	end)

	return value
end

function HudController:_refreshSettingsText()
	if self.fovValueLabel then
		self.fovValueLabel.Text = tostring(self.baseFov)
	end

    if self.sensitivityValueLabel then
        self.sensitivityValueLabel.Text = string.format("%.1f", self.mouseSensitivity)
    end
    if self.graphicsValueLabel then
        self.graphicsValueLabel.Text = GRAPHICS_LABELS[self.graphicsIndex]
    end
    if self.fireAimValueLabel then
        self.fireAimValueLabel.Text = FIRE_AIM_LABELS[self.fireAimIndex]
    end
    if self.touchSizeValueLabel then
        self.touchSizeValueLabel.Text = TOUCH_SIZE_LABELS[self.touchSizeIndex]
    end
    if self.hitSoundValueLabel then
        self.hitSoundValueLabel.Text = HIT_SOUND_LABELS[self.hitSoundLevel]
    end
    if self.opponentFootstepValueLabel then
        self.opponentFootstepValueLabel.Text = self.opponentFootstepVolume .. "%"
    end
end

function HudController:_disconnectHealth()
	for _, connection in ipairs(self.healthConnections) do
		connection:Disconnect()
	end

	table.clear(self.healthConnections)
end

function HudController:_bindHealth(character)
    self.healthBindGeneration = (self.healthBindGeneration or 0) + 1
    local generation = self.healthBindGeneration
	self:_disconnectHealth()
    self.previousHealth = nil
    self.lastHealthRatio = nil
    self.lastHealthText = nil
    self.lastHealthTone = nil
    if self.healthTween then
        self.healthTween:Cancel()
        self.healthTween = nil
    end

	if not character then
		self:_updateHealth(nil)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    -- CharacterAdded may fire while an older WaitForChild is suspended.
    -- Never reconnect the obsolete Humanoid over the new character HUD.
    if self.healthBindGeneration ~= generation
        or self.player.Character ~= character then return end
	if not humanoid then
		self:_updateHealth(nil)
		return
	end

	self:_updateHealth(humanoid)
	table.insert(self.healthConnections, humanoid.HealthChanged:Connect(function()
        if self.healthBindGeneration == generation then
		    self:_updateHealth(humanoid)
        end
	end))
	table.insert(self.healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        if self.healthBindGeneration == generation then
		    self:_updateHealth(humanoid)
        end
	end))
end

function HudController:_updateHealth(humanoid)
	local health = humanoid and humanoid.Health or 0
    if self.previousHealth and health < self.previousHealth then
        self:_pulseDamage(self.previousHealth - health)
    end
    self.previousHealth = health
	local maxHealth = humanoid and humanoid.MaxHealth or 100
    local ratio, tone, text = CombatReadoutPolicy.health(health, maxHealth)
    -- Damage pulse above remains independent and immediate, even if two
    -- consecutive health readings round to the same displayed number.
    if tone ~= self.lastHealthTone then
        self.lastHealthTone = tone
        local color = Color3.fromRGB(77, 224, 128)
        if tone == "CRITICAL" then
            color = Color3.fromRGB(245, 82, 82)
        elseif tone == "WARNING" then
            color = Color3.fromRGB(245, 192, 82)
        end
        self.healthFill.BackgroundColor3 = color
    end
    if ratio ~= self.lastHealthRatio then
        self.lastHealthRatio = ratio
        -- Prevent a repeated HealthChanged or MaxHealth sync from stacking
        -- new tweens over the same property.
        if self.healthTween then self.healthTween:Cancel() end
        self.healthTween = TweenService:Create(self.healthFill,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(ratio, 1) })
        self.healthTween:Play()
    end
    if text ~= self.lastHealthText then
        self.lastHealthText = text
        self.healthText.Text = text
    end
end

function HudController:setBoostFuel(ratio)
    if not self.boostFill then return end
    -- The movement controller reports fuel every RenderStepped. Previous
    -- code created a Tween on EVERY frame, even at constant full fuel.
    local now = os.clock()
    local draw, value, zone = BoostMeterPolicy.shouldDraw(
        self.lastBoostRatio, self.lastBoostUpdateAt, ratio, now)
    if not draw then return end

    self.lastBoostRatio = value
    self.lastBoostUpdateAt = now
    if self.lastBoostZone ~= zone then
        self.lastBoostZone = zone
        if zone == "CRITICAL" then
            self.boostFill.BackgroundColor3 = Color3.fromRGB(245, 82, 82)
        elseif zone == "WARNING" then
            self.boostFill.BackgroundColor3 = Color3.fromRGB(245, 192, 82)
        else
            self.boostFill.BackgroundColor3 = Color3.fromRGB(207, 160, 89)
        end
    end

    -- Urgent color/empty/full transitions may interrupt the previous 80ms
    -- animation. Never stack overlapping Tweens on the same UI property.
    if self.boostTween then self.boostTween:Cancel() end
    self.boostTween = TweenService:Create(self.boostFill,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(value, 1) })
    self.boostTween:Play()
end

function HudController:_syncSettingsSelection()
    local selected = GuiService.SelectedObject
    local ownsSelection = selected and selected:IsDescendantOf(self.settingsPanel)
    if self.settingsOpen and not GuiService.MenuIsOpen
        and GamepadCombatPolicy.isGamepad(UserInputService:GetLastInputType().Name) then
        if not ownsSelection then GuiService.SelectedObject = self.settingsFocus end
    elseif ownsSelection then
        GuiService.SelectedObject = nil
    end
end

function HudController:setSettingsOpen(open)
	self.settingsOpen = open
	self.settingsPanel.Visible = open
    -- Settings modal must render above the match HUD and results screens.
    if self.touchSettingsGui then
        self.touchSettingsGui.DisplayOrder = open and 50 or 32
    else
        self.gui.DisplayOrder = open and 50 or self.defaultDisplayOrder
    end
    self.player:WaitForChild("PlayerGui"):SetAttribute("IronYardSettingsOpen", open)
    self:_syncSettingsSelection()

	if self.options.onSettingsOpenChanged then
		self.options.onSettingsOpenChanged(open)
	end
end

function HudController:toggleSettings()
	self:setSettingsOpen(not self.settingsOpen)
end

function HudController:isSettingsOpen()
	return self.settingsOpen
end

function HudController:setWeapon(weaponId)
	self.currentWeaponId = weaponId
    self.reticleKick = 0
    self.reticleShotPending = false
    self.reticleKickAt = nil
    self.reticleRadius = nil
    -- Equip must force a fresh readout even when two magazines happen to
    -- share the same text and the server snapshot arrives a frame later.
    self.lastAmmoText = nil
    self.lastAmmoTone = nil
	local config = self.WeaponConfig.get(weaponId)
    self.reloadDuration = config and config.reloadSeconds
	self.weaponLabel.Text = config and config.displayName or weaponId
    self:setAmmo(weaponId, nil, config and config.magazineSize, false)

	local color = Color3.fromRGB(247, 244, 235)
	if weaponId == "AssaultRifle" then
        color = Color3.fromRGB(218, 231, 205)
    elseif weaponId == "Shotgun" then
        color = Color3.fromRGB(232, 197, 132)
    elseif weaponId == "Sniper" then
		color = Color3.fromRGB(201, 191, 162)
	elseif weaponId == "Knife" then
		color = Color3.fromRGB(255, 226, 153)
	end

	for _, line in ipairs(self.crosshairLines) do
        line.BackgroundColor3 = color
    end
    self.adsDot.BackgroundColor3 = color
end

-- Predicted shot bloom is cosmetic; only a server "Hit" triggers damage feedback.
function HudController:registerPredictedShot(weaponId, followUp)
    if weaponId ~= self.currentWeaponId then return end
    local now = os.clock()
    local prior = CrosshairFeedback.recover(self.reticleKick, now - (self.reticleKickAt or now))
    self.reticleKick = CrosshairFeedback.kick(weaponId, prior, followUp)
    self.reticleKickAt = now
    self.reticleShotPending = true
end

-- Wake the existing HUD render callback for the next shot of any weapon.
-- Recovery uses the shot clock, including after a mobile background pause.
function HudController:updateCrosshair(moving, running)
    if not self.crosshair.Visible and not self.reticleShotPending then return end
    local freshShot = self.reticleShotPending
    self.reticleShotPending = false
    local now = os.clock()
    local kick = CrosshairFeedback.recover(self.reticleKick, now - (self.reticleKickAt or now))
    local radius = CrosshairFeedback.radius(self.currentWeaponId, moving, running, kick)
    if not CrosshairFeedback.shouldDraw(now,
        self.reticleLastAt, self.reticleRadius, radius, freshShot) then return end
    self.reticleLastAt = now
    self.reticleRadius = radius
    self.crosshairLines[1].Position = UDim2.new(0.5, 0, 0.5, -radius)
    self.crosshairLines[2].Position = UDim2.new(0.5, 0, 0.5, radius)
    self.crosshairLines[3].Position = UDim2.new(0.5, -radius, 0.5, 0)
    self.crosshairLines[4].Position = UDim2.new(0.5, radius, 0.5, 0)
end

function HudController:setScoped(scoped)
	local isOptical = self.currentWeaponId == "Sniper"
    self.scopeOverlay.Visible = scoped and isOptical
    self.scopeRing.Visible = scoped and isOptical
    self.crosshair.Visible = not scoped
    self.adsDot.Visible = scoped and not isOptical
end

local function showDamageReadout(self, content, color, duration)
    local label = self.damageReadout
    self.damageReadoutToken += 1
    local token = self.damageReadoutToken
    label.Text = content
    label.TextColor3 = color
    label.TextTransparency = 0
    label.Visible = true
    task.delay(duration, function()
        if self.damageReadoutToken == token and label.Parent then
            label.TextTransparency = 1
            label.Visible = false
        end
    end)
end

function HudController:resetCombatFeedback()
    self.lastConfirmedHudHitAt = -math.huge
    self.lastConfirmedHudHitPriority = 0
    self.hitToken += 1
    self.damageReadoutToken += 1
    self.eliminationToken += 1
    self.hitMarkerPulse:Cancel()
    self.hitConfirmSound:Stop()
    self.hitMarker.Visible = false
    self.damageReadout.Visible = false
    self.eliminationConfirmation.Visible = false
end

function HudController:showProtectedFeedback()
    -- Avoid replacing a recently confirmed elimination with a weaker shield
    -- indicator from another pellet or a lagged hit notification.
    local recent = FeedbackPolicy.markerStyle(self.lastConfirmedHudHitPriority)
    if os.clock() - self.lastConfirmedHudHitAt < math.max(0.24, recent and recent.duration or 0) then
        return
    end
    showDamageReadout(self, FeedbackPolicy.readout("Protected"),
        Color3.fromRGB(172, 208, 226), 0.48)
end

function HudController:showHitFeedback(message)
    local killed = message.killed == true
    local headshot = message.headshot == true
    local config = self.WeaponConfig.get(message.weaponId)
    local readoutText = FeedbackPolicy.readout("Hit", message.damage, headshot,
        message.pelletsHit, config and config.pellets)
    if not readoutText then return end
    local priority = CombatVfxProfile.hitPriority(headshot, killed)
    local previous = FeedbackPolicy.markerStyle(self.lastConfirmedHudHitPriority)
    local now = os.clock()
    if not CombatVfxProfile.shouldDisplayHit(now,
        self.lastConfirmedHudHitAt, self.lastConfirmedHudHitPriority, priority,
        previous and previous.duration) then
        return
    end
    self.lastConfirmedHudHitAt = now
    self.lastConfirmedHudHitPriority = priority
    self.hitToken += 1
    local token = self.hitToken
    local style = FeedbackPolicy.markerStyle(priority)
    local color = Color3.fromRGB(table.unpack(style.tint))
    for index, direction in ipairs(MARKER_QUADRANTS) do
        local arm = self.hitArms[index]
        arm.Position = UDim2.new(0.5, direction[1] * style.offset, 0.5, direction[2] * style.offset)
        arm.Size = UDim2.fromOffset(style.length, style.thickness)
        arm.BackgroundColor3 = color
        local endMark = self.eliminationArms[index]
        endMark.BackgroundColor3 = color
        endMark.Visible = killed
    end
    for _, mark in ipairs(self.headshotChevron) do
        mark.BackgroundColor3 = color
        mark.Visible = headshot
    end
    self.hitMarker.Visible = true
    if not GuiService.ReducedMotionEnabled then
        self.hitMarkerPulse:Cancel()
        self.hitMarkerScale.Scale = 1.09
        self.hitMarkerPulse:Play()
    end

    local volume = FeedbackPolicy.soundVolume(style, self.hitSoundLevel)
    if volume > 0 then
        local sound = self.hitConfirmSound
        sound.Volume = volume
        sound.PlaybackSpeed = style.pitch
        sound:Stop()
        sound:Play()
    end
    showDamageReadout(self, readoutText, color, killed and 0.78 or 0.48)

    if killed then
        self.eliminationToken += 1
        local eliminationToken = self.eliminationToken
        local confirmation = self.eliminationConfirmation
        confirmation.Text = PracticeMode.active(self.player) and "TARGET DOWN"
            or (headshot and "HEADSHOT ELIMINATION" or "ELIMINATED")
        confirmation.TextColor3 = color
        confirmation.TextTransparency = 0
        confirmation.Visible = true
        task.delay(0.85, function()
            if self.eliminationToken == eliminationToken then
                confirmation.Visible = false
                confirmation.TextTransparency = 1
            end
        end)
    end

    task.delay(style.duration, function()
        if self.hitToken == token then
            self.hitMarker.Visible = false
        end
    end)
end

return HudController
