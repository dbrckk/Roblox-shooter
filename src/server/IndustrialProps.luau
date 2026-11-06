-- IRON YARD / in-world freight yard visual landmarks.
-- Decorative pieces are non-colliding and non-queryable. MapService owns
-- their coarse gameplay colliders so pathfinding and authoritative raycasts
-- are consistent regardless of graphics detail/LOD.
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

local function palletStacks(folder, id, x, z, coat)
    local center = CFrame.new(x, 0, z)
    local function item(name, size, pos, color, mat, tier)
        return prop(folder, "PALLET / " .. id .. " / " .. name,
            size, center * CFrame.new(pos), color, mat, tier)
    end
    -- The collision crate in MapService is authoritative; decorative crate
    -- divisions below follow its general physical envelope.
    for _, side in ipairs({ -1, 1 }) do
        item("wood runners " .. side, Vector3.new(9.4, 0.27, 1.2),
            Vector3.new(0, 0.22, side * 3.65), C.rust, Enum.Material.WoodPlanks, "Detail")
    end
    item("lower pallet", Vector3.new(9.4, 0.28, 9.3),
        Vector3.new(0, 0.46, 0), C.rust, Enum.Material.WoodPlanks, "Core")
    for row = 1, 2 do
        for column = 1, 2 do
            item("parcel " .. row .. "." .. column, Vector3.new(4.3, 1.32, 4.3),
                Vector3.new((column == 1 and -2.2 or 2.2), 1.32 + (row - 1) * 1.44,
                    (row == 1 and -2.2 or 2.2)),
                coat, Enum.Material.WoodPlanks, "Core")
        end
    end
    for _, side in ipairs({ -1, 1 }) do
        item("cargo strap " .. side, Vector3.new(0.28, 3.15, 9.1),
            Vector3.new(side * 2.15, 2.1, 0), C.dark, Enum.Material.SmoothPlastic, "Detail")
    end
end

function IndustrialProps.build(arena)
    local old = arena:FindFirstChild("FreightLandmarks")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "FreightLandmarks"
    folder.Parent = arena
    forklift(folder, "12", -72, -115, math.rad(10), C.safety)
    forklift(folder, "27", 72, 115, math.rad(180), C.olive)

    for i, position in ipairs({
        Vector2.new(0, -128),
        Vector2.new(-100, 52),
        Vector2.new(100, 52),
        Vector2.new(-100, -55),
        Vector2.new(100, -55),
    }) do
        palletStacks(folder, tostring(i), position.X, position.Y, i % 2 == 0 and C.cream or C.rust)
    end
end

return IndustrialProps
