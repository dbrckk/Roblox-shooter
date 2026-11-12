local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OperatorFinishes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OperatorFinishes"))
local CombatVfxProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatVfxProfile"))
local TransientFxPool = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TransientFxPool"))
local ImpactMarkPool = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ImpactMarkPool"))
local WeaponFeel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponFeelProfile"))
local WeaponSway = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponSwayPolicy"))
local WeaponDetailPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponDetailPlan"))
local WeaponMeshPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponMeshPolicy"))
local WeaponPbrFxSockets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponPbrFxSockets"))
local WeaponMeshRefresh = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponMeshRefreshPolicy"))
local WeaponMeshSwapState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponMeshSwapState"))
local WeaponMeshLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponMeshLayout"))
local WeaponAudio = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponAudioPolicy"))
local CartridgeEjection = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CartridgeEjectionPolicy"))
local ShotgunReloadVisual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotgunReloadVisual"))
local ViewmodelRenderPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ViewmodelRenderPolicy"))
local WeaponAimPose = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponAimPose"))
local WeaponFxFramePolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponFxFramePolicy"))
local WeaponReloadHandPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponReloadHandPlan"))

local WeaponVisuals = {}
WeaponVisuals.__index = WeaponVisuals

local MATERIAL_METAL = Enum.Material.Metal
local MATERIAL_SMOOTH = Enum.Material.SmoothPlastic
local MATERIAL_NEON = Enum.Material.Neon

local function rgb(channels)
    return Color3.fromRGB(channels[1], channels[2], channels[3])
end

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

-- One shared lookup across all shots; avoid allocating a table on each trigger.
local MUZZLE_NAMES = { Muzzle = true, MuzzleBrake = true,
    MuzzleRing = true, FlashHider = true }

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
    self.aimPose = nil
    self.reloadActive = false
    self.reloadStartedAt = 0
    self.reloadBlend = 0
    self.reloadHandX = 0
    self.reloadHandY = 0
    self.reloadHandZ = 0
    self.lastViewmodelHidden = nil
    self.stepPhase = 0
    self.stepBlend = 0
    self.lastCameraPosition = nil
    self.lastCameraCFrame = nil
	self.sway = Vector2.new(0, 0)
	self.random = Random.new()
    self.impactMarks = {}
    self.nextImpactMarkUpdateAt = 0
    self.transientParts = {}
    -- Track only live slots: pooled Parts persist, but inactive slots must
    -- not be visited by every RenderStepped after the first firefight.
    self.activeTransientIndices = {}
    -- A bounded list of remote emitters only. The local weapon's feedback
    -- has absolute priority and does not consume these slots.
    self.remoteSoundEmitters = {}
    self.cartridgeShots = {}
    self.pendingCartridge = nil
    self.pendingLocalFlashAt = nil
    self.detailTier = nil
    self.currentWeaponImported = false
    self.activeMeshLod = nil
    self.nextWeaponMeshCheck = 0
    -- Update visible detail immediately on graphics setting changes, without
    -- resetting reload state, recoil, camera aim or the equipped weapon.
    self.detailPresetConnection = Players.LocalPlayer:GetAttributeChangedSignal(
        "IronYardGraphicsPreset"):Connect(function()
            self:_syncDetailTier()
        end)
    -- Server-authored rank only affects the cosmetic local viewmodel.
    self.finishConnection = Players.LocalPlayer:GetAttributeChangedSignal(
        "IronYardProgressLevel"):Connect(function()
            self:_applyCareerFinish()
        end)
	-- Draw after the native camera AND our local camera tilt/FOV pass.
    -- A naked RenderStepped connection has no guaranteed order vs Camera.
    RunService:BindToRenderStep("IronYardWeaponViewmodel",
        Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
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
        baseColor = color,
	})

	return part
end

-- Device-specific cosmetic detail is created on equip and updated only
-- when the graphics preset changes. Existing pieces survive tier switches.
function WeaponVisuals:_addDetailGeometry(model, weaponId)
    local preset = Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset")
    local touch = UserInputService.TouchEnabled
    local plans = WeaponDetailPlan.get(weaponId, preset, touch)
    if not plans then return end
    local existing = {}
    for _, entry in ipairs(self.parts) do
        if entry.isDetail then existing[entry.part.Name] = true end
    end
    for _, spec in ipairs(plans) do
        if not existing[spec.name] then
            local className = spec.shape == "Wedge" and "WedgePart" or "Part"
            local shape = spec.shape ~= "Wedge" and Enum.PartType[spec.shape] or nil
            local pos, ang = spec.position, spec.angles
            local offset = CFrame.new(pos[1],pos[2],pos[3])
                * CFrame.Angles(math.rad(ang[1]),math.rad(ang[2]),math.rad(ang[3]))
            self:_addPart(model, className, spec.name,
                Vector3.new(spec.size[1],spec.size[2],spec.size[3]),
                rgb(spec.color), offset,
                spec.finish == "dark" and MATERIAL_SMOOTH or MATERIAL_METAL,
                nil, shape)
            local added = self.parts[#self.parts]
            added.finishRole = spec.finish
            added.isDetail = true
            -- An in-match graphics upgrade must not leak parts into the
            -- sniper optical sight while the rest of the model is hidden.
            added.part.Transparency = ViewmodelRenderPolicy.transparency(
                added.baseTransparency, self.lastViewmodelHidden == true)
        end
    end
    self.detailTier = WeaponDetailPlan.tier(preset, touch)
end

function WeaponVisuals:_syncDetailTier()
    if not self.model or self.currentWeaponImported
        or not WeaponDetailPlan.get(self.currentWeaponId,
            Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
            UserInputService.TouchEnabled) then
        return
    end
    local preset = Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset")
    local touch = UserInputService.TouchEnabled
    local newTier = WeaponDetailPlan.tier(preset, touch)
    if newTier == self.detailTier then return end
    local allowed = {}
    for _, spec in ipairs(WeaponDetailPlan.get(self.currentWeaponId, preset, touch)) do
        allowed[spec.name] = true
    end
    for i = #self.parts, 1, -1 do
        local entry = self.parts[i]
        if entry.isDetail and not allowed[entry.part.Name] then
            entry.part:Destroy()
            table.remove(self.parts, i)
        end
    end
    self:_addDetailGeometry(self.model, self.currentWeaponId)
    self:_applyCareerFinish()
end

-- Rank-gated finishes recolor only first-person visual Parts, not weapons
-- or armor collision. Applying on level change does not rebuild an active gun.
function WeaponVisuals:_applyCareerFinish()
    if not self.model then return end
    local level = Players.LocalPlayer:GetAttribute("IronYardProgressLevel")
    local finish = OperatorFinishes.forLevel(level)
    local accent, metal = rgb(finish.accent), rgb(finish.metal)
    local fabric, glove = rgb(finish.fabric), rgb(finish.glove)
    local accents = {
        Handguard=true, StockPad=true, RecoilPad=true, PumpAction=true,
        PumpGrooveA=true, PumpGrooveB=true, ScopeFront=true, ForeRail=true,
        ChargingHandle=true, MuzzleRing=true, Guard=true, ShellCarrier=true,
        GripPanelLeft=true, BoltHandleKnob=true, ScopeEyepiece=true,
    }
    local panels = {
        Receiver=true, Slide=true, Frame=true, Bolt=true, UpperRail=true,
        Barrel=true, TubeMagazine=true, BladeSpine=true, ScopeBody=true,
        MuzzleBrake=true, ReceiverDeflector=true, BoltHandle=true,
        GasBlock=true, ScopeRingFront=true, ScopeRingRear=true,
    }
    for _, entry in ipairs(self.parts) do
        if WeaponMeshPolicy.canRetint(entry) then
            local name = entry.part.Name
            local color = entry.baseColor
            if entry.finishRole == "accent" then
                color = accent
            elseif entry.finishRole == "panel" then
                color = entry.baseColor:Lerp(metal, 0.62)
            elseif entry.finishRole == "dark" then
                color = entry.baseColor
            elseif string.find(name, "Forearm", 1, true)
                or string.find(name, "Sleeve", 1, true) then
                color = fabric
            elseif string.find(name, "Glove", 1, true)
                or string.find(name, "Knuckle", 1, true) then
                color = glove
            elseif string.find(name, "WristStrap", 1, true)
                or accents[name] then
                color = accent
            elseif panels[name] then
                color = entry.baseColor:Lerp(metal, 0.78)
            end
            entry.part.Color = color
        end
    end
    self.model:SetAttribute("IronYardCareerFinish", finish.name)
end

-- Tactical first-person arms: matte fabric sleeves, reinforced gloves and
-- restrained olive accents, consistent with the VANGUARD industrial palette.
-- These are one local viewmodel's cosmetic parts, never server hitboxes.
function WeaponVisuals:_addArms(model, leftHandOffset, rightHandOffset)
    local fabric = Color3.fromRGB(100, 113, 92)
    local glove = Color3.fromRGB(42, 49, 46)
    local padding = Color3.fromRGB(78, 89, 78)
    local strap = Color3.fromRGB(128, 133, 107)

    local function createArm(side, pose, forearmLength)
        local sleeve = pose * CFrame.new(0, 0.06, 0.28) * CFrame.Angles(math.rad(8), 0, 0)
        self:_addPart(model, "Part", side .. "Forearm",
            Vector3.new(0.27, 0.28, forearmLength), fabric, sleeve, Enum.Material.Fabric)
        self:_addPart(model, "Part", side .. "SleeveHem",
            Vector3.new(0.31, 0.31, 0.14), padding,
            pose * CFrame.new(0, 0.05, 0.13), MATERIAL_SMOOTH)
        self:_addPart(model, "Part", side .. "Glove",
            Vector3.new(0.29, 0.22, 0.27), glove,
            pose * CFrame.new(0, 0, -0.13), MATERIAL_SMOOTH)
        self:_addPart(model, "Part", side .. "KnucklePanel",
            Vector3.new(0.27, 0.055, 0.19), padding,
            pose * CFrame.new(0, 0.133, -0.18), MATERIAL_SMOOTH)
        self:_addPart(model, "Part", side .. "WristStrap",
            Vector3.new(0.33, 0.08, 0.12), strap,
            pose * CFrame.new(0, 0.075, 0.065), Enum.Material.Fabric)
        self:_addPart(model, "Part", side .. "SleevePanel",
            Vector3.new(0.17, 0.025, 0.29), padding,
            pose * CFrame.new(0, 0.22, 0.38), Enum.Material.Fabric)
    end

    createArm("Right", rightHandOffset, 0.72)
    if leftHandOffset then
        createArm("Left", leftHandOffset, 0.74)
    end
end

function WeaponVisuals:_clearModel()
	if self.model then
		self.model:Destroy()
	end

	self.model = nil
	table.clear(self.parts)
    self.lastViewmodelHidden = nil
    self.detailTier = nil
end

function WeaponVisuals:_createPistol(model)
	self:_addArms(model,
        CFrame.new(-0.27, -0.54, 0.08) * CFrame.Angles(math.rad(-8), math.rad(12), 0),
        CFrame.new(0.03, -0.36, 0.18) * CFrame.Angles(math.rad(-11), 0, 0))
	self:_addPart(model, "Part", "Grip", Vector3.new(0.24, 0.62, 0.24), Color3.fromRGB(24, 27, 34), CFrame.new(0, -0.29, 0.07) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "GripPanelLeft", Vector3.new(0.03, 0.46, 0.18), Color3.fromRGB(50, 57, 70), CFrame.new(-0.135, -0.3, 0.07) * CFrame.Angles(math.rad(-14), 0, 0), MATERIAL_SMOOTH)
    -- The sidearm now has a distinct magazine and baseplate that animate
    -- through the existing server-confirmed reload pose, without physics.
    self:_addPart(model, "Part", "Magazine", Vector3.new(0.17, 0.46, 0.16),
        Color3.fromRGB(45, 50, 58),
        CFrame.new(0, -0.49, 0.13) * CFrame.Angles(math.rad(-14), 0, 0),
        MATERIAL_METAL)
    self:_addPart(model, "Part", "MagazineBase", Vector3.new(0.22, 0.09, 0.20),
        Color3.fromRGB(85, 91, 100),
        CFrame.new(0, -0.73, 0.17) * CFrame.Angles(math.rad(-14), 0, 0),
        MATERIAL_METAL)
	self:_addPart(model, "Part", "Frame", Vector3.new(0.38, 0.24, 0.82), Color3.fromRGB(36, 41, 50), CFrame.new(0, 0, -0.2), MATERIAL_METAL)
	self:_addPart(model, "Part", "Slide", Vector3.new(0.43, 0.18, 0.9), Color3.fromRGB(78, 88, 102), CFrame.new(0, 0.17, -0.25), MATERIAL_METAL)
	self:_addPart(model, "Part", "EjectionPort", Vector3.new(0.2, 0.025, 0.18), Color3.fromRGB(14, 16, 20), CFrame.new(0.07, 0.272, -0.32), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "Extractor", Vector3.new(0.035, 0.032, 0.14),
        Color3.fromRGB(139, 145, 149), CFrame.new(0.17, 0.28, -0.33),
        MATERIAL_METAL)
	self:_addPart(model, "Part", "Barrel", Vector3.new(0.15, 0.15, 0.54), Color3.fromRGB(16, 19, 24), CFrame.new(0, 0.16, -0.77), MATERIAL_METAL)
	self:_addPart(model, "Part", "Muzzle", Vector3.new(0.2, 0.2, 0.08), Color3.fromRGB(8, 10, 13), CFrame.new(0, 0.16, -1.06), MATERIAL_METAL)
	self:_addPart(model, "Part", "TriggerGuard", Vector3.new(0.32, 0.05, 0.24), Color3.fromRGB(22, 25, 31), CFrame.new(0, -0.18, -0.2), MATERIAL_METAL)
	self:_addPart(model, "Part", "FrontSight", Vector3.new(0.08, 0.08, 0.06), Color3.fromRGB(210, 204, 183), CFrame.new(0, 0.3, -0.7), MATERIAL_METAL)
	self:_addPart(model, "Part", "RearSight", Vector3.new(0.16, 0.06, 0.05), Color3.fromRGB(220, 230, 242), CFrame.new(0, 0.3, 0.1), MATERIAL_SMOOTH)
    self:_addDetailGeometry(model, "Pistol")
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
    -- Rounded optical tube and lens instead of the original stacked cubes.
    local scopeAxis = CFrame.Angles(math.pi / 2, 0, 0)
    self:_addPart(model, "Part", "ScopeBody", Vector3.new(0.30, 0.78, 0.30), Color3.fromRGB(18, 23, 30), CFrame.new(0, 0.32, -0.38) * scopeAxis, MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeFront", Vector3.new(0.38, 0.16, 0.38), Color3.fromRGB(18, 23, 30), CFrame.new(0, 0.32, -0.83) * scopeAxis, MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeLens", Vector3.new(0.28, 0.04, 0.28), Color3.fromRGB(81, 112, 127), CFrame.new(0, 0.32, -0.94) * scopeAxis, MATERIAL_SMOOTH, 0.25, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeAdjustmentTurret", Vector3.new(0.14, 0.18, 0.14), Color3.fromRGB(63, 72, 76), CFrame.new(0, 0.57, -0.37), MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeAdjustmentCap", Vector3.new(0.17, 0.035, 0.17), Color3.fromRGB(30, 35, 38), CFrame.new(0, 0.68, -0.37), MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    -- Distinct round scope bands, ocular assembly and real bolt handle.
    -- These five mechanical pieces inherit the same single viewmodel root.
    self:_addPart(model, "Part", "ScopeRingFront",
        Vector3.new(0.35, 0.055, 0.35), Color3.fromRGB(88, 94, 102),
        CFrame.new(0, 0.32, -0.65) * scopeAxis,
        MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeRingRear",
        Vector3.new(0.35, 0.055, 0.35), Color3.fromRGB(88, 94, 102),
        CFrame.new(0, 0.32, -0.12) * scopeAxis,
        MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "ScopeEyepiece",
        Vector3.new(0.33, 0.12, 0.33), Color3.fromRGB(41, 47, 54),
        CFrame.new(0, 0.32, 0.09) * scopeAxis,
        MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "BoltHandle",
        Vector3.new(0.25, 0.065, 0.09), Color3.fromRGB(136, 141, 147),
        CFrame.new(0.38, 0.10, -0.22), MATERIAL_METAL)
    self:_addPart(model, "Part", "BoltHandleKnob",
        Vector3.new(0.15, 0.15, 0.15), Color3.fromRGB(48, 54, 59),
        CFrame.new(0.54, 0.10, -0.22), MATERIAL_SMOOTH,
        nil, Enum.PartType.Ball)
	self:_addPart(model, "Part", "ForeRail", Vector3.new(0.42, 0.08, 0.78), Color3.fromRGB(36, 42, 50), CFrame.new(0, -0.12, -0.86), MATERIAL_METAL)
    -- The casing must leave the breech, not the animated Bolt's pivot.
    self:_addPart(model, "Part", "SniperEjectionPort",
        Vector3.new(0.02, 0.02, 0.02), Color3.fromRGB(25, 25, 25),
        CFrame.new(0.27, 0.12, -0.22), MATERIAL_SMOOTH, 1)
    self:_addDetailGeometry(model, "Sniper")
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
    -- Tapered ejection deflector, rotating safety dial and gas block turn
    -- the flat receiver into recognizable industrial firearm geometry.
    self:_addPart(model, "WedgePart", "ReceiverDeflector",
        Vector3.new(0.09, 0.14, 0.16), steel,
        CFrame.new(0.275, 0.08, -0.12) * CFrame.Angles(0, math.pi, 0),
        MATERIAL_METAL)
    self:_addPart(model, "Part", "SelectorDial",
        Vector3.new(0.04, 0.13, 0.13), charcoal,
        CFrame.new(0.24, -0.07, 0.025),
        MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "GasBlock",
        Vector3.new(0.19, 0.20, 0.25), steel,
        CFrame.new(0, 0.14, -1.92), MATERIAL_METAL)
    -- Six recessed ventilation cuts align with the existing handguard.
    -- This surface detail is fixed at equip, not allocated on firing.
    for i = 1, 3 do
        local z = -1.06 - (i - 1) * 0.24
        self:_addPart(model, "Part", "VentLeft" .. i,
            Vector3.new(0.014, 0.09, 0.13), charcoal,
            CFrame.new(-0.257, 0.03, z), MATERIAL_SMOOTH)
        self:_addPart(model, "Part", "VentRight" .. i,
            Vector3.new(0.014, 0.09, 0.13), charcoal,
            CFrame.new(0.257, 0.03, z), MATERIAL_SMOOTH)
    end
    -- Raised rail teeth break the silhouette without adding an optic
    -- obstruction to the rear iron-sight / ADS camera axis.
    for i = 1, 3 do
        self:_addPart(model, "Part", "RailTooth" .. i,
            Vector3.new(0.29, 0.025, 0.045), steel,
            CFrame.new(0, 0.253, -0.27 - (i - 1) * 0.32), MATERIAL_METAL)
    end
    self:_addDetailGeometry(model, "AssaultRifle")
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
    -- Two visible crimson 12-gauge shells with independent brass heads.
    -- Fixed local viewmodel Parts; there is no per-round allocation.
    local shellAxis = CFrame.Angles(math.pi / 2, 0, 0)
    for i = 1, 2 do
        local z = -0.23 + (i - 1) * 0.22
        self:_addPart(model, "Part", "CarrierShellBody" .. i,
            Vector3.new(0.12, 0.18, 0.12), Color3.fromRGB(142, 46, 35),
            CFrame.new(-0.36, 0.02, z) * shellAxis,
            MATERIAL_SMOOTH, nil, Enum.PartType.Cylinder)
        self:_addPart(model, "Part", "CarrierShellBrass" .. i,
            Vector3.new(0.125, 0.052, 0.125), Color3.fromRGB(195, 154, 87),
            CFrame.new(-0.36, 0.02, z + 0.104) * shellAxis,
            MATERIAL_METAL, nil, Enum.PartType.Cylinder)
    end
    -- A real mechanical port also becomes the casing ejection anchor.
    self:_addPart(model, "Part", "ShotgunEjectionPort",
        Vector3.new(0.027, 0.12, 0.28), Color3.fromRGB(14, 17, 17),
        CFrame.new(0.264, 0.085, -0.18), MATERIAL_SMOOTH)
    self:_addPart(model, "Part", "ShotgunLoadingPort",
        Vector3.new(0.25, 0.018, 0.33), Color3.fromRGB(17, 20, 21),
        CFrame.new(0, -0.181, -0.06), MATERIAL_SMOOTH)
    -- Server Ammo feedback alone enables this held/inserted cartridge.
    -- Its initial transparency of 1 keeps it absent outside reload.
    self:_addPart(model, "Part", "LoadingShellBody",
        Vector3.new(0.13, 0.23, 0.13), Color3.fromRGB(166, 46, 37),
        CFrame.new(-0.35, -0.29, 0.24) * shellAxis,
        MATERIAL_SMOOTH, 1, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "LoadingShellBrass",
        Vector3.new(0.138, 0.055, 0.138), Color3.fromRGB(205, 171, 96),
        CFrame.new(-0.35, -0.29, 0.38) * shellAxis,
        MATERIAL_METAL, 1, Enum.PartType.Cylinder)
    self:_addPart(model, "Part", "Sight", Vector3.new(0.09, 0.13, 0.10), sand, CFrame.new(0, 0.25, -2.12), MATERIAL_METAL)
    self:_addPart(model, "Part", "RearSight", Vector3.new(0.19, 0.09, 0.14), charcoal, CFrame.new(0, 0.24, -0.28), MATERIAL_METAL)
    self:_addDetailGeometry(model, "Shotgun")
end

function WeaponVisuals:_createKnife(model)
	self:_addArms(model, nil, CFrame.new(0.02, -0.32, 0.22) * CFrame.Angles(math.rad(-21), math.rad(7), math.rad(-8)))
	self:_addPart(model, "Part", "Handle", Vector3.new(0.2, 0.2, 0.7), Color3.fromRGB(28, 32, 39), CFrame.new(0, -0.04, 0.16), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "HandleWrapA", Vector3.new(0.23, 0.03, 0.12), Color3.fromRGB(88, 96, 110), CFrame.new(0, 0.11, 0.26), MATERIAL_SMOOTH)
	self:_addPart(model, "Part", "HandleWrapB", Vector3.new(0.23, 0.03, 0.12), Color3.fromRGB(88, 96, 110), CFrame.new(0, -0.13, 0.04), MATERIAL_SMOOTH)
	self:_addPart(model, "WedgePart", "Blade", Vector3.new(0.34, 0.08, 0.92), Color3.fromRGB(218, 225, 235), CFrame.new(0, 0.02, -0.6) * CFrame.Angles(0, math.rad(180), 0), MATERIAL_METAL)
	self:_addPart(model, "Part", "BladeSpine", Vector3.new(0.08, 0.04, 0.74), Color3.fromRGB(182, 189, 184), CFrame.new(0, 0.07, -0.58), MATERIAL_METAL, 0.25)
	self:_addPart(model, "Part", "Guard", Vector3.new(0.5, 0.08, 0.1), Color3.fromRGB(76, 83, 94), CFrame.new(0, 0, -0.18), MATERIAL_METAL)
    self:_addDetailGeometry(model, "Knife")
end

-- Load ONLY owner-installed PBR MeshParts from the replicated Studio kit.
-- Nothing is downloaded or script-executed, and the original Part gun stays
-- usable if the imported model, permissions or SurfaceAppearance are incomplete.
-- A single validated source selector is shared by initial equipping and
-- deferred LOD refresh. Incomplete server replication must never hide a gun.
function WeaponVisuals:_getImportedWeapon(weaponId, lod)
    local templates = ReplicatedStorage:FindFirstChild("IronYardWeaponTemplates")
    local category = templates and templates:FindFirstChild(weaponId)
    if not category then return nil end
    local template = category:FindFirstChild(lod)
    if not template or not template:IsA("Model")
        or template:GetAttribute("IronYardStudioApproved") ~= true then
        return nil
    end
    local origin = template:FindFirstChild("WeaponOrigin")
    if not origin or not origin:IsA("BasePart") then return nil end
    local required = WeaponMeshPolicy.Required[weaponId]
    if not required then return nil end
    -- glTF Model hierarchy can split one authored component into several
    -- MeshParts with distinct PBR material maps. Validate all primitives.
    local selected = WeaponMeshLayout.collect(template, required, function(part)
        if not part:IsA("MeshPart") or part.MeshId == ""
            or part.Size.Magnitude < 0.03 or part.Size.Magnitude > 10 then
            return false
        end
        local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
        return appearance ~= nil and WeaponMeshPolicy.mapsReady({
            ColorMap=appearance.ColorMap, NormalMap=appearance.NormalMap,
            RoughnessMap=appearance.RoughnessMap,
            MetalnessMap=appearance.MetalnessMap,
        })
    end, WeaponMeshPolicy.Optional[weaponId])
    if not selected then return nil end
    return origin, selected
end

function WeaponVisuals:_createImportedWeapon(model, weaponId)
    local lod = WeaponMeshPolicy.lod(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    local origin, selected = self:_getImportedWeapon(weaponId, lod)
    if not origin then return false end
    -- Preserve the original hand positions when a validated imported mesh
    -- replaces a procedural firearm. No imported script/rig is executed.
    if weaponId == "Pistol" then
        self:_addArms(model,
            CFrame.new(-0.27, -0.54, 0.08) * CFrame.Angles(math.rad(-8), math.rad(12), 0),
            CFrame.new(0.03, -0.36, 0.18) * CFrame.Angles(math.rad(-11), 0, 0))
    elseif weaponId == "Knife" then
        self:_addArms(model, nil, CFrame.new(0.02, -0.32, 0.22)
            * CFrame.Angles(math.rad(-21), math.rad(7), math.rad(-8)))
    elseif weaponId == "AssaultRifle" then
        self:_addArms(model,
            CFrame.new(-0.32, -0.31, -0.66) * CFrame.Angles(math.rad(-8), 0, 0),
            CFrame.new(0.07, -0.36, 0.09) * CFrame.Angles(math.rad(-10), 0, 0))
    elseif weaponId == "Shotgun" then
        self:_addArms(model,
            CFrame.new(-0.29, -0.35, -0.83) * CFrame.Angles(math.rad(-8), 0, 0),
            CFrame.new(0.08, -0.40, 0.13) * CFrame.Angles(math.rad(-11), 0, 0))
    elseif weaponId == "Sniper" then
        self:_addArms(model,
            CFrame.new(-0.34, -0.3, -0.58)
                * CFrame.Angles(math.rad(-6), math.rad(-4), math.rad(3)),
            CFrame.new(0.08, -0.38, 0.06) * CFrame.Angles(math.rad(-11), 0, 0))
    end
    for _, componentName in ipairs(WeaponMeshPolicy.components(weaponId)) do
      if selected[componentName] then
       for _, sourcePart in ipairs(selected[componentName]) do
        local clone = sourcePart:Clone()
        local appearance = clone:FindFirstChildOfClass("SurfaceAppearance")
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant ~= appearance or descendant.Parent ~= clone then
                descendant:Destroy()
            end
        end
        configurePart(clone)
        -- Reuse the existing one-pass mechanical animation by matching
        -- the names the renderer already understands; static shells never move.
        clone.Name = WeaponMeshPolicy.runtimeName(componentName)
        clone.Parent = model
        table.insert(self.parts, {
            part=clone,
            offset=origin.CFrame:ToObjectSpace(sourcePart.CFrame),
            baseTransparency=clone.Transparency,
            baseColor=clone.Color,
            -- This entire material primitive is authored in Blender.
            -- Never apply rank-wide BasePart.Color recolors to its PBR maps.
            isPbrMesh=true,
        })
       end
      end
    end
    -- Existing local FX and reload samples must keep functional anchors.
    -- All are fully transparent non-colliding client-owned primitives.
    local function anchor(name)
        local x, y, z = WeaponPbrFxSockets.get(weaponId, name)
        if x == nil then return end
        self:_addPart(model, "Part", name,
            Vector3.new(0.02, 0.02, 0.02), Color3.fromRGB(25, 25, 25),
            CFrame.new(x, y, z), MATERIAL_SMOOTH, 1)
    end
    if weaponId == "Pistol" then
        anchor("Muzzle")
        anchor("EjectionPort")
    elseif weaponId == "AssaultRifle" then
        anchor("FlashHider")
        anchor("EjectionPort")
    elseif weaponId == "Shotgun" then
        anchor("MuzzleRing")
        anchor("ShotgunEjectionPort")
        -- Server-confirmed reload still animates one visible shell, as it
        -- does for the procedural shotgun. Never create it per round/frame.
        local shellAxis = CFrame.Angles(math.pi / 2, 0, 0)
        self:_addPart(model, "Part", "LoadingShellBody",
            Vector3.new(0.13, 0.23, 0.13), Color3.fromRGB(166, 46, 37),
            CFrame.new(-0.35, -0.29, 0.24) * shellAxis,
            MATERIAL_SMOOTH, 1, Enum.PartType.Cylinder)
        self:_addPart(model, "Part", "LoadingShellBrass",
            Vector3.new(0.138, 0.055, 0.138), Color3.fromRGB(205, 171, 96),
            CFrame.new(-0.35, -0.29, 0.38) * shellAxis,
            MATERIAL_METAL, 1, Enum.PartType.Cylinder)
    elseif weaponId == "Sniper" then
        anchor("MuzzleBrake")
        anchor("SniperEjectionPort")
    end
    self.currentWeaponImported = true
    self.currentWeaponHasPbrMagazine = weaponId == "Pistol"
        and selected.IRONYARD_Pistol_Magazine ~= nil
    self.activeMeshLod = lod
    model:SetAttribute("IronYardWeaponSource", "PBR_MESH")
    model:SetAttribute("IronYardWeaponLOD", lod)
    return true
end

function WeaponVisuals:setWeapon(weaponId)
    -- A late PBR LOD refresh may change which authored magazine exists.
    self.currentWeaponHasPbrMagazine = false
	self.currentWeaponId = weaponId
    self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap
    self.pendingLocalFlashAt = nil -- prevent late flash from previous weapon
    self.aimBlend = 0
    -- Resolve ADS only AFTER choosing procedural or PBR mesh. Their
    -- rear sights have different authored positions in weaponforge.
    self.aimPose = nil
	self.equipStartedAt = os.clock()
	self.recoil = 0
    self.reloadActive = false
    self.reloadBlend = 0
    self.reloadHandX, self.reloadHandY, self.reloadHandZ = 0, 0, 0
    self.lastCameraPosition = nil
    self.lastCameraCFrame = nil
	self:_clearModel()
    self.currentWeaponImported = false
    self.activeMeshLod = nil
    self.nextWeaponMeshCheck = 0

	local model = Instance.new("Model")
	model.Name = weaponId .. "Viewmodel"
	model.Parent = workspace.CurrentCamera or workspace
	self.model = model

	if weaponId == "AssaultRifle" then
        if not self:_createImportedWeapon(model, "AssaultRifle") then
            self:_createAssaultRifle(model)
        end
    elseif weaponId == "Shotgun" then
        if not self:_createImportedWeapon(model, "Shotgun") then
            self:_createShotgun(model)
        end
    elseif weaponId == "Sniper" then
        if not self:_createImportedWeapon(model, "Sniper") then
            self:_createSniper(model)
        end
	elseif weaponId == "Knife" then
        if not self:_createImportedWeapon(model, "Knife") then
            self:_createKnife(model)
        end
	else
        if not self:_createImportedWeapon(model, "Pistol") then
            self:_createPistol(model)
        end
	end
    if not self.currentWeaponImported then
        model:SetAttribute("IronYardWeaponSource", "PROCEDURAL_PARTS")
    end
    local pose = WeaponAimPose.get(weaponId, self.currentWeaponImported)
    self.aimPose = pose and CFrame.new(pose.x, pose.y, pose.z) or nil
    self:_applyCareerFinish()
    self:_syncScopeVisibility()
end

-- Server-created PBR templates can arrive after the initial equip.
-- Upgrades are deferred until idle; all mesh validation precedes any swap.
function WeaponVisuals:_refreshImportedWeaponIfSafe(now)
    if now < self.nextWeaponMeshCheck then return end
    self.nextWeaponMeshCheck = now + 1.2
    if not self.model or not self.currentWeaponId then return end

    local lod = WeaponMeshPolicy.lod(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    if self.currentWeaponImported and self.activeMeshLod == lod then return end
    -- Cheap animation state test first. Avoid re-scanning dozens of material
    -- MeshParts and four SurfaceAppearance textures while firing or aiming.
    local safe = WeaponMeshRefresh.shouldRefresh(self.currentWeaponImported,
        self.activeMeshLod, lod, true, {
            scoped = self.scoped,
            sprinting = self.sprinting,
            reloading = self.reloadActive,
            pendingCartridge = self.pendingCartridge ~= nil,
            aimBlend = self.aimBlend,
            reloadBlend = self.reloadBlend,
            sinceShot = now - self.fireStartedAt,
            sinceEquip = now - self.equipStartedAt,
        })
    if not safe then return end
    local origin = self:_getImportedWeapon(self.currentWeaponId, lod)
    if origin then
        -- This is not an actual equip. Preserve the currently interpolated
        -- camera, hands, aim, recoil and reload pose while rebuilding the
        -- visuals from newly replicated or higher/lower LOD meshes.
        -- The real weapon, ammo and all server-owned combat state stay put.
        local previousPose = WeaponMeshSwapState.capture(self)
        local weaponId = self.currentWeaponId
        self:setWeapon(weaponId)
        WeaponMeshSwapState.restore(self, previousPose)
        if self.currentWeaponImported then
            self.model:SetAttribute("IronYardWeaponUpgrade", "DEFERRED_IDLE")
        end
    end
end

function WeaponVisuals:setSprinting(isSprinting)
	self.sprinting = isSprinting
end

function WeaponVisuals:_syncScopeVisibility()
    local hidden = ViewmodelRenderPolicy.hidden(self.currentWeaponId, self.scoped)
    if not ViewmodelRenderPolicy.needsUpdate(self.lastViewmodelHidden, hidden) then
        return
    end
    self.lastViewmodelHidden = hidden
    -- The model still moves every frame; opacity changes only when
    -- equipping or entering/exiting the sniper's optical scope.
    for _, entry in ipairs(self.parts) do
        local target = ViewmodelRenderPolicy.transparency(
            entry.baseTransparency, hidden)
        -- Pistol support hand is only visible during a confirmed reload.
        -- Initially hidden on equip and never leaked by ADS changes.
        if self.currentWeaponId == "Pistol"
            and string.sub(entry.part.Name, 1, 4) == "Left" then
            target = 1
        end
        if entry.part.Transparency ~= target then
            entry.part.Transparency = target
        end
    end
end

function WeaponVisuals:setScoped(isScoped)
    self.scoped = isScoped
    self:_syncScopeVisibility()
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

-- Locate the actual animated first-person part for the ejector. A missing
-- viewmodel anchor never creates a casing at the camera origin.
function WeaponVisuals:_ejectCartridge(plan)
    if not self.model or not plan then return end
    local ejector = nil
    for _, entry in ipairs(self.parts) do
        if entry.part.Name == plan.anchor and entry.part.Parent == self.model then
            ejector = entry.part
            break
        end
    end
    if not ejector then return end

    local from = ejector.CFrame * CFrame.new(0.12, 0.08, 0)
    local to = from * CFrame.new(0.76, -0.48, 0.34)
        * CFrame.Angles(1.5, 0.8, 1.2)
    self:_spawnTransient({
        name = "IronYardSpentCartridge",
        origin = from, target = to,
        size = Vector3.new(plan.size[1], plan.size[2], plan.size[3]),
        endSize = Vector3.new(plan.size[1], plan.size[2], plan.size[3]),
        shape = Enum.PartType.Cylinder,
        material = MATERIAL_METAL,
        color = Color3.fromRGB(plan.tint[1], plan.tint[2], plan.tint[3]),
        alpha = 0, duration = plan.duration, priority = 1,
        arcHeight = plan.arc, spinAngle = plan.spin, linear = true,
    })
end

function WeaponVisuals:kick(weaponId)
    local config = self.WeaponConfig.get(weaponId)
    if not config or weaponId ~= self.currentWeaponId then return end
    self.recoil = WeaponFeel.kick(weaponId, self.recoil, config.recoilKick or 0.08)
    self.fireStartedAt = os.clock()
    -- Schedule visible first-person FX until AFTER the final camera-aligned
    -- viewmodel pose is written. No 1-frame-old muzzle/receiver coordinates.
    self.pendingLocalFlashAt = weaponId ~= "Knife" and self.fireStartedAt or nil
    local count = (self.cartridgeShots[weaponId] or 0) + 1
    self.cartridgeShots[weaponId] = count
    local plan = CartridgeEjection.plan(weaponId,
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled, count)
    -- Even a zero-delay pistol/AR casing waits until the updated slide and
    -- ejection port have been rendered. Delayed pump/bolt retain their beat.
    -- Only one pending shell: repeated shots before a frame drop older FX.
    self.pendingCartridge = plan and {
        at = self.fireStartedAt + plan.delay,
        weaponId = weaponId, plan = plan,
    } or nil
end

function WeaponVisuals:_getAnimationCFrame(deltaTime, camera, motion, reloadingPose)
	local mouseDelta = UserInputService:GetMouseDelta()
    -- On touch/gamepad GetMouseDelta is often zero even while the camera
    -- turns. Reuse its actual angular change without moving the hit ray.
    local pitch, yaw = 0, 0
    if self.lastCameraCFrame then
        local delta = self.lastCameraCFrame:ToObjectSpace(camera.CFrame)
        pitch, yaw = delta:ToOrientation()
    end
    self.lastCameraCFrame = camera.CFrame
    local swayX, swayY = WeaponSway.target(mouseDelta.X, mouseDelta.Y,
        UserInputService.TouchEnabled or UserInputService.GamepadEnabled,
        pitch, yaw, deltaTime)
    local targetSway = Vector2.new(swayX, swayY)
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
    local swayFactor, bobFactor = WeaponAimPose.damping(self.aimBlend)
    bobAmount *= bobFactor
	local bob = CFrame.new(
		math.sin(self.stepPhase) * bobAmount,
		math.abs(math.cos(self.stepPhase)) * bobAmount * 0.7,
		self.recoil
	)

	local equipAlpha = smoothStep(math.min((timeNow - self.equipStartedAt) / 0.22, 1))
	local equipMotion = CFrame.new(0, (1 - equipAlpha) * 0.5, (1 - equipAlpha) * 0.36)
        * CFrame.Angles(math.rad((1 - equipAlpha) * -18), math.rad((1 - equipAlpha) * 10), 0)

    local feel = WeaponFeel.get(self.currentWeaponId)
    local fireAlpha = WeaponFeel.shotEnvelope(self.currentWeaponId,
        timeNow - self.fireStartedAt)
    local fireMotion = CFrame.new(0, 0, fireAlpha * feel.back)
        * CFrame.Angles(math.rad(fireAlpha * feel.pitch),
            math.rad(fireAlpha * feel.yaw), math.rad(fireAlpha * feel.roll))

	local swayMotion = CFrame.Angles(self.sway.Y * swayFactor,
        self.sway.X * swayFactor, self.sway.X * 0.45 * swayFactor)
	local sprintOffset = SPRINT_OFFSETS[self.currentWeaponId] or CFrame.new()
	local sprintMotion = CFrame.new():Lerp(sprintOffset, sprintAlpha * (1 - self.aimBlend))

    -- Common server-timed reload progression, visibly different mechanical
    -- grip and roll per original weapon. Never changes the server reload.
    local reloadMotion = CFrame.new(feel.reloadX * reloadingPose,
        feel.reloadY * reloadingPose, feel.reloadZ * reloadingPose)
        * CFrame.Angles(math.rad(feel.reloadPitch * reloadingPose),
            math.rad(feel.reloadYaw * reloadingPose),
            math.rad(feel.reloadRoll * reloadingPose))
	return sprintMotion * bob * swayMotion * fireMotion * reloadMotion * equipMotion
end
function WeaponVisuals:_render(deltaTime)
    -- Preserve actual wall-clock recoil/FX expiry, but cap interpolation after
    -- Android backgrounding or a frame hitch to avoid single-frame pose snaps.
    local animationDt = ViewmodelRenderPolicy.animationDelta(deltaTime)
    -- Pool opacity/expiry is serviced at 8 Hz, not via a Tween and Debris
    -- allocation for every bullet. Reuses the existing RenderStepped hook.
    local clock = os.clock()
    if #self.impactMarks > 0 and clock >= self.nextImpactMarkUpdateAt then
        self.nextImpactMarkUpdateAt = clock + 0.125
        self:_updateImpactMarks(clock)
    end
    -- Sub-300ms effects need smooth animation. The existing render callback
    -- owns their lifecycle; no extra frame loop, task, Tween or Debris entry.
    if next(self.activeTransientIndices) then
        self:_updateTransientFx(clock)
    end
	local camera = workspace.CurrentCamera
	if not camera or not self.model then
		return
	end

	if self.model.Parent ~= camera then
		self.model.Parent = camera
	end

    self:_refreshImportedWeaponIfSafe(clock)
    self.recoil = WeaponFeel.recover(self.currentWeaponId, self.recoil, deltaTime)

    local now = os.clock()
    local reloadConfig = self.WeaponConfig.get(self.currentWeaponId)
    local reloadSeconds = reloadConfig and reloadConfig.reloadSeconds or 2
    local progress = math.clamp((now - self.reloadStartedAt) / math.max(reloadSeconds, 0.25), 0, 1)
    local reloadTarget = self.reloadActive and 1 or 0
    self.reloadBlend += (reloadTarget - self.reloadBlend) * math.clamp(animationDt * 13, 0, 1)
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
    self.stepBlend += (moving - self.stepBlend) * math.clamp(animationDt * 9, 0, 1)

	local offset = WEAPON_OFFSETS[self.currentWeaponId] or WEAPON_OFFSETS.Pistol
    local aimTarget = self.scoped and self.currentWeaponId ~= "Sniper" and 1 or 0
    self.aimBlend += (aimTarget - self.aimBlend) * math.clamp(animationDt * 13, 0, 1)
    -- Blend the full viewmodel root toward each weapon's rear iron sight.
    -- Sniper keeps its dedicated optical overlay and hidden scoped weapon.
    local rootPose = self.aimPose and offset:Lerp(self.aimPose, self.aimBlend)
        or offset
    local root = camera.CFrame * rootPose
        * self:_getAnimationCFrame(animationDt, camera, self.stepBlend, reloadPose)

    -- Short, mechanically coherent motions for actual moving weapon parts.
    -- No physics, sounds or network calls: these offsets are client-only.
    local shotAge = now - self.fireStartedAt
    -- A single equipped gun is animated. No longer evaluate the four
    -- mechanical firing curves for inactive weapons on RenderStepped.
    local actionTravel = WeaponFeel.mechanism(self.currentWeaponId, shotAge)
    local feel = WeaponFeel.get(self.currentWeaponId)
    -- AR magazine: the left glove reaches the detachable PBR/Part magazine
    -- and follows its downward travel. Shotgun: the glove follows the visible
    -- loading shell toward its real port, then returns to the pump. The
    -- 3D forearm, sleeve, glove and straps keep ONE coherent transform.
    local handX, handY, handZ = WeaponReloadHandPlan.sample(
        self.currentWeaponId, progress, self.reloadActive,
        magazineDip, feel.handTravel,
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        self.currentWeaponImported, self.currentWeaponHasPbrMagazine)
    local handAlpha = math.clamp(animationDt * 14, 0, 1)
    self.reloadHandX += (handX - self.reloadHandX) * handAlpha
    self.reloadHandY += (handY - self.reloadHandY) * handAlpha
    self.reloadHandZ += (handZ - self.reloadHandZ) * handAlpha
    local workingHand = CFrame.new(self.reloadHandX, self.reloadHandY, self.reloadHandZ)
    local pistolHandVisibility = self.currentWeaponId == "Pistol"
        and WeaponReloadHandPlan.pistolVisibility(progress, self.reloadActive) or 0
    local boltX, boltY, boltZ = WeaponReloadHandPlan.boltGrip(
        self.currentWeaponId, actionTravel, self.reloadActive, self.scoped)
    local boltAlpha = boltX / 0.32
    local boltHand = CFrame.new(boltX, boltY, boltZ)
        * CFrame.Angles(0, math.rad(15 * boltAlpha),
            math.rad(-18 * boltAlpha))
    -- Pump and support hand move together on a shot; never pump the fore-end
    -- into the left glove while it is inserting a cartridge.
    local supportMotion = self.currentWeaponId == "Shotgun" and not self.reloadActive
        and CFrame.new(0, 0, actionTravel * feel.actionTravel * 0.72)
        or CFrame.new()
    local shellX, shellY, shellZ, shellRoll
    if self.currentWeaponId == "Shotgun" then
        shellX, shellY, shellZ, shellRoll = ShotgunReloadVisual.sample(
            progress, self.reloadActive,
            Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"))
    end

    for _, entry in ipairs(self.parts) do
        local localOffset = entry.offset
        local partName = entry.part.Name
        if string.sub(partName, 1, 4) == "Left" then
            -- One transform for glove, wrist, sleeve, and forearm.
            localOffset = localOffset * workingHand * supportMotion
            if self.currentWeaponId == "Pistol" then
                local opacity = math.max(
                    ViewmodelRenderPolicy.transparency(entry.baseTransparency,
                        self.lastViewmodelHidden == true),
                    1 - pistolHandVisibility)
                if entry.part.Transparency ~= opacity then
                    entry.part.Transparency = opacity
                end
            end
        elseif string.sub(partName, 1, 5) == "Right"
            and self.currentWeaponId == "Sniper" then
            -- The right glove follows the existing bolt action in hip fire.
            localOffset = localOffset * boltHand
        elseif (partName == "LoadingShellBody" or partName == "LoadingShellBrass")
            and self.currentWeaponId == "Shotgun" then
            if shellX then
                localOffset = localOffset * CFrame.new(shellX, shellY, shellZ)
                    * CFrame.Angles(0, 0, shellRoll)
            end
            local targetAlpha = shellX and not self.lastViewmodelHidden and 0 or 1
            if entry.part.Transparency ~= targetAlpha then
                entry.part.Transparency = targetAlpha
            end
        elseif (partName == "Magazine" or partName == "MagazineBase")
            and self.currentWeaponId ~= "Shotgun" then
            localOffset = localOffset * CFrame.new(0, -0.36 * magazineDip * feel.magazineTravel,
                0.04 * magazineDip * feel.magazineTravel)
        elseif partName == "ChargingHandle" and self.currentWeaponId == "AssaultRifle" then
            localOffset = localOffset * CFrame.new(0, 0, actionTravel * feel.actionTravel)
        elseif (partName == "Slide" or partName == "EjectionPort"
            or partName == "Extractor"
            or string.sub(partName, 1, 11) == "SlideDetail")
            and self.currentWeaponId == "Pistol" then
            -- Mechanism and ejection anchor must remain attached to the slide.
            localOffset = localOffset * CFrame.new(0, 0, actionTravel * feel.actionTravel)
        elseif (partName == "PumpAction" or partName == "PumpGrooveA"
            or partName == "PumpGrooveB") and self.currentWeaponId == "Shotgun" then
            localOffset = localOffset * CFrame.new(0, 0, actionTravel * feel.actionTravel)
        elseif (partName == "Bolt" or partName == "BoltHandle"
            or partName == "BoltHandleKnob") and self.currentWeaponId == "Sniper" then
            localOffset = localOffset * CFrame.new(0.8 * feel.actionTravel * actionTravel,
                0, feel.actionTravel * actionTravel)
        end
        entry.part.CFrame = root * localOffset
    end

    -- Emission MUST happen after all parts have their current-frame CFrames.
    -- This closes the input-versus-render race on fast Android camera turns.
    local flashAt = self.pendingLocalFlashAt
    if flashAt ~= nil then
        self.pendingLocalFlashAt = nil
        if WeaponFxFramePolicy.flashReady(self.currentWeaponId, flashAt, now) then
            self:drawLocalMuzzleFlash()
        end
    end
    local pending = self.pendingCartridge
    if pending and now >= pending.at then
        self.pendingCartridge = nil
        if WeaponFxFramePolicy.casingReady(self.currentWeaponId,
            pending.weaponId, pending.at, now) then
            self:_ejectCartridge(pending.plan)
        end
    end
end

-- A single bounded client pool owns every short-lived visual Part
-- (except high-priority confirmed hit glints, which keep their separate HUD
-- priority rules). Every effect resets Shape, material, color and local light
-- state, so different kinds can safely reuse the SAME physical Part.
function WeaponVisuals:_spawnTransient(spec)
    local now = os.clock()
    local cap = TransientFxPool.cap(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    local slot, index = TransientFxPool.claim(self.transientParts,
        now, spec.duration, cap, spec.priority)
    if not slot then return false end
    -- Recycled slots keep the same numeric identity even when a local
    -- muzzle flash preempts lower-priority bot debris.
    self.activeTransientIndices[index] = true
    local part = slot.part
    if not part then
        part = Instance.new("Part")
        configurePart(part)
        slot.part = part
    end
    part.Name = spec.name
    part.Shape = spec.shape or Enum.PartType.Block
    part.Material = spec.material or MATERIAL_SMOOTH
    part.Color = spec.color
    part.Size = spec.size
    part.CFrame = spec.origin
    part.Transparency = spec.alpha
    -- A previously illuminated muzzle core must not light up reused debris.
    if slot.light then slot.light.Enabled = false end
    if spec.lightColor then
        if not slot.light then
            local light = Instance.new("PointLight")
            light.Brightness = 1.25
            light.Range = 9
            light.Shadows = false
            light.Parent = part
            slot.light = light
        end
        slot.light.Color = spec.lightColor
        slot.light.Enabled = true
    end
    slot.fromCFrame = spec.origin
    slot.toCFrame = spec.target or spec.origin
    slot.fromSize = spec.size
    slot.toSize = spec.endSize
    slot.fromAlpha = spec.alpha
    slot.linear = spec.linear == true
    -- Reset when a pooled shell is reused as a tracer/impact/muzzle flash.
    slot.arcHeight = spec.arcHeight or 0
    slot.spinAngle = spec.spinAngle or 0
    -- Reset impact movement when this Part is recycled for another effect.
    slot.gravityDrop = spec.gravityDrop or 0
    slot.flicker = spec.flicker or 0
    part.Parent = workspace
    return true
end

function WeaponVisuals:_updateTransientFx(now)
    local cap = TransientFxPool.cap(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    for index in pairs(self.activeTransientIndices) do
        local slot = self.transientParts[index]
        local part = slot and slot.part
        local t = slot and TransientFxPool.progress(slot, now, index <= cap)
        if t and part then
            -- Original standard TweenInfo uses Quad.Out; tracers use Linear.
            local blend = slot.linear and t or (1 - (1 - t) * (1 - t))
            local transform = slot.fromCFrame:Lerp(slot.toCFrame, blend)
            if slot.arcHeight > 0 then
                transform *= CFrame.new(0,
                    CartridgeEjection.arc(t, slot.arcHeight), 0)
            end
            if slot.gravityDrop > 0 then
                -- Analytic falling arc, no mass, collisions or Heartbeat tasks.
                transform += Vector3.new(0, -slot.gravityDrop * t * t, 0)
            end
            if slot.spinAngle ~= 0 then
                transform *= CFrame.Angles(0, slot.spinAngle * t, slot.spinAngle * t * 0.6)
            end
            part.CFrame = transform
            part.Size = slot.fromSize:Lerp(slot.toSize, blend)
            local baseAlpha = slot.fromAlpha + (1 - slot.fromAlpha) * blend
            part.Transparency = math.clamp(baseAlpha
                + slot.flicker * (1 - baseAlpha) * math.abs(math.sin(t * 24)),
                0, 1)
            if not part.Parent then part.Parent = workspace end
        else
            -- Expired or excluded by a reduced graphics cap: retire this
            -- active index immediately. The pooled Part remains reusable.
            self.activeTransientIndices[index] = nil
            if part then
                if part.Parent then part.Parent = nil end
                if slot.light then slot.light.Enabled = false end
            end
        end
    end
end

-- A short high-speed segment is more legible than a stationary full-range
-- laser bar, especially on lower-resolution Android screens. The actual
-- raycast/hit registration remains completely server-owned.
function WeaponVisuals:drawTracer(origin, direction, range, accentColor)
    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3"
        or direction.Magnitude < 0.01 then return end
    local profile = CombatVfxProfile.tracer(range)
    if not profile then return end
    local aim = direction.Unit
    local distance = math.clamp(range, 0, 1500)
    local half = profile.length * 0.5
    local startCenter = origin + aim * half
    local endCenter = origin + aim * math.max(half, distance - half)
    self:_spawnTransient({
        name = "IronYardFlightTracer",
        origin = CFrame.lookAt(startCenter, startCenter + aim),
        target = CFrame.lookAt(endCenter, endCenter + aim),
        size = Vector3.new(0.047, 0.047, profile.length),
        endSize = Vector3.new(0.025, 0.025, profile.length),
        alpha = 0.13,
        material = MATERIAL_NEON,
        color = accentColor or Color3.fromRGB(248, 225, 174),
        duration = profile.duration, priority = 2, linear = true,
    })
end

local function colorFromChannels(channels)
    return Color3.fromRGB(channels[1], channels[2], channels[3])
end

-- Only a bounded set of client-owned Parts exists for persistent marks.
-- Inactive entries are unparented rather than Destroyed, then immediately
-- reused on the next shot. The pool never participates in hit raycasts.
function WeaponVisuals:_trackImpactMark(now, duration, cap)
    local slot = ImpactMarkPool.claim(self.impactMarks, now, duration, cap)
    if not slot then return nil end
    if not slot.part then
        local mark = Instance.new("Part")
        mark.Name = "IronYardBulletMark"
        configurePart(mark)
        mark.Shape = Enum.PartType.Cylinder
        mark.Material = MATERIAL_SMOOTH
        slot.part = mark
    end
    return slot.part
end

function WeaponVisuals:_updateImpactMarks(now)
    local preset = Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset")
    local allowed = CombatVfxProfile.budget(
        preset, UserInputService.TouchEnabled, 0).marks
    for i, slot in ipairs(self.impactMarks) do
        local mark = slot.part
        if mark then
            local alpha = ImpactMarkPool.alpha(slot, now, i <= allowed)
            if alpha then
                if not mark.Parent then mark.Parent = workspace end
                mark.Transparency = alpha
            elseif mark.Parent then
                mark.Parent = nil
            end
        end
    end
end

-- A short 3D glint appears only on the shooter's client when the server
-- confirms REAL damage. This does not change hitboxes or expose positions
-- to other players, and uses no additional remotes or uploaded assets.
function WeaponVisuals:drawConfirmedHit(position, headshot, killed)
    if typeof(position) ~= "Vector3" then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local settings = CombatVfxProfile.hitFeedback(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled,
        (camera.CFrame.Position - position).Magnitude,
        headshot == true, killed == true)
    if not settings then return end
    local now = os.clock()
    local priority = CombatVfxProfile.hitPriority(headshot == true, killed == true)
    if not CombatVfxProfile.shouldDisplayHit(now,
        self.lastConfirmedHitFxAt or -math.huge,
        self.lastConfirmedHitFxPriority or 0, priority) then return end
    self.lastConfirmedHitFxAt = now
    self.lastConfirmedHitFxPriority = priority

    local color = killed and Color3.fromRGB(247, 189, 105)
        or (headshot and Color3.fromRGB(255, 229, 151)
            or Color3.fromRGB(204, 231, 218))
    local toward = camera.CFrame.Position - position
    if toward.Magnitude < 0.1 then return end
    local direction = toward.Unit
    local center = position + direction * 0.12
    -- Confirmed hits used to create up to four new Parts, Tweens and
    -- Debris timers on every accepted shot. The existing bounded local
    -- VFX pool already renders the same Quad.Out expansion/fade curve.
    -- Reserve its highest priority for real server-confirmed damage:
    -- cosmetic debris must never displace the actual hit confirmation.
    if settings.eliminationRing then
        self:_spawnTransient({
            name = "IronYardEliminationRing",
            origin = CFrame.lookAt(center, center + direction)
                * CFrame.Angles(0, math.pi * 0.5, 0),
            size = Vector3.new(0.018, settings.radius * 2, settings.radius * 2),
            endSize = Vector3.new(0.012, settings.radius * 4, settings.radius * 4),
            shape = Enum.PartType.Cylinder,
            material = MATERIAL_NEON,
            color = color,
            alpha = 0.38, duration = settings.duration,
            priority = 3,
        })
    end
    self:_spawnTransient({
        name = "IronYardConfirmedHit",
        origin = CFrame.new(center),
        size = Vector3.new(settings.radius, settings.radius, settings.radius),
        endSize = Vector3.new(settings.radius * 1.9,
            settings.radius * 1.9, settings.radius * 1.9),
        shape = Enum.PartType.Ball,
        material = MATERIAL_NEON,
        color = color,
        alpha = 0.08,
        duration = settings.duration,
        priority = 4,
    })

    for i = 1, settings.sparks do
        local angle = (i - 1) * math.pi / math.max(2, settings.sparks)
        self:_spawnTransient({
            name = "IronYardHitSpark",
            origin = CFrame.lookAt(center, center + direction)
                * CFrame.Angles(0, 0, angle),
            size = Vector3.new(0.025, 0.025, settings.radius * 2.4),
            endSize = Vector3.new(0.018, 0.018, settings.radius * 0.5),
            material = MATERIAL_NEON,
            color = color,
            alpha = 0.18,
            duration = settings.duration,
            priority = 3,
        })
    end
end

-- At most three accepted world pellet contacts. Unlike full impacts, these
-- glints never leave marks and allocate at most 1/2/3 local parts according
-- to ECO/BALANCED/QUALITY on the receiving device.
function WeaponVisuals:drawPelletImpacts(impacts)
    if typeof(impacts) ~= "table" then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local preset = Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset")
    local touch = UserInputService.TouchEnabled
    local drawn = 0
    for i = 1, math.min(#impacts, 3) do
        local info = impacts[i]
        if typeof(info) == "table" and typeof(info.position) == "Vector3"
            and typeof(info.normal) == "Vector3" and info.normal.Magnitude > 0.9 then
            local maxCount = CombatVfxProfile.pelletVisualCount(
                preset, touch, (camera.CFrame.Position - info.position).Magnitude)
            if drawn < maxCount then
                local profile = CombatVfxProfile.surface(info.material)
                if self:_spawnTransient({
                    name = "IronYardShotgunPellet",
                    origin = CFrame.new(info.position + info.normal.Unit * 0.09),
                    size = Vector3.new(0.12, 0.12, 0.12),
                    endSize = Vector3.new(0.34, 0.34, 0.34),
                    shape = Enum.PartType.Ball,
                    material = profile.sparks and MATERIAL_NEON or MATERIAL_SMOOTH,
                    color = rgb(profile.debris), alpha = 0.12,
                    duration = 0.18, priority = 2,
                }) then
                    drawn += 1
                end
            end
        end
    end
end

function WeaponVisuals:drawImpact(position, normal, materialName)
    if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3"
        or normal.Magnitude < 0.9 then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local preset = Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset")
    local touch = UserInputService.TouchEnabled
    local distance = (camera.CFrame.Position - position).Magnitude
    local budget = CombatVfxProfile.budget(preset, touch, distance)
    if not budget then return end
    local now = os.clock()
    if now - (self.lastImpactAt or -math.huge) < budget.cooldown then return end
    self.lastImpactAt = now

    local surface = CombatVfxProfile.surface(materialName)
    local motion = CombatVfxProfile.fragmentMotion(materialName)
    local n = normal.Unit
    local tint = colorFromChannels(surface.debris)
    local reference = math.abs(n.Y) > 0.88 and Vector3.xAxis or Vector3.yAxis
    local tangent = n:Cross(reference).Unit
    local bitangent = n:Cross(tangent).Unit

    -- Embedded circular mark on the actual contact plane (no TextureIds,
    -- collision, server instances or permanently growing decal inventory).
    local mark = self:_trackImpactMark(now, budget.markSeconds, budget.marks)
    if not mark then return end
    mark.Color = colorFromChannels(surface.mark)
    mark.Transparency = ImpactMarkPool.INITIAL_ALPHA
    local width = self.random:NextNumber(0.15, 0.26)
    mark.Size = Vector3.new(0.019, width, width * self.random:NextNumber(0.86, 1.14))
    mark.CFrame = CFrame.lookAt(position + n * 0.032, position + n)
        * CFrame.Angles(0, math.pi * 0.5, 0)
        * CFrame.Angles(self.random:NextNumber(0, math.pi * 2), 0, 0)
    mark.Parent = workspace

    -- Fleeting directional sparks for metal, glass glints, splinters for wood,
    -- and small dust/gravel for concrete and ground. All VFX are cosmetic.
    for _ = 1, budget.fragments do
        local angle = self.random:NextNumber(0, math.pi * 2)
        local ring = tangent * math.cos(angle) + bitangent * math.sin(angle)
        local travel = (n * self.random:NextNumber(0.28, 0.68) + ring).Unit
        local reach = self.random:NextNumber(0.28, surface.spread)
        local length = self.random:NextNumber(0.14,
            surface.sparks and 0.67 or (surface.glimmer and 0.37 or 0.30))
        local center = position + n * 0.07 + travel * (length * 0.35)
        local finish = center + travel * reach - Vector3.new(0, reach * 0.22, 0)
        self:_spawnTransient({
            name = surface.sparks and "IronYardRicochetSpark"
                or (surface.glimmer and "IronYardGlassGlint" or "IronYardSurfaceDebris"),
            origin = CFrame.lookAt(center, center + travel),
            target = CFrame.lookAt(finish, finish + travel),
            size = Vector3.new(surface.sparks and 0.034 or 0.065,
                surface.sparks and 0.034 or 0.045, length),
            endSize = Vector3.new(0.025, 0.025, 0.035),
            material = (surface.sparks or surface.glimmer)
                and MATERIAL_NEON or MATERIAL_SMOOTH,
            color = tint, alpha = surface.sparks and 0.02 or 0.16,
            duration = surface.sparks and 0.18 or 0.28, priority = 1,
            gravityDrop = motion.gravity * self.random:NextNumber(0.65, 1),
            spinAngle = motion.spin * self.random:NextNumber(-1, 1),
            flicker = motion.flicker,
        })
    end

    -- One short diffuse puff only at higher settings, never on ECO.
    if budget.fragments >= 2 and not surface.sparks and not surface.glimmer then
        local start = CFrame.new(position + n * 0.13)
        self:_spawnTransient({
            name = "IronYardImpactDust",
            origin = start, target = start + n * 0.22,
            size = Vector3.new(0.18, 0.18, 0.18),
            endSize = Vector3.new(0.75, 0.50, 0.75),
            shape = Enum.PartType.Ball, material = MATERIAL_SMOOTH,
            color = tint, alpha = 0.76, duration = 0.25, priority = 1,
        })
    end
end

-- Remote combatants use an oriented, compact muzzle burst. Only desktop
-- QUALITY enables a short-lived local light: never a networked light source.
function WeaponVisuals:drawMuzzleFlash(origin, accentColor, shotDirection, localShot)
    if typeof(origin) ~= "Vector3" then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local touch = UserInputService.TouchEnabled
    local budget = CombatVfxProfile.budget(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        touch, (camera.CFrame.Position - origin).Magnitude)
    if not budget then return end
    local direction = typeof(shotDirection) == "Vector3" and shotDirection.Magnitude > 0.01
        and shotDirection.Unit or camera.CFrame.LookVector
    local tint = accentColor or Color3.fromRGB(250, 204, 125)

    local localLightColor = nil
    if budget.muzzleLight then
        localLightColor = tint
    end
    self:_spawnTransient({
        name = "IronYardMuzzleCore", origin = CFrame.new(origin),
        size = Vector3.new(0.26, 0.26, 0.26),
        endSize = Vector3.new(0.05, 0.05, 0.05),
        shape = Enum.PartType.Ball, material = MATERIAL_NEON,
        color = tint, alpha = 0, duration = 0.09,
        priority = localShot and 4 or 3,
        lightColor = localLightColor,
    })

    for i = 1, budget.muzzleFins do
        self:_spawnTransient({
            name = "IronYardMuzzlePetal",
            origin = CFrame.lookAt(origin + direction * 0.24,
                origin + direction) * CFrame.Angles(0, 0, (i - 1) * math.pi * 0.5),
            size = Vector3.new(0.09, 0.36, 0.54),
            endSize = Vector3.new(0.035, 0.07, 0.17),
            material = MATERIAL_NEON, color = tint,
            alpha = 0.24, duration = 0.08,
            priority = localShot and 4 or 2,
        })
    end
end

-- First-person weapons use their actual viewmodel muzzle, not the character's
-- head. For scoped sniper shots the hidden weapon does not flash on the reticle.
function WeaponVisuals:drawLocalMuzzleFlash()
    if self.currentWeaponId == "Knife" or (self.currentWeaponId == "Sniper" and self.scoped) then
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then return end
    for _, entry in ipairs(self.parts) do
        if MUZZLE_NAMES[entry.part.Name] and entry.part.Parent then
            local direction = camera.CFrame.LookVector
            local advance = WeaponPbrFxSockets.muzzleAdvance(self.currentWeaponImported)
            self:drawMuzzleFlash(entry.part.Position + direction * advance, nil, direction, true)
            return
        end
    end
end

-- Playback from existing, approved Roblox sounds. The spatial audio
-- budget does NOT pretend these are final original licensed gun recordings.
function WeaponVisuals:_playSoundLayer(parent, layer, mix)
    if typeof(layer.soundId) ~= "string" or layer.soundId == "" then return end
    local sound = Instance.new("Sound")
    sound.Name = "FireLayer"
    sound.SoundId = layer.soundId
    sound.Volume = math.clamp((layer.volume or 0.5) * mix.volume, 0, 2)
    sound.PlaybackSpeed = math.clamp((layer.playbackSpeed or 1)
        + self.random:NextNumber(-0.035, 0.035), 0.25, 3)
    sound.RollOffMaxDistance = mix.maxDistance
    sound.RollOffMinDistance = 6
    sound.Parent = parent
    -- Standard Roblox equalization on remote/distant shots only.
    -- Avoid an additional engine effect on full-band local/near shots.
    if (mix.highGain or 0) < 0 or (mix.midGain or 0) < 0 then
        local eq = Instance.new("EqualizerSoundEffect")
        eq.Name = "IronYardDistanceFilter"
        eq.LowGain = mix.lowGain or 0
        eq.MidGain = mix.midGain or 0
        eq.HighGain = mix.highGain or 0
        eq.Parent = sound
    end
    sound:Play()
end

function WeaponVisuals:playFireSound(weaponId, origin, localShot)
    local config = self.WeaponConfig.get(weaponId)
    if not config or typeof(origin) ~= "Vector3" then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local ownShot = localShot == true
    if not ownShot then
        -- No heartbeat or extra task: clear completed remote emitters only
        -- when another spatialized shot is considered.
        for i = #self.remoteSoundEmitters, 1, -1 do
            if not self.remoteSoundEmitters[i].Parent then
                table.remove(self.remoteSoundEmitters, i)
            end
        end
    end
    local distance = ownShot and 0 or (camera.CFrame.Position - origin).Magnitude
    local mix = WeaponAudio.select(
        Players.LocalPlayer:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled, distance, ownShot, #self.remoteSoundEmitters, weaponId)
    if not mix then return end

    -- One cover ray ONLY for an admitted, distant remote sound. Ignore all
    -- fighters, the native camera and the viewmodel: their bodies do not
    -- acoustically block a shot. Collidable world cover does.
    if WeaponAudio.needsOcclusion(distance, ownShot) then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { camera }
        for _, participant in ipairs(Players:GetPlayers()) do
            if participant.Character then
                table.insert(ignore, participant.Character)
            end
        end
        local bots = workspace:FindFirstChild("NeonStrikeBots")
        if bots then table.insert(ignore, bots) end
        params.FilterDescendantsInstances = ignore
        params.RespectCanCollide = true
        params.IgnoreWater = true
        local cover = workspace:Raycast(
            camera.CFrame.Position, origin - camera.CFrame.Position, params)
        mix = WeaponAudio.occludedMix(mix, cover ~= nil)
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
        for index, layer in ipairs(config.soundLayers) do
            if index > mix.layers then break end
            self:_playSoundLayer(emitter, layer, mix)
        end
    elseif config.fireSoundId then
        self:_playSoundLayer(emitter, {
            soundId = config.fireSoundId,
            volume = config.fireVolume,
            playbackSpeed = config.firePlaybackSpeed,
        }, mix)
    end

    if not ownShot then
        table.insert(self.remoteSoundEmitters, emitter)
    end
    Debris:AddItem(emitter, mix.lifetime)
end

return WeaponVisuals
