-- NEON STRIKE / VANGUARD modular combat armor.
-- Procedurally authored Roblox 3D parts: no external IDs, copyrighted meshes or textures.
-- Armor is welded to the R6 Humanoid skeleton and is non-colliding/non-queryable.
local ServerStorage = game:GetService("ServerStorage")
local BotVisuals = {}
local importedPalette = { "cyan", "amber", "violet", "emerald" }
local importedParts = { "torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "rifle" }

-- Studio-uploaded MeshParts are optional. This path activates only after a complete
-- asset pack is actually imported into ServerStorage/VanguardTemplates/<palette>.
-- No MeshId is fabricated and no script attempts to set protected MeshPart.MeshId.
local function tryImportedMeshKit(model, rig, index, accent)
    local root = ServerStorage:FindFirstChild("VanguardTemplates")
    local name = importedPalette[(index - 1) % #importedPalette + 1]
    local variant = root and root:FindFirstChild(name)
    if not variant then return nil end

    local source = {}
    for _, partName in ipairs(importedParts) do
        local mesh = variant:FindFirstChild(partName)
        if not mesh or not mesh:IsA("MeshPart") then return nil end
        source[partName] = mesh
    end

    local anchors = {
        torso = rig.torso,
        head = rig.head,
        left_arm = rig.leftArm,
        right_arm = rig.rightArm,
        left_leg = rig.leftLeg,
        right_leg = rig.rightLeg,
        rifle = rig.rightArm,
    }
    for _, partName in ipairs(importedParts) do
        local target = anchors[partName]
        local part = source[partName]:Clone()
        part.Name = "VANGUARD Mesh " .. partName
        part.Anchored = false
        part.Massless = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = true
        part:SetAttribute("NeonCosmeticTier", "Core")
        local offset = partName == "rifle" and CFrame.new(0, -0.39, -1.12) or CFrame.new()
        part.CFrame = target.CFrame * offset
        part.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Name = "ImportedVisualWeld"
        weld.Part0 = target
        weld.Part1 = part
        weld.Parent = part
    end

    -- Invisible base R6 parts remain the server's raycast hitboxes and skeleton.
    -- Do NOT switch CanQuery off: players must still hit these Humanoid parts.
    for _, bodyPart in ipairs({ rig.torso, rig.head, rig.leftArm, rig.rightArm, rig.leftLeg, rig.rightLeg }) do
        bodyPart.Transparency = 1
    end
    local muzzle = Instance.new("Attachment")
    muzzle.Name = "VX_Muzzle"
    muzzle.CFrame = CFrame.new(0.02, -0.46, -2.91)
    muzzle.Parent = rig.rightArm
    model:SetAttribute("NeonVisualSource", "PBR_MESH")
    return { muzzle = muzzle, accent = accent }
end

local STEEL = Color3.fromRGB(32, 42, 56)
local CARBON = Color3.fromRGB(18, 24, 34)
local GUNMETAL = Color3.fromRGB(65, 78, 92)
local PALE = Color3.fromRGB(166, 188, 198)

local palettes = {
    { accent = Color3.fromRGB(49, 218, 244), shade = Color3.fromRGB(16, 93, 137) },
    { accent = Color3.fromRGB(255, 155, 63), shade = Color3.fromRGB(129, 67, 28) },
    { accent = Color3.fromRGB(172, 125, 255), shade = Color3.fromRGB(78, 54, 139) },
    { accent = Color3.fromRGB(108, 244, 152), shade = Color3.fromRGB(43, 109, 84) },
}

local function armor(model, anchor, name, size, offset, color, material, tier, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.Shape = shape or Enum.PartType.Block
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CFrame = anchor.CFrame * offset
    p.Anchored = false
    p.Massless = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = tier == "Core"
    p:SetAttribute("NeonCosmeticTier", tier or "Detail")
    p.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Name = "CosmeticWeld"
    weld.Part0 = anchor
    weld.Part1 = p
    weld.Parent = p
    return p
end

local function plate(model, anchor, name, size, x, y, z, color, tier)
    return armor(model, anchor, name, size, CFrame.new(x, y, z), color, Enum.Material.Metal, tier)
end

function BotVisuals.decorate(model, rig, index)
    local colors = palettes[(index - 1) % #palettes + 1]
    local accent, shade = colors.accent, colors.shade
    local torso, head = rig.torso, rig.head
    local leftArm, rightArm = rig.leftArm, rig.rightArm
    local leftLeg, rightLeg = rig.leftLeg, rig.rightLeg

    model:SetAttribute("NeonAccentR", math.floor(accent.R * 255 + 0.5))
    model:SetAttribute("NeonAccentG", math.floor(accent.G * 255 + 0.5))
    model:SetAttribute("NeonAccentB", math.floor(accent.B * 255 + 0.5))

    torso.Color = CARBON
    head.Color = STEEL
    leftArm.Color = STEEL
    rightArm.Color = STEEL
    leftLeg.Color = CARBON
    rightLeg.Color = CARBON

    local imported = tryImportedMeshKit(model, rig, index, accent)
    if imported then return imported end
    model:SetAttribute("NeonVisualSource", "PROCEDURAL_PARTS")

    -- Segmented central chest plating and under-armor.
    plate(model, torso, "VANGUARD Chest Core", Vector3.new(1.85, 1.65, 0.24), 0, 0.12, -0.57, GUNMETAL, "Core")
    for _, side in ipairs({ -1, 1 }) do
        plate(model, torso, "Breastplate " .. side, Vector3.new(0.78, 0.70, 0.16), side * 0.47, 0.38, -0.75, STEEL, "Core")
        plate(model, torso, "Lower Torso " .. side, Vector3.new(0.72, 0.46, 0.17), side * 0.48, -0.41, -0.75, shade, "Detail")
        plate(model, torso, "Breastplate Light " .. side, Vector3.new(0.60, 0.055, 0.06), side * 0.47, 0.17, -0.845, accent, "Detail")
        plate(model, torso, "Harness " .. side, Vector3.new(0.20, 1.85, 0.21), side * 0.92, 0, -0.53, CARBON, "Core")
        plate(model, torso, "Ammo Pouch " .. side, Vector3.new(0.49, 0.44, 0.28), side * 0.65, -0.82, -0.57, GUNMETAL, "Detail")
    end
    plate(model, torso, "Reactor Center", Vector3.new(0.16, 0.52, 0.08), 0, 0.04, -0.91, accent, "Detail")
    plate(model, torso, "Belt Lock", Vector3.new(0.48, 0.25, 0.28), 0, -0.89, -0.59, PALE, "Core")
    plate(model, torso, "Backpack", Vector3.new(1.35, 1.65, 0.54), 0, -0.08, 0.86, STEEL, "Core")
    plate(model, torso, "Backpack Center", Vector3.new(0.44, 1.20, 0.12), 0, 0.02, 1.20, CARBON, "Detail")
    for _, side in ipairs({ -1, 1 }) do
        plate(model, torso, "Cooling Fin " .. side, Vector3.new(0.32, 0.98, 0.12), side * 0.42, -0.04, 1.19, accent, "Detail")
    end

    -- Helmet silhouette, forehead ridge and unlit glass visor; no extra hitbox.
    armor(model, head, "Helmet Dome", Vector3.new(2.03, 1.09, 1.08),
        CFrame.new(0, 0.11, 0), GUNMETAL, Enum.Material.Metal, "Core")
    plate(model, head, "Forehead Armor", Vector3.new(1.68, 0.24, 0.19), 0, 0.43, -0.62, STEEL, "Core")
    plate(model, head, "Visor Shadow", Vector3.new(1.66, 0.34, 0.14), 0, 0.1, -0.66, CARBON, "Core")
    plate(model, head, "Visor Band", Vector3.new(1.40, 0.14, 0.07), 0, 0.1, -0.76, accent, "Core")
    plate(model, head, "Mouth Guard", Vector3.new(1.1, 0.23, 0.12), 0, -0.36, -0.65, STEEL, "Core")
    for _, side in ipairs({ -1, 1 }) do
        plate(model, head, "Helmet Ear " .. side, Vector3.new(0.22, 0.62, 0.65), side * 1.02, 0, 0.09, shade, "Core")
        plate(model, head, "Helmet Antenna " .. side, Vector3.new(0.095, 0.46, 0.10), side * 0.81, 0.74, 0.17, accent, "Detail")
    end

    -- Layered articulated limb armor, attached to the original hitbox geometry.
    for _, limb in ipairs({ leftArm, rightArm }) do
        local name = limb.Name
        armor(model, limb, name .. " Shoulder Armor", Vector3.new(1.29, 0.54, 1.26),
            CFrame.new(0, 0.78, 0), shade, Enum.Material.Metal, "Core")
        plate(model, limb, name .. " Shoulder Bevel", Vector3.new(0.92, 0.12, 0.12),
            0, 0.81, -0.67, accent, "Detail")
        plate(model, limb, name .. " Forearm Guard", Vector3.new(0.99, 0.70, 0.21),
            0, -0.51, -0.52, GUNMETAL, "Core")
        plate(model, limb, name .. " Wrist Band", Vector3.new(1.07, 0.16, 1.04),
            0, -0.91, 0, CARBON, "Detail")
    end
    for _, leg in ipairs({ leftLeg, rightLeg }) do
        local name = leg.Name
        plate(model, leg, name .. " Thigh Plate", Vector3.new(0.88, 0.76, 0.20),
            0, 0.49, -0.51, STEEL, "Core")
        plate(model, leg, name .. " Knee Guard", Vector3.new(0.93, 0.36, 0.30),
            0, -0.11, -0.52, shade, "Core")
        plate(model, leg, name .. " Knee Signal", Vector3.new(0.56, 0.08, 0.07),
            0, -0.08, -0.69, accent, "Detail")
        plate(model, leg, name .. " Shin Armor", Vector3.new(0.81, 0.59, 0.20),
            0, -0.55, -0.51, GUNMETAL, "Core")
        plate(model, leg, name .. " Boot Toe", Vector3.new(0.99, 0.34, 1.38),
            0, -0.85, -0.21, CARBON, "Core")
    end

    -- Silhouette-matched sci-fi rifle with visible magazine, barrel and illuminated rails.
    -- All pieces weld to the right arm, so the prop follows combat poses for free.
    plate(model, rightArm, "VX Receiver", Vector3.new(0.34, 0.42, 1.30),
        0.02, -0.41, -1.13, STEEL, "Core")
    plate(model, rightArm, "VX Barrel", Vector3.new(0.18, 0.18, 1.14),
        0.02, -0.46, -2.17, GUNMETAL, "Core")
    plate(model, rightArm, "VX Stock", Vector3.new(0.43, 0.27, 0.62),
        0.02, -0.39, -0.46, CARBON, "Core")
    plate(model, rightArm, "VX Magazine", Vector3.new(0.22, 0.58, 0.34),
        0.02, -0.83, -1.03, CARBON, "Core")
    plate(model, rightArm, "VX Top Rail", Vector3.new(0.21, 0.12, 0.94),
        0.02, -0.16, -1.31, shade, "Detail")
    plate(model, rightArm, "VX Rail Signal", Vector3.new(0.12, 0.055, 0.69),
        0.02, -0.085, -1.49, accent, "Detail")
    armor(model, rightArm, "VX Muzzle Brake", Vector3.new(0.29, 0.29, 0.28),
        CFrame.new(0.02, -0.46, -2.72), STEEL, Enum.Material.Metal, "Core")

    local muzzle = Instance.new("Attachment")
    muzzle.Name = "VX_Muzzle"
    muzzle.CFrame = CFrame.new(0.02, -0.46, -2.91)
    muzzle.Parent = rightArm

    return {
        muzzle = muzzle,
        accent = accent,
    }
end

return BotVisuals
