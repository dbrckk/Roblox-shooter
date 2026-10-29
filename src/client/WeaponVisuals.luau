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
	AssaultRifle = CFrame.new(0.51, -0.59, -1.37) * CFrame.Angles(math.rad(-2), math.rad(5), 0),
	Shotgun = CFrame.new(0.54, -0.62, -1.41) * CFrame.Angles(math.rad(-3), math.rad(6), 0),
	Pistol = CFrame.new(0.72, -0.58, -1.2) * CFrame.Angles(math.rad(-2), math.rad(7), math.rad(-1)),
	Sniper = CFrame.new(0.5, -0.5, -1.46) * CFrame.Angles(math.rad(-1), math.rad(4), 0),
	Knife = CFrame.new(0.7, -0.58, -1.08) * CFrame.Angles(math.rad(-18), math.rad(16), math.rad(-12)),
}

local SPRINT_OFFSETS = {
	AssaultRifle = CFrame.new(0.14, -0.12, 0.17) * CFrame.Angles(math.rad(-12), math.rad(19), math.rad(6)),
	Shotgun = CFrame.new(0.14, -0.12, 0.17) * CFrame.Angles(math.rad(-12), math.rad(19), math.rad(6)),
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
	self.currentWeaponId = "AssaultRifle"
	self.model = nil
	self.parts = {}
	self.recoil = 0
	self.fireStartedAt = -math.huge
	self.equipStartedAt = os.clock()
	self.sprinting = false
	self.scoped = false
    self.aimBlend = 0
    self.reloadActive = false
    self.reloadStartedAt = 0
    self.reloadBlend = 0
    self.stepPhase = 0
    self.stepBlend = 0
    self.lastCameraPosition = nil
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

-- Original procedural firearm meshes; no third-party asset IDs or imported weapons.
function WeaponVisuals:_createAssaultRifle(model)
    local charcoal = Color3.fromRGB(38, 44, 42)
    local graphite = Color3.fromRGB(65, 74, 71)
    local olive = Color3.fromRGB(111, 121, 88)
    local steel = Color3.fromRGB(126, 132, 119)
    self:_addArms(model,
        CFrame.new(-0.32, -0.31, -0.66) * CFrame.Angles(math.rad(-8), 0, 0),
        CFrame.new(0.07, -0.36, 0.09) * CFrame.Angles(math.rad(-10), 0, 0))
    self:_addPart(model, "Part", "Receiver", Vector3.new(0.42, 0.31, 1.25), graphite, CFrame.new(0, 0, -0.36), MATERIAL_METAL)
    self:_addPart(model, "Part", "UpperRail", Vector3.new(0.28, 0.08, 1.20), charcoal, CFrame.new(0, 0.20, -0.44), MATERIAL_METAL)
    self:_addPart(model, "Part", "EjectionPort", Vector3.new(0.025, 0.09, 0.34), charcoal, CFrame.new(0.222, 0.09, -0.27), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "Stock", Vector3.new(0.32, 0.24, 0.78), charcoal, CFrame.new(0, -0.03, 0.64), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "StockPad", Vector3.new(0.38, 0.40, 0.10), olive, CFrame.new(0, -0.06, 1.03), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "PistolGrip", Vector3.new(0.26, 0.58, 0.28), charcoal,
        CFrame.new(0, -0.41, 0.05) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "Magazine", Vector3.new(0.28, 0.61, 0.29), charcoal,
        CFrame.new(0, -0.46, -0.48) * CFrame.Angles(math.rad(-11), 0, 0), MATERIAL_METAL)
    self:_addPart(model, "Part", "Handguard", Vector3.new(0.49, 0.33, 0.93), olive, CFrame.new(0, -0.015, -1.32), MATERIAL_METAL)
    self:_addPart(model, "Part", "HandguardInset", Vector3.new(0.50, 0.14, 0.42), charcoal, CFrame.new(0, -0.02, -1.39), MATERIAL_METAL)
    self:_addPart(model, "Part", "Barrel", Vector3.new(0.17, 0.17, 0.89), steel, CFrame.new(0, 0.03, -2.06), MATERIAL_METAL)
    self:_addPart(model, "Part", "FlashHider", Vector3.new(0.22, 0.20, 0.24), charcoal, CFrame.new(0, 0.03, -2.61), MATERIAL_METAL)
    self:_addPart(model, "Part", "FrontSight", Vector3.new(0.13, 0.23, 0.11), charcoal, CFrame.new(0, 0.30, -1.91), MATERIAL_METAL)
    self:_addPart(model, "Part", "RearSight", Vector3.new(0.13, 0.19, 0.14), charcoal, CFrame.new(0, 0.32, -0.05), MATERIAL_METAL)
    self:_addPart(model, "Part", "ChargingHandle", Vector3.new(0.25, 0.09, 0.18), steel, CFrame.new(0, 0.20, 0.18), MATERIAL_METAL)
end

function WeaponVisuals:_createShotgun(model)
    local sand = Color3.fromRGB(178, 161, 128)
    local charcoal = Color3.fromRGB(38, 42, 40)
    local steel = Color3.fromRGB(89, 99, 97)
    self:_addArms(model,
        CFrame.new(-0.29, -0.35, -0.83) * CFrame.Angles(math.rad(-8), 0, 0),
        CFrame.new(0.08, -0.40, 0.13) * CFrame.Angles(math.rad(-11), 0, 0))
    self:_addPart(model, "Part", "Receiver", Vector3.new(0.50, 0.33, 1.05), steel, CFrame.new(0, 0, -0.17), MATERIAL_METAL)
    self:_addPart(model, "Part", "Stock", Vector3.new(0.36, 0.33, 1.00), charcoal, CFrame.new(0, -0.11, 0.83), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "RecoilPad", Vector3.new(0.38, 0.46, 0.12), sand, CFrame.new(0, -0.14, 1.34), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "Grip", Vector3.new(0.26, 0.48, 0.26), charcoal, CFrame.new(0, -0.38, 0.23) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "PumpAction", Vector3.new(0.55, 0.32, 0.79), sand, CFrame.new(0, -0.10, -1.11), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "PumpGrooveA", Vector3.new(0.56, 0.06, 0.12), charcoal, CFrame.new(0, -0.09, -1.02), MATERIAL_METAL)
    self:_addPart(model, "Part", "PumpGrooveB", Vector3.new(0.56, 0.06, 0.12), charcoal, CFrame.new(0, -0.09, -1.28), MATERIAL_METAL)
    self:_addPart(model, "Part", "Barrel", Vector3.new(0.23, 0.23, 1.52), charcoal, CFrame.new(0, 0.10, -1.52), MATERIAL_METAL)
    self:_addPart(model, "Part", "TubeMagazine", Vector3.new(0.19, 0.19, 1.41), steel, CFrame.new(0, -0.18, -1.43), MATERIAL_METAL)
    self:_addPart(model, "Part", "MuzzleRing", Vector3.new(0.31, 0.31, 0.12), charcoal, CFrame.new(0, 0.10, -2.31), MATERIAL_METAL)
    self:_addPart(model, "Part", "ShellCarrier", Vector3.new(0.08, 0.21, 0.43), sand, CFrame.new(-0.30, 0.02, -0.10), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "Sight", Vector3.new(0.09, 0.13, 0.10), sand, CFrame.new(0, 0.25, -2.12), MATERIAL_METAL)
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
    self.reloadActive = false
    self.reloadBlend = 0
    self.lastCameraPosition = nil
	self:_clearModel()

	local model = Instance.new("Model")
	model.Name = weaponId .. "Viewmodel"
	model.Parent = workspace.CurrentCamera or workspace
	self.model = model

	if weaponId == "AssaultRifle" then
        self:_createAssaultRifle(model)
    elseif weaponId == "Shotgun" then
        self:_createShotgun(model)
    elseif weaponId == "Sniper" then
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

-- Reload state comes only from server Ammo messages. Repeated snapshots
-- must not restart the timeline, and canceled reloads fade out smoothly.
function WeaponVisuals:setReloading(weaponId, active)
    if weaponId ~= self.currentWeaponId then return end
    if active and not self.reloadActive then
        self.reloadStartedAt = os.clock()
    end
    self.reloadActive = active == true
end

function WeaponVisuals:kick(weaponId)
	local config = self.WeaponConfig.get(weaponId)
	self.recoil = math.max(self.recoil, config and config.recoilKick or 0.08)
	self.fireStartedAt = os.clock()
end

function WeaponVisuals:_getAnimationCFrame(deltaTime, camera, motion, reloadingPose)
	local mouseDelta = UserInputService:GetMouseDelta()
	local targetSway = Vector2.new(
		math.clamp(-mouseDelta.X * 0.002, -0.04, 0.04),
		math.clamp(-mouseDelta.Y * 0.002, -0.035, 0.035)
	)
	local swayAlpha = math.clamp(deltaTime * 14, 0, 1)
	self.sway = self.sway + (targetSway - self.sway) * swayAlpha

	local timeNow = os.clock()
	local sprintAlpha = self.sprinting and 1 or 0
    -- Bob follows actual movement, not uptime: idling and airborne
    -- no longer make the weapon glide as if the operator were running.
    local movement = motion or 0
    local bobAmount = (self.sprinting and 0.035 or 0.014) * movement
    local cadence = self.sprinting and 13.5 or 10
    self.stepPhase = (self.stepPhase + cadence * deltaTime * movement) % (math.pi * 2)
	local bob = CFrame.new(
		math.sin(self.stepPhase) * bobAmount,
		math.abs(math.cos(self.stepPhase)) * bobAmount * 0.7,
		self.recoil
	)

	local equipAlpha = smoothStep(math.min((timeNow - self.equipStartedAt) / 0.22, 1))
	local equipMotion = CFrame.new(0, (1 - equipAlpha) * 0.5, (1 - equipAlpha) * 0.36)
        * CFrame.Angles(math.rad((1 - equipAlpha) * -18), math.rad((1 - equipAlpha) * 10), 0)

	local fireAlpha = 1 - math.clamp((timeNow - self.fireStartedAt) / 0.14, 0, 1)
	local fireMotion = CFrame.new(0, 0, fireAlpha * 0.06)
        * CFrame.Angles(math.rad(fireAlpha * 7), math.rad(fireAlpha * -2), math.rad(fireAlpha * 1.5))

	local swayMotion = CFrame.Angles(self.sway.Y, self.sway.X, self.sway.X * 0.45)
	local sprintOffset = SPRINT_OFFSETS[self.currentWeaponId] or CFrame.new()
	local sprintMotion = CFrame.new():Lerp(sprintOffset, sprintAlpha)

    -- Distinct, readable reload dip and roll. Rifle, pistol and sniper
    -- all share this timeline, with their own server-configured duration.
    local reloadMotion = CFrame.new(0.07 * reloadingPose, -0.16 * reloadingPose, 0.16 * reloadingPose)
        * CFrame.Angles(math.rad(17 * reloadingPose), math.rad(12 * reloadingPose),
            math.rad(10 * reloadingPose))
	return sprintMotion * bob * swayMotion * fireMotion * reloadMotion * equipMotion
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

    local now = os.clock()
    local reloadConfig = self.WeaponConfig.get(self.currentWeaponId)
    local reloadSeconds = reloadConfig and reloadConfig.reloadSeconds or 2
    local progress = math.clamp((now - self.reloadStartedAt) / math.max(reloadSeconds, 0.25), 0, 1)
    local reloadTarget = self.reloadActive and 1 or 0
    self.reloadBlend += (reloadTarget - self.reloadBlend) * math.clamp(deltaTime * 13, 0, 1)
    -- Smooth pose in/out, with a distinct magazine manipulation around mid-reload.
    local reloadPose = self.reloadBlend * math.sin(math.pi * progress * 0.93)
    local magazineDip = self.reloadActive
        and smoothStep(math.clamp((progress - 0.22) / 0.18, 0, 1))
            * (1 - smoothStep(math.clamp((progress - 0.58) / 0.18, 0, 1)))
        or 0

    local character = game:GetService("Players").LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local moving = 0
    if humanoid and rootPart and humanoid.Health > 0
        and humanoid.FloorMaterial ~= Enum.Material.Air then
        local velocity = rootPart.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        moving = math.clamp(horizontalSpeed / math.max(12, humanoid.WalkSpeed), 0, 1)
    end
    self.stepBlend += (moving - self.stepBlend) * math.clamp(deltaTime * 9, 0, 1)

	local offset = WEAPON_OFFSETS[self.currentWeaponId] or WEAPON_OFFSETS.Pistol
    local aimTarget = self.scoped and self.currentWeaponId ~= "Sniper" and 1 or 0
    self.aimBlend += (aimTarget - self.aimBlend) * math.clamp(deltaTime * 13, 0, 1)
    -- Smooth sight alignment for iron-sight weapons. The sniper uses its
    -- dedicated scope overlay and hides the viewmodel when scoped.
    local aimOffset = CFrame.new(-0.40, 0.13, -0.14)
        * CFrame.Angles(math.rad(-2), math.rad(-4), 0)
    local root = camera.CFrame * offset * CFrame.new():Lerp(aimOffset, self.aimBlend)
        * self:_getAnimationCFrame(deltaTime, camera, self.stepBlend, reloadPose)
	local hideForScope = self.currentWeaponId == "Sniper" and self.scoped

	for _, entry in ipairs(self.parts) do
        local localOffset = entry.offset
        local partName = entry.part.Name
        if partName == "LeftHand" or partName == "LeftForearm" then
            -- The support hand works the magazine while the weapon is dipped.
            localOffset = localOffset * CFrame.new(0.13 * magazineDip,
                -0.22 * magazineDip, -0.11 * magazineDip)
        elseif partName == "Magazine" and self.currentWeaponId ~= "Shotgun" then
            -- A detachable magazine drops and seats before the reload completes.
            localOffset = localOffset * CFrame.new(0, -0.36 * magazineDip,
                0.04 * magazineDip)
        end
		entry.part.CFrame = root * localOffset
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

-- Brief, surface-sensitive physical impact fragments; never gameplay geometry.
-- Capped count, lifespan and visibility distance keep Android overdraw bounded.
function WeaponVisuals:drawImpact(position, normal, materialName)
    if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then return end
    if normal.Magnitude < 0.9 then return end
    local camera = workspace.CurrentCamera
    local touch = UserInputService.TouchEnabled
    if not camera or (camera.CFrame.Position - position).Magnitude > (touch and 100 or 185) then return end
    local now = os.clock()
    if now - (self.lastImpactAt or -math.huge) < (touch and 0.105 or 0.065) then return end
    self.lastImpactAt = now

    local metallic = materialName == "Metal" or materialName == "DiamondPlate"
        or materialName == "CorrodedMetal" or materialName == "Foil"
    local woody = materialName == "Wood" or materialName == "WoodPlanks"
    local tint = metallic and Color3.fromRGB(242, 190, 107)
        or (woody and Color3.fromRGB(188, 154, 108) or Color3.fromRGB(182, 177, 164))
    local n = normal.Unit
    local reference = math.abs(n.Y) > 0.88 and Vector3.xAxis or Vector3.yAxis
    local tangent = n:Cross(reference).Unit
    local bitangent = n:Cross(tangent).Unit
    local count = touch and 2 or 4
    for i = 1, count do
        local angle = i / count * math.pi * 2 + self.random:NextNumber(-0.25, 0.25)
        local spread = tangent * math.cos(angle) + bitangent * math.sin(angle)
        local direction = (n * self.random:NextNumber(0.4, 0.8) + spread).Unit
        local length = self.random:NextNumber(0.22, metallic and 0.85 or 0.56)
        local center = position + n * 0.10 + direction * (length * 0.5)
        local chip = Instance.new("Part")
        chip.Name = "IronYardImpactChip"
        configurePart(chip)
        chip.Material = metallic and MATERIAL_NEON or MATERIAL_SMOOTH
        chip.Color = tint
        chip.Size = Vector3.new(0.034, 0.034, length)
        chip.CFrame = CFrame.lookAt(center, center + direction)
        chip.Transparency = 0.12
        chip.Parent = workspace
        TweenService:Create(chip, TweenInfo.new(metallic and 0.16 or 0.22), {
            Transparency = 1,
            Size = Vector3.new(0.02, 0.02, 0.045),
        }):Play()
        Debris:AddItem(chip, 0.28)
    end
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
