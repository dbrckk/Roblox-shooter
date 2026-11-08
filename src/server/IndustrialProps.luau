-- IRON YARD / in-world freight yard visual landmarks.
-- Decorative pieces are non-colliding and non-queryable. MapService owns
-- their coarse gameplay colliders so pathfinding and authoritative raycasts
-- are consistent regardless of graphics detail/LOD.
local PalletVisualPlan = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PalletVisualPlan"))
local IndustrialProps = {}

local C = {
    slate = Color3.fromRGB(74, 86, 88),
    charcoal = Color3.fromRGB(41, 45, 45),
    olive = Color3.fromRGB(120, 132, 99),
    safety = Color3.fromRGB(216, 159, 59),
    cream = Color3.fromRGB(221, 215, 194),
    rust = Color3.fromRGB(163, 105, 76),
    dark = Color3.fromRGB(59, 67, 65),
    glass = Color3.fromRGB(97, 124, 128),
}

local function prop(parent, name, size, cf, color, material, tier, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.Shape = shape or Enum.PartType.Block
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = tier == "Core"
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", tier or "Detail")
    p.Parent = parent
    return p
end

local function sticker(parent, part, words, primary)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "IndustrialInscription"
    gui.Face = Enum.NormalId.Front
    gui.CanvasSize = Vector2.new(390, 132)
    gui.LightInfluence = 0.1
    gui.Parent = part
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(1, 1)
    title.BackgroundTransparency = 1
    title.Text = words
    title.TextColor3 = primary
    title.TextSize = 50
    title.TextScaled = true
    title.Font = Enum.Font.GothamBlack
    title.Parent = gui
end

local function forklift(folder, label, x, z, yaw, coat)
    local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
    local function cube(name, size, offset, color, tier, material, shape)
        return prop(folder, "FORKLIFT / " .. label .. " / " .. name,
            size, cf * CFrame.new(offset), color, material, tier, shape)
    end
    cube("engine bonnet", Vector3.new(7.4, 2.0, 5.2), Vector3.new(0, 2.4, 2.4), coat, "Core")
    cube("engine grille", Vector3.new(5.4, 1.0, 0.15), Vector3.new(0, 2.2, 5.1), C.charcoal, "Detail")
    cube("driver seat", Vector3.new(3.1, 2.6, 2.1), Vector3.new(0, 3.6, -0.8), C.charcoal, "Core")
    cube("cab roof", Vector3.new(7.6, 0.45, 7.5), Vector3.new(0, 7.2, 0.2), coat, "Core")
    for _, side in ipairs({ -1, 1 }) do
        for _, front in ipairs({ -1, 1 }) do
            cube("wheel " .. side .. "." .. front,
                Vector3.new(0.85, 2.45, 2.45),
                Vector3.new(side * 4.22, 1.15, front * 3.05),
                C.charcoal, "Core", Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
            cube("wheel hub " .. side .. "." .. front,
                Vector3.new(0.94, 1.05, 1.05),
                Vector3.new(side * 4.69, 1.15, front * 3.05),
                C.slate, "Detail", Enum.Material.Metal, Enum.PartType.Cylinder)
        end
        cube("cab upright " .. side .. ".rear",
            Vector3.new(0.42, 5.0, 0.46), Vector3.new(side * 3.25, 4.8, 3.4), C.dark, "Core")
        cube("cab upright " .. side .. ".front",
            Vector3.new(0.42, 5.0, 0.46), Vector3.new(side * 3.25, 4.8, -2.9), C.dark, "Core")
        cube("mast " .. side, Vector3.new(0.62, 9.5, 0.74),
            Vector3.new(side * 2.05, 5.2, -5.0), C.charcoal, "Core")
        cube("fork rail " .. side, Vector3.new(0.56, 0.43, 6.2),
            Vector3.new(side * 1.5, 0.62, -6.7), C.slate, "Core")
        cube("chevron " .. side, Vector3.new(0.65, 0.35, 0.3),
            Vector3.new(side * 2.6, 6.8, -3.9), C.safety, "Detail")
    end
    cube("mast crossbar", Vector3.new(5.1, 0.43, 0.58),
        Vector3.new(0, 5.1, -5.0), C.charcoal, "Core")

    -- The forklift becomes a recognisable industrial machine, rather than
    -- just the previous boxes-and-wheels silhouette. These are all cosmetic
    -- Roblox-native 3D components, not unuploaded PBR MeshParts.
    for _, side in ipairs({ -1, 1 }) do
        -- Hydraulic lift cylinder with a narrower polished ram. Each side
        -- has a defined dark mount and a visible moving-stage housing.
        cube("hydraulic cylinder " .. side, Vector3.new(0.42, 5.9, 0.48),
            Vector3.new(side * 1.72, 4.3, -4.8),
            C.dark, "Core", Enum.Material.Metal)
        cube("hydraulic ram " .. side, Vector3.new(0.20, 3.3, 0.24),
            Vector3.new(side * 1.72, 7.05, -4.8),
            Color3.fromRGB(177, 183, 176), "Detail", Enum.Material.Metal)
        cube("chain rail " .. side, Vector3.new(0.22, 6.6, 0.18),
            Vector3.new(side * 2.33, 5.15, -5.13),
            C.charcoal, "Detail", Enum.Material.DiamondPlate)
        -- A tapered fork point is actual wedge geometry. Reuse the existing
        -- part conventions but never introduce a walkable or bullet collider.
        local wedge = Instance.new("WedgePart")
        wedge.Name = "FORKLIFT / " .. label .. " / fork tip " .. side
        wedge.Anchored = true
        wedge.CanCollide = false
        wedge.CanQuery = false
        wedge.CanTouch = false
        wedge.CastShadow = false
        wedge.Material = Enum.Material.Metal
        wedge.Color = C.slate
        wedge.Size = Vector3.new(0.56, 0.32, 1.25)
        wedge.CFrame = cf * CFrame.new(side * 1.5, 0.62, -10.35)
        wedge:SetAttribute("NeonArtTier", "Detail")
        wedge.Parent = folder
        cube("fork heel " .. side, Vector3.new(0.70, 1.30, 0.53),
            Vector3.new(side * 1.5, 1.11, -4.92),
            C.dark, "Core", Enum.Material.Metal)
        cube("safety windshield frame " .. side, Vector3.new(0.22, 2.9, 0.22),
            Vector3.new(side * 2.6, 5.25, -2.92),
            C.charcoal, "Detail")
        cube("sideview mirror " .. side, Vector3.new(0.14, 0.64, 0.95),
            Vector3.new(side * 3.46, 5.82, -2.35),
            C.glass, "Detail", Enum.Material.Glass)
        -- Wheel lugs are large enough to read from nearby without the cost
        -- of complex per-frame rubber simulation.
        for _, front in ipairs({ -1, 1 }) do
            for groove = 1, 5 do
                local angle = groove * (math.pi * 2 / 5)
                cube("wheel lug " .. side .. ":" .. front .. ":" .. groove,
                    Vector3.new(0.11, 0.31, 0.35),
                    Vector3.new(side * 4.28, 1.15 + math.cos(angle) * 1.1,
                        front * 3.05 + math.sin(angle) * 1.1),
                    C.dark, "Detail", Enum.Material.SmoothPlastic)
            end
        end
    end

    -- Cab controls and recognisable mechanical details.
    cube("rear counterweight", Vector3.new(6.0, 2.7, 0.68),
        Vector3.new(0, 2.3, 5.5), C.charcoal, "Core")
    cube("engine vent upper", Vector3.new(5.1, 0.11, 2.8),
        Vector3.new(0, 3.52, 2.9), C.dark, "Detail")
    cube("exhaust chimney", Vector3.new(0.29, 2.1, 0.29),
        Vector3.new(2.8, 4.4, 3.9), C.charcoal, "Detail",
        Enum.Material.Metal, Enum.PartType.Cylinder)
    cube("cab steering column", Vector3.new(0.17, 1.7, 0.19),
        Vector3.new(0.9, 4.3, -1.8), C.charcoal, "Detail")
    cube("cab steering wheel", Vector3.new(0.17, 1.05, 1.05),
        Vector3.new(0.9, 5.18, -1.8), C.slate, "Detail",
        Enum.Material.Metal, Enum.PartType.Cylinder)
    for index = 1, 3 do
        cube("hood grille slat " .. index, Vector3.new(4.9, 0.1, 0.18),
            Vector3.new(0, 2.15 + index * 0.27, 5.22),
            C.slate, "Detail")
    end
    -- Amber and red rear service lamps, with no real PointLight allocation.
    for _, side in ipairs({ -1, 1 }) do
        cube("rear signal " .. side, Vector3.new(0.76, 0.34, 0.11),
            Vector3.new(side * 2.55, 3.48, 5.93),
            side == 1 and C.safety or C.rust, "Detail", Enum.Material.Glass)
    end
    cube("amber warning beacon", Vector3.new(0.65, 0.45, 0.65),
        Vector3.new(-2.3, 7.6, 2.4), C.safety, "Detail", Enum.Material.Glass)
    local serial = cube("fleet insignia", Vector3.new(3.4, 1.2, 0.1),
        Vector3.new(0, 2.7, 5.13), C.cream, "Detail", Enum.Material.SmoothPlastic)
    sticker(folder, serial, "FY-" .. label, C.charcoal)
end

-- Three visible cargo families, applied only to the five authoritative
-- 9x3.7x9 pallet colliders. Styling follows the real collider CFrame.
local function palletStacks(folder, collider, plan)
    local id = plan.label
    local center = collider.CFrame * CFrame.new(0, -collider.Size.Y * 0.5, 0)
    local function item(name, size, pos, color, mat, tier, transparency)
        local p = prop(folder, "PALLET / " .. id .. " / " .. name,
            size, center * CFrame.new(pos), color, mat, tier)
        if transparency then p.Transparency = transparency end
        return p
    end

    local coat = plan.style == "TIMBER_CRATE" and C.rust
        or (plan.style == "WRAPPED_FREIGHT" and C.cream or C.olive)
    local parcelMaterial = plan.style == "TIMBER_CRATE" and Enum.Material.WoodPlanks
        or (plan.style == "WRAPPED_FREIGHT" and Enum.Material.SmoothPlastic
            or Enum.Material.Metal)

    for _, side in ipairs({ -1, 1 }) do
        item("wood runners " .. side, Vector3.new(8.9, 0.25, 1.0),
            Vector3.new(0, 0.22, side * 3.63),
            C.rust, Enum.Material.WoodPlanks, "Detail")
    end
    item("lower pallet", Vector3.new(8.85, 0.28, 8.9),
        Vector3.new(0, 0.46, 0),
        C.rust, Enum.Material.WoodPlanks, "Core")
    for row = 1, 2 do
        for column = 1, 2 do
            item("parcel " .. row .. "." .. column,
                Vector3.new(4.3, 1.32, 4.3),
                Vector3.new(column == 1 and -2.2 or 2.2,
                    1.32 + (row - 1) * 1.44,
                    row == 1 and -2.2 or 2.2),
                coat, parcelMaterial, "Core")
        end
    end

    if plan.style == "TIMBER_CRATE" then
        -- Solid export crates: timber corner bracing and crossed side
        -- frames, not a stack of unrelated generic boxes.
        for _, side in ipairs({ -1, 1 }) do
            for _, face in ipairs({ -1, 1 }) do
                item("timber corner " .. side .. ":" .. face,
                    Vector3.new(0.30, 3.1, 0.30),
                    Vector3.new(side * 4.12, 2.06, face * 4.12),
                    C.dark, Enum.Material.WoodPlanks, "Core")
            end
        end
        local function diagonal(a, b, side, index)
            local delta = b - a
            prop(folder, "PALLET / " .. id .. " / timber diagonal " .. side .. ":" .. index,
                Vector3.new(0.24, 0.16, delta.Magnitude),
                center * CFrame.lookAt((a + b) * 0.5, b),
                C.cream, Enum.Material.WoodPlanks, "Detail")
        end
        for _, face in ipairs({ -1, 1 }) do
            diagonal(Vector3.new(-3.8, 0.85, face * 4.23),
                Vector3.new(3.8, 3.22, face * 4.23), face, 1)
            diagonal(Vector3.new(3.8, 0.85, face * 4.23),
                Vector3.new(-3.8, 3.22, face * 4.23), face, 2)
        end
    elseif plan.style == "WRAPPED_FREIGHT" then
        -- Tight translucent shrink-wrap around a real group of parcels.
        -- Very light shading; no fog wall or misleading solid shape.
        for _, side in ipairs({ -1, 1 }) do
            item("shrinkwrap side " .. side, Vector3.new(0.07, 2.89, 8.35),
                Vector3.new(side * 4.34, 2.06, 0),
                C.cream, Enum.Material.SmoothPlastic, "Detail", 0.70)
            item("shrinkwrap end " .. side, Vector3.new(8.35, 2.89, 0.07),
                Vector3.new(0, 2.06, side * 4.34),
                C.cream, Enum.Material.SmoothPlastic, "Detail", 0.70)
            item("cargo strap " .. side, Vector3.new(0.20, 3.11, 0.15),
                Vector3.new(side * 2.00, 2.02, -4.39),
                C.dark, Enum.Material.SmoothPlastic, "Core")
        end
    else
        -- Steel cage: readable graphite uprights, crossbars and amber
        -- handling details; no new pathfinding, collision or bullet cover.
        for _, side in ipairs({ -1, 1 }) do
            for _, face in ipairs({ -1, 1 }) do
                item("cage upright " .. side .. ":" .. face,
                    Vector3.new(0.25, 3.12, 0.25),
                    Vector3.new(side * 4.23, 2.05, face * 4.23),
                    C.charcoal, Enum.Material.Metal, "Core")
            end
            item("cage upper rail " .. side,
                Vector3.new(8.46, 0.22, 0.20),
                Vector3.new(0, 3.37, side * 4.25),
                C.slate, Enum.Material.Metal, "Core")
            item("cage lower rail " .. side,
                Vector3.new(8.46, 0.18, 0.20),
                Vector3.new(0, 1.00, side * 4.25),
                C.dark, Enum.Material.Metal, "Detail")
            item("amber cargo stripe " .. side,
                Vector3.new(8.02, 0.30, 0.09),
                Vector3.new(0, 1.72, side * 4.35),
                C.safety, Enum.Material.SmoothPlastic, "Detail")
        end
    end

    -- Every unit gets a readable freight ID, on a facade of the actual
    -- collision volume; marker remains on ECO even if microdetail is culled.
    local plate = item("freight identity plate",
        Vector3.new(3.8, 0.82, 0.11),
        Vector3.new(0, 2.40, -4.39),
        C.cream, Enum.Material.Metal, "Core")
    local category = plan.style == "TIMBER_CRATE" and "EXPORT"
        or (plan.style == "WRAPPED_FREIGHT" and "SEALED" or "EQUIPMENT")
    sticker(folder, plate, id .. " / " .. category, C.charcoal)
end

function IndustrialProps.build(arena)
    local old = arena:FindFirstChild("FreightLandmarks")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "FreightLandmarks"
    folder.Parent = arena
    forklift(folder, "12", -72, -115, math.rad(10), C.safety)
    forklift(folder, "27", 72, 115, math.rad(180), C.olive)

    -- Read the actual collision volumes instead of duplicating five
    -- hard-coded world positions that can silently drift from MapService.
    local palletCount = 0
    for _, collider in ipairs(arena:GetChildren()) do
        if collider:IsA("BasePart") then
            local plan = PalletVisualPlan.forCollider(
                collider.Name, collider.Size.X, collider.Size.Y, collider.Size.Z)
            if plan then
                palletStacks(folder, collider, plan)
                palletCount += 1
            end
        end
    end
    if palletCount ~= 5 then
        warn("[IRON YARD] Freight facade count mismatch: " .. tostring(palletCount))
    end
end

return IndustrialProps
