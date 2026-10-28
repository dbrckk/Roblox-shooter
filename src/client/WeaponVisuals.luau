local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WeaponVisuals = {}
WeaponVisuals.__index = WeaponVisuals

local MATERIAL_METAL = Enum.Material.Metal
local MATERIAL_SMOOTH = Enum.Material.SmoothPlastic
local MATERIAL_NEON = Enum.Material.Neon

local WEAPON_OFFSETS = {
	Pistol = CFrame.new(0.72, -0.58, -1.2) * CFrame.Angles(math.rad(-2), math.rad(7), math.rad(-1)),
	Sniper = CFrame.new(0.5, -0.5, -1.46) * CFrame.Angles(math.rad(-1), math.rad(4), 0),
	Knife = CFrame.new(0.7, -0.58, -1.08) * CFrame.Angles(math.rad(-18), math.rad(16), math.rad(-12)),
}

local SPRINT_OFFSETS = {
	Pistol = CFrame.new(0.12, -0.1, 0.14) * CFrame.Angles(math.rad(-11), math.rad(16), math.rad(9)),
	Sniper = CFrame.new(0.18, -0.16, 0.16) * CFrame.Angles(math.rad(-13), math.rad(20), math.rad(7)),
	Knife = CFrame.new(0.08, -0.08, 0.06) * CFrame.Angles(math.rad(-22), math.rad(18), math.rad(18)),
}

local function configurePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function smoothStep(value)
	value = math.clamp(value, 0, 1)
	return value * value * (3 - 2 * value)
end

function WeaponVisuals.new(WeaponConfig)
	local self = setmetatable({}, WeaponVisuals)

	self.WeaponConfig = WeaponConfig
	self.currentWeaponId = "Pistol"
	self.model = nil
	self.parts = {}
	self.recoil = 0
	self.fireStartedAt = -math.huge
	self.equipStartedAt = os.clock()
	self.sprinting = false
	self.scoped = false
	self.sway = Vector2.new(0, 0)
	self.random = Random.new()
	self.renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		self:_render(deltaTime)
	end)

	return self
end

function WeaponVisuals:_addPart(model, className, name, size, color, offset, material, transparency, shape)
	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or MATERIAL_SMOOTH
	part.Transparency = transparency or 0

	if shape and part:IsA("Part") then
		part.Shape = shape
	end

	configurePart(part)
	part.Parent = model
	table.insert(self.parts, {
		part = part,
		offset = offset,
		baseTransparency = part.Transparency,
	})

	return part
end

function WeaponVisuals:_addArms(model, leftHandOffset, rightHandOffset)
	local sleeveColor = Color3.fromRGB(95, 106, 90)
	local handColor = Color3.fromRGB(224, 178, 132)

	self:_addPart(model, "Part", "RightForearm", Vector3.new(0.24, 0.24, 0.72), sleeveColor, rightHandOffset * CFrame.new(0, 0.06, 0.28) * CFrame.Angles(math.rad(8), 0, 0), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "RightHand", Vector3.new(0.28, 0.22, 0.26), handColor, rightHandOffset * CFrame.new(0, 0, -0.13), MATERIAL_SMOOTH)

	if leftHandOffset then
		self:_addPart(model, "Part", "LeftForearm", Vector3.new(0.24, 0.24, 0.74), sleeveColor, leftHandOffset * CFrame.new(0, 0.04, 0.3) * CFrame.Angles(math.rad(8), 0, 0), MATERIAL_SMOOTH)
		self:_addPart(model, "Part", "LeftHand", Vector3.new(0.28, 0.22, 0.26), handColor, leftHandOffset * CFrame.new(0, 0, -0.12), MATERIAL_SMOOTH)
	end
end

function WeaponVisuals:_clearModel()
	if self.model then
		self.model:Destroy()
	end

	self.model = nil
	table.clear(self.parts)
end

function WeaponVisuals:_createPistol(model)
	self:_addArms(model, nil, CFrame.new(0.03, -0.36, 0.18) * CFrame.Angles(math.rad(-11), 0, 0))
	self:_addPart(model, "Part", "Grip", Vector3.new(0.24, 0.62, 0.24), Color3.fromRGB(24, 27, 34), CFrame.new(0, -0.29, 0.07) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "GripPanelLeft", Vector3.new(0.03, 0.46, 0.18), Color3.fromRGB(50, 57, 70), CFrame.new(-0.135, -0.3, 0.07) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "Frame", Vector3.new(0.38, 0.24, 0.82), Color3.fromRGB(36, 41, 50), CFrame.new(0, 0, -0.2), MATERIAL_METAL)
	self:_addPart(model, "Part", "Slide", Vector3.new(0.43, 0.18, 0.9), Color3.fromRGB(78, 88, 102), CFrame.new(0, 0.17, -0.25), MATERIAL_METAL)
	self:_addPart(model, "Part", "EjectionPort", Vector3.new(0.2, 0.025, 0.18), Color3.fromRGB(14, 16, 20), CFrame.new(0.07, 0.272, -0.32), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "Barrel", Vector3.new(0.15, 0.15, 0.54), Color3.fromRGB(16, 19, 24), CFrame.new(0, 0.16, -0.77), MATERIAL_METAL)
	self:_addPart(model, "Part", "Muzzle", Vector3.new(0.2, 0.2, 0.08), Color3.fromRGB(8, 10, 13), CFrame.new(0, 0.16, -1.06), MATERIAL_METAL)
	self:_addPart(model, "Part", "TriggerGuard", Vector3.new(0.32, 0.05, 0.24), Color3.fromRGB(22, 25, 31), CFrame.new(0, -0.18, -0.2), MATERIAL_METAL)
	self:_addPart(model, "Part", "FrontSight", Vector3.new(0.08, 0.08, 0.06), Color3.fromRGB(210, 204, 183), CFrame.new(0, 0.3, -0.7), MATERIAL_METAL)
	self:_addPart(model, "Part", "RearSight", Vector3.new(0.16, 0.06, 0.05), Color3.fromRGB(220, 230, 242), CFrame.new(0, 0.3, 0.1), MATERIAL_SMOOTH)
end

function WeaponVisuals:_createSniper(model)
	self:_addArms(model, CFrame.new(-0.34, -0.3, -0.58) * CFrame.Angles(math.rad(-6), math.rad(-4), math.rad(3)), CFrame.new(0.08, -0.38, 0.06) * CFrame.Angles(math.rad(-11), 0, 0))
	self:_addPart(model, "Part", "Stock", Vector3.new(0.34, 0.3, 0.9), Color3.fromRGB(30, 36, 43), CFrame.new(0, -0.08, 0.42), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "CheekRest", Vector3.new(0.28, 0.12, 0.42), Color3.fromRGB(43, 51, 62), CFrame.new(0, 0.14, 0.42), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "Receiver", Vector3.new(0.36, 0.25, 0.95), Color3.fromRGB(58, 67, 78), CFrame.new(0, 0.02, -0.34), MATERIAL_METAL)
	self:_addPart(model, "Part", "Bolt", Vector3.new(0.1, 0.1, 0.32), Color3.fromRGB(115, 126, 140), CFrame.new(0.25, 0.1, -0.22), MATERIAL_METAL)
	self:_addPart(model, "Part", "Barrel", Vector3.new(0.12, 0.12, 1.68), Color3.fromRGB(18, 22, 27), CFrame.new(0, 0.03, -1.47), MATERIAL_METAL)
	self:_addPart(model, "Part", "MuzzleBrake", Vector3.new(0.28, 0.18, 0.18), Color3.fromRGB(29, 34, 40), CFrame.new(0, 0.03, -2.35), MATERIAL_METAL)
	self:_addPart(model, "Part", "Grip", Vector3.new(0.23, 0.54, 0.21), Color3.fromRGB(25, 29, 35), CFrame.new(0.02, -0.36, -0.02) * CFrame.Angles(math.rad(-10), 0, 0), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "ScopeBody", Vector3.new(0.3, 0.24, 0.78), Color3.fromRGB(18, 23, 30), CFrame.new(0, 0.32, -0.38), MATERIAL_METAL)
	self:_addPart(model, "Part", "ScopeFront", Vector3.new(0.38, 0.3, 0.16), Color3.fromRGB(18, 23, 30), CFrame.new(0, 0.32, -0.83), MATERIAL_METAL)
	self:_addPart(model, "Part", "ScopeLens", Vector3.new(0.28, 0.22, 0.04), Color3.fromRGB(81, 112, 127), CFrame.new(0, 0.32, -0.94), MATERIAL_SMOOTH, 0.25)
	self:_addPart(model, "Part", "ForeRail", Vector3.new(0.42, 0.08, 0.78), Color3.fromRGB(36, 42, 50), CFrame.new(0, -0.12, -0.86), MATERIAL_METAL)
end

function WeaponVisuals:_createKnife(model)
	self:_addArms(model, nil, CFrame.new(0.02, -0.32, 0.22) * CFrame.Angles(math.rad(-21), math.rad(7), math.rad(-8)))
	self:_addPart(model, "Part", "Handle", Vector3.new(0.2, 0.2, 0.7), Color3.fromRGB(28, 32, 39), CFrame.new(0, -0.04, 0.16), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "HandleWrapA", Vector3.new(0.23, 0.03, 0.12), Color3.fromRGB(88, 96, 110), CFrame.new(0, 0.11, 0.26), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "HandleWrapB", Vector3.new(0.23, 0.03, 0.12), Color3.fromRGB(88, 96, 110), CFrame.new(0, -0.13, 0.04), MATERIAL_SMOOTH)
	self:_addPart(model, "WedgePart", "Blade", Vector3.new(0.34, 0.08, 0.92), Color3.fromRGB(218, 225, 235), CFrame.new(0, 0.02, -0.6) * CFrame.Angles(0, math.rad(180), 0), MATERIAL_METAL)
	self:_addPart(model, "Part", "BladeSpine", Vector3.new(0.08, 0.04, 0.74), Color3.fromRGB(182, 189, 184), CFrame.new(0, 0.07, -0.58), MATERIAL_METAL, 0.25)
	self:_addPart(model, "Part", "Guard", Vector3.new(0.5, 0.08, 0.1), Color3.fromRGB(76, 83, 94), CFrame.new(0, 0, -0.18), MATERIAL_METAL)
end

function WeaponVisuals:setWeapon(weaponId)
	self.currentWeaponId = weaponId
	self.equipStartedAt = os.clock()
	self.recoil = 0
	self:_clearModel()

	local model = Instance.new("Model")
	model.Name = weaponId .. "Viewmodel"
	model.Parent = workspace.CurrentCamera or workspace
	self.model = model

	if weaponId == "Sniper" then
		self:_createSniper(model)
	elseif weaponId == "Knife" then
		self:_createKnife(model)
	else
		self:_createPistol(model)
	end
end

function WeaponVisuals:setSprinting(isSprinting)
	self.sprinting = isSprinting
end

function WeaponVisuals:setScoped(isScoped)
	self.scoped = isScoped
end

function WeaponVisuals:kick(weaponId)
	local config = self.WeaponConfig.get(weaponId)
	self.recoil = math.max(self.recoil, config and config.recoilKick or 0.08)
	self.fireStartedAt = os.clock()
end

function WeaponVisuals:_getAnimationCFrame(deltaTime)
	local mouseDelta = UserInputService:GetMouseDelta()
	local targetSway = Vector2.new(
		math.clamp(-mouseDelta.X * 0.002, -0.04, 0.04),
		math.clamp(-mouseDelta.Y * 0.002, -0.035, 0.035)
	)
	local swayAlpha = math.clamp(deltaTime * 14, 0, 1)
	self.sway = self.sway + (targetSway - self.sway) * swayAlpha

	local timeNow = os.clock()
	local sprintAlpha = self.sprinting and 1 or 0
	local bobSpeed = self.sprinting and 14 or 8
	local bobAmount = self.sprinting and 0.035 or 0.007
	local bob = CFrame.new(
		math.sin(timeNow * bobSpeed) * bobAmount,
		math.abs(math.cos(timeNow * bobSpeed)) * bobAmount * 0.75,
		self.recoil
	)

	local equipAlpha = smoothStep(math.min((timeNow - self.equipStartedAt) / 0.22, 1))
	local equipMotion = CFrame.new(0, (1 - equipAlpha) * 0.5, (1 - equipAlpha) * 0.36) * CFrame.Angles(math.rad((1 - equipAlpha) * -18), math.rad((1 - equipAlpha) * 10), 0)

	local fireAlpha = 1 - math.clamp((timeNow - self.fireStartedAt) / 0.14, 0, 1)
	local fireMotion = CFrame.new(0, 0, fireAlpha * 0.06) * CFrame.Angles(math.rad(fireAlpha * 7), math.rad(fireAlpha * -2), math.rad(fireAlpha * 1.5))

	local swayMotion = CFrame.Angles(self.sway.Y, self.sway.X, self.sway.X * 0.45)
	local sprintOffset = SPRINT_OFFSETS[self.currentWeaponId] or CFrame.new()
	local sprintMotion = CFrame.new():Lerp(sprintOffset, sprintAlpha)

	return sprintMotion * bob * swayMotion * fireMotion * equipMotion
end

function WeaponVisuals:_render(deltaTime)
	local camera = workspace.CurrentCamera
	if not camera or not self.model then
		return
	end

	if self.model.Parent ~= camera then
		self.model.Parent = camera
	end

	self.recoil = math.max(0, self.recoil - deltaTime * 5.5)

	local offset = WEAPON_OFFSETS[self.currentWeaponId] or WEAPON_OFFSETS.Pistol
	local root = camera.CFrame * offset * self:_getAnimationCFrame(deltaTime)
	local hideForScope = self.currentWeaponId == "Sniper" and self.scoped

	for _, entry in ipairs(self.parts) do
		entry.part.CFrame = root * entry.offset
		entry.part.Transparency = hideForScope and 1 or entry.baseTransparency
	end
end

function WeaponVisuals:drawTracer(origin, direction, range, accentColor)
	local length = math.min(range, 420)
	local tracer = Instance.new("Part")
	tracer.Name = "LocalTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Color = accentColor or Color3.fromRGB(245, 248, 255)
	tracer.Material = MATERIAL_NEON
	tracer.Size = Vector3.new(0.035, 0.035, length)
	tracer.Transparency = 0.2
	tracer.CFrame = CFrame.lookAt(origin + direction * (length * 0.5), origin + direction * length)
	tracer.Parent = workspace

	local tween = TweenService:Create(tracer, TweenInfo.new(0.08), { Transparency = 1 })
	tween:Play()
	Debris:AddItem(tracer, 0.12)
end

function WeaponVisuals:drawMuzzleFlash(origin, accentColor)
    local burst = Instance.new("Part")
    burst.Name = "LocalBotMuzzle"
    burst.Anchored = true
    burst.CanCollide = false
    burst.CanQuery = false
    burst.CanTouch = false
    burst.CastShadow = false
    burst.Material = MATERIAL_NEON
    burst.Shape = Enum.PartType.Ball
    burst.Size = Vector3.new(0.27, 0.27, 0.27)
    burst.Color = accentColor or Color3.fromRGB(244, 202, 132)
    burst.CFrame = CFrame.new(origin)
    burst.Parent = workspace
    local tween = TweenService:Create(burst, TweenInfo.new(0.11), {
        Size = Vector3.new(0.06, 0.06, 0.06),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(burst, 0.16)
end

function WeaponVisuals:_playSoundLayer(parent, layer)
	local sound = Instance.new("Sound")
	sound.Name = "FireLayer"
	sound.SoundId = layer.soundId
	sound.Volume = layer.volume or 0.5
	sound.PlaybackSpeed = (layer.playbackSpeed or 1) + self.random:NextNumber(-0.035, 0.035)
	sound.RollOffMaxDistance = 160
	sound.RollOffMinDistance = 6
	sound.Parent = parent
	sound:Play()
end

function WeaponVisuals:playFireSound(weaponId, origin)
	local config = self.WeaponConfig.get(weaponId)
	if not config then
		return
	end

	local emitter = Instance.new("Part")
	emitter.Name = weaponId .. "FireSound"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Position = origin
	emitter.Parent = workspace

	if config.soundLayers then
		for _, layer in ipairs(config.soundLayers) do
			self:_playSoundLayer(emitter, layer)
		end
	elseif config.fireSoundId then
		self:_playSoundLayer(emitter, {
			soundId = config.fireSoundId,
			volume = config.fireVolume,
			playbackSpeed = config.firePlaybackSpeed,
		})
	end

	Debris:AddItem(emitter, 2)
end

return WeaponVisuals
