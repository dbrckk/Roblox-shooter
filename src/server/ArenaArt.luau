-- IRON YARD / sunlit freight terminal environment art.
-- Core collision geometry is owned by MapService. These details cannot block
-- raycasts, movement, or PathfindingService and are locally culled on mobile.
local Lighting = game:GetService("Lighting")
local ArenaArt = {}
local COLOR = {
    wall = Color3.fromRGB(136, 135, 125),
    steel = Color3.fromRGB(83, 96, 100),
    slate = Color3.fromRGB(62, 73, 76),
    sand = Color3.fromRGB(209, 197, 170),
    rust = Color3.fromRGB(164, 102, 72),
    orange = Color3.fromRGB(225, 168, 65),
    olive = Color3.fromRGB(108, 121, 98),
    ink = Color3.fromRGB(35, 42, 44),
    paper = Color3.fromRGB(245, 236, 217),
}

local function prop(parent, name, size, cf, color, material, tier)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = tier == "Core"
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cf
    p.Color = color or COLOR.steel
    p.Material = material or Enum.Material.Metal
    p:SetAttribute("NeonArtTier", tier or "Detail")
    p.Parent = parent
    return p
end

local function span(parent, name, a, b, thickness, color, tier)
    local segment = b - a
    return prop(parent, name, Vector3.new(thickness, thickness, segment.Magnitude),
        CFrame.lookAt((a + b) * 0.5, b), color, Enum.Material.Metal, tier)
end

local function poster(parent, name, position, facing, message, color)
    local board = prop(parent, name, Vector3.new(16, 5.2, 0.25),
        CFrame.lookAt(position, position + facing), COLOR.ink, Enum.Material.Metal, "Core")
    local surface = Instance.new("SurfaceGui")
    surface.Name = "FreightSign"
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(800, 260)
    surface.LightInfluence = 0.2
    surface.Parent = board

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = COLOR.paper
    frame.BorderSizePixel = 0
    frame.Parent = surface
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 9
    stroke.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, -30)
    title.Position = UDim2.fromOffset(20, 15)
    title.BackgroundTransparency = 1
    title.TextColor3 = COLOR.ink
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextWrapped = true
    title.Text = message
    title.Parent = frame
end

local function cornerCranes(parent)
    -- Silhouettes above the battle space: no added collision or cover.
    for i, v in ipairs({
        Vector3.new(-146, 0, -145), Vector3.new(146, 0, -145),
        Vector3.new(-146, 0, 145), Vector3.new(146, 0, 145),
    }) do
        local hue = i % 2 == 0 and COLOR.orange or COLOR.steel
        local y = 27
        prop(parent, "GANTRY / tower " .. i, Vector3.new(4.5, 54, 4.5),
            CFrame.new(v.X, y, v.Z), hue, Enum.Material.Metal, "Core")
        prop(parent, "GANTRY / safety base " .. i, Vector3.new(8.5, 2.4, 8.5),
            CFrame.new(v.X, 1.2, v.Z), COLOR.slate, Enum.Material.Metal, "Core")
        span(parent, "GANTRY / crossbeam " .. i,
            Vector3.new(v.X - 16, 54, v.Z),
            Vector3.new(v.X + 17, 54, v.Z), 2.4, hue, "Core")
        span(parent, "GANTRY / diagonal " .. i,
            Vector3.new(v.X, 38, v.Z),
            Vector3.new(v.X + (i % 2 == 0 and -15 or 15), 54, v.Z), 0.85,
            COLOR.sand, "Detail")
        prop(parent, "GANTRY / machinery pod " .. i, Vector3.new(8, 5, 7),
            CFrame.new(v.X, 57, v.Z), COLOR.slate, Enum.Material.Metal, "Core")
    end
end

-- Container detail is purely visual: the eight existing large box colliders in
-- MapService remain the only bullet / navigation geometry. Decorative layers
-- are thin, non-queryable and mobile-culled by their Detail tier.
local function freightSerial(parent, plate, id)
    local face = Instance.new("SurfaceGui")
    face.Name = "FreightSerial"
    face.Face = Enum.NormalId.Front
    face.CanvasSize = Vector2.new(420, 112)
    face.LightInfluence = 0.35
    face.Parent = plate

    local label = Instance.new("TextLabel")
    label.Name = "FreightIdentification"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = id
    label.TextColor3 = COLOR.ink
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = face
end

local function containerDetails(parent)
    for row = -1, 1 do
        for column = -1, 1 do
            if row ~= 0 or column ~= 0 then
                local x, z = column * 100, row * 103
                local id = string.format("%d:%d", row, column)
                local h = 15 + ((row + column + 6) % 3) * 6
                local mid = h / 2
                local trim = (row + column) % 2 == 0 and COLOR.sand or COLOR.slate
                local serial = string.format("IY-%02d%02d   24G1", row + 2, column + 2)

                -- Long corrugations make both side faces read like stamped
                -- freight steel instead of an untextured cuboid.
                for _, side in ipairs({ -1, 1 }) do
                    for rib = -4, 4 do
                        prop(parent, "FREIGHT / side flute " .. id .. ":" .. side .. ":" .. rib,
                            Vector3.new(0.18, h - 1.0, 0.38),
                            CFrame.new(x + side * 12.09, mid, z + rib * 2.2),
                            COLOR.steel, Enum.Material.Metal, "Detail")
                    end
                    -- Top and bottom longitudinal corner extrusions.
                    for _, level in ipairs({ 0.52, h - 0.52 }) do
                        prop(parent, "FREIGHT / side perimeter " .. id .. ":" .. side .. ":" .. level,
                            Vector3.new(0.25, 0.28, 21.5),
                            CFrame.new(x + side * 12.08, level, z),
                            trim, Enum.Material.Metal, "Core")
                    end
                end

                -- End doors: split vertical seams, locking rods and hinges.
                -- All metal trim remains inside 0.36 studs of the box.
                for _, face in ipairs({ -1, 1 }) do
                    local endZ = z + face * 11.16
                    for rib = -2, 2 do
                        prop(parent, "FREIGHT / end flute " .. id .. ":" .. face .. ":" .. rib,
                            Vector3.new(0.27, h - 1, 0.18),
                            CFrame.new(x + rib * 4.2, mid, endZ),
                            COLOR.steel, Enum.Material.Metal, "Detail")
                    end
                    prop(parent, "FREIGHT / door seam " .. id .. ":" .. face,
                        Vector3.new(0.14, h - 0.8, 0.20),
                        CFrame.new(x, mid, endZ + face * 0.07),
                        COLOR.ink, Enum.Material.Metal, "Core")
                    for _, side in ipairs({ -1, 1 }) do
                        prop(parent, "FREIGHT / locking rod " .. id .. ":" .. face .. ":" .. side,
                            Vector3.new(0.20, h - 1.2, 0.22),
                            CFrame.new(x + side * 3.1, mid, endZ + face * 0.12),
                            trim, Enum.Material.Metal, "Core")
                        for _, hingeHeight in ipairs({ 2.0, h - 2.0 }) do
                            prop(parent, "FREIGHT / hinge " .. id .. ":" .. face .. ":" .. side .. ":" .. hingeHeight,
                                Vector3.new(0.73, 0.42, 0.29),
                                CFrame.new(x + side * 11.15, hingeHeight, endZ + face * 0.13),
                                COLOR.ink, Enum.Material.Metal, "Detail")
                        end
                    end
                    for _, level in ipairs({ 0.45, h - 0.45 }) do
                        prop(parent, "FREIGHT / end perimeter " .. id .. ":" .. face .. ":" .. level,
                            Vector3.new(23.4, 0.27, 0.23),
                            CFrame.new(x, level, endZ + face * 0.12),
                            trim, Enum.Material.Metal, "Core")
                    end
                end

                -- Distinct readable identification on the front face.
                local tag = prop(parent, "FREIGHT / serial plate " .. id,
                    Vector3.new(6.3, 1.45, 0.20),
                    CFrame.new(x + 3.8, h - 2.15, z - 11.31),
                    COLOR.sand, Enum.Material.SmoothPlastic, "Core")
                freightSerial(parent, tag, serial)
                prop(parent, "FREIGHT / safety marking " .. id,
                    Vector3.new(2.15, 0.22, 0.19),
                    CFrame.new(x - 8.6, 2.1, z - 11.30),
                    COLOR.orange, Enum.Material.SmoothPlastic, "Detail")
            end
        end
    end
end
local function laneMarkings(parent)
    for _, side in ipairs({ -1, 1 }) do
        for index = -3, 3 do
            -- Broken yellow loading-lane lines, visible at ground level.
            prop(parent, "ROAD / dashed marking " .. side .. ":" .. index,
                Vector3.new(0.35, 0.045, 13),
                CFrame.new(side * 66, 0.047, index * 36),
                COLOR.orange, Enum.Material.SmoothPlastic, "Detail")
            prop(parent, "ROAD / loading bay marking " .. side .. ":" .. index,
                Vector3.new(11, 0.045, 0.30),
                CFrame.new(index * 37, 0.047, side * 141),
                COLOR.paper, Enum.Material.SmoothPlastic, "Detail")
        end
    end

    for i = 1, 10 do
        local x = -125 + (i - 1) * 27
        prop(parent, "WAREHOUSE / hazard stripe " .. i,
            Vector3.new(1.1, 0.045, 3.2),
            CFrame.new(x, 0.045, 66) * CFrame.Angles(0, math.rad(35), 0),
            i % 2 == 0 and COLOR.orange or COLOR.ink,
            Enum.Material.SmoothPlastic, "Detail")
    end
end

local function silhouettes(parent)
    -- Sparse static off-map buildings create depth without importing textures.
    -- These parts stay outside the 356x356 playfield.
    for index = 1, 20 do
        local direction = index % 2 == 0 and 1 or -1
        local x = direction * (209 + index % 3 * 20)
        local z = ((index * 43) % 370) - 185
        local height = 24 + (index * 17) % 43
        prop(parent, "SKYLINE / warehouse " .. index,
            Vector3.new(32, height, 38),
            CFrame.new(x, height / 2 - 0.2, z),
            index % 3 == 0 and COLOR.sand or COLOR.wall, Enum.Material.Concrete, "Detail")
    end
end

-- Secondary architecture: real industrial scale without changing any map collider.
-- Every component is non-colliding, non-queryable and locally LOD-culled.
-- Platforms, freight containers and warehouse gameplay volumes are unchanged.
local function warehouseArchitecture(parent)
    local roofHeight = 21.5
    -- Open roof trusses are readable from ground level and make the central
    -- processing bay feel like a large industrial building instead of a maze.
    for bay = 0, 4 do
        local z = -22 + bay * 20
        for _, side in ipairs({ -1, 1 }) do
            prop(parent, "WAREHOUSE / roof column " .. bay .. ":" .. side,
                Vector3.new(0.95, 6.2, 0.95),
                CFrame.new(side * 29, 19.1, z), COLOR.slate, Enum.Material.Metal, "Core")
            span(parent, "WAREHOUSE / diagonal brace " .. bay .. ":" .. side,
                Vector3.new(side * 29, 20.3, z),
                Vector3.new(side * 18, roofHeight + 1.2, z),
                0.34, COLOR.steel, "Detail")
        end
        span(parent, "WAREHOUSE / overhead truss " .. bay,
            Vector3.new(-30, roofHeight, z),
            Vector3.new(30, roofHeight, z), 0.72, COLOR.steel, "Core")
        prop(parent, "WAREHOUSE / truss center splice " .. bay,
            Vector3.new(1.3, 1.0, 0.85), CFrame.new(0, roofHeight, z),
            COLOR.sand, Enum.Material.Metal, "Detail")
    end

    -- Longitudinal roof purlins keep an uninterrupted open-floor shooting
    -- lane. They cast only strategic core shadows, never physical collision.
    for _, x in ipairs({ -28, -15, 0, 15, 28 }) do
        prop(parent, "WAREHOUSE / roof purlin " .. x,
            Vector3.new(0.43, 0.42, 86), CFrame.new(x, roofHeight + 1.0, 18),
            COLOR.slate, Enum.Material.Metal, "Detail")
    end

    -- Roll-up doors are thin facades over an ALREADY-solid warehouse bulkhead
    -- at z=61. No fake traversable entrance and no misleading hit geometry.
    for index, x in ipairs({ -20, 0, 20 }) do
        local faceZ = 62.68
        prop(parent, "WAREHOUSE / shutter " .. index,
            Vector3.new(14.2, 10.0, 0.14), CFrame.new(x, 6, faceZ),
            COLOR.steel, Enum.Material.Metal, "Core")
        for row = 0, 5 do
            prop(parent, "WAREHOUSE / shutter slat " .. index .. ":" .. row,
                Vector3.new(13.5, 0.09, 0.08),
                CFrame.new(x, 1.5 + row * 1.65, faceZ + 0.10),
                row % 2 == 0 and COLOR.slate or COLOR.wall,
                Enum.Material.Metal, "Detail")
        end
        for _, side in ipairs({ -1, 1 }) do
            prop(parent, "WAREHOUSE / shutter track " .. index .. ":" .. side,
                Vector3.new(0.33, 11.1, 0.29),
                CFrame.new(x + side * 7.35, 6, faceZ + 0.09),
                COLOR.ink, Enum.Material.Metal, "Core")
        end
        prop(parent, "WAREHOUSE / dock marker " .. index,
            Vector3.new(3.0, 1.2, 0.12),
            CFrame.new(x, 13.8, faceZ), COLOR.orange,
            Enum.Material.SmoothPlastic, "Detail")
    end

    for _, side in ipairs({ -1, 1 }) do
        -- The outer side-wall face is at x= +/-31.5.
        local x = side * 31.72
        for index = 0, 5 do
            local z = -23 + index * 15
            prop(parent, "WAREHOUSE / vertical conduit " .. side .. ":" .. index,
                Vector3.new(0.23, 11.0, 0.23), CFrame.new(x, 8.7, z),
                COLOR.ink, Enum.Material.Metal, "Detail")
            prop(parent, "WAREHOUSE / junction box " .. side .. ":" .. index,
                Vector3.new(0.58, 1.15, 0.76), CFrame.new(x + side * 0.19, 12.6, z),
                COLOR.sand, Enum.Material.Metal, "Detail")
        end
    end
end

local function catwalkSafety(parent)
    for _, side in ipairs({ -1, 1 }) do
        local cx = side * 118
        -- MapService's elevated catwalk occupies x=86..150 and z=-26..26,
        -- its top surface is y=13; all these pieces are visual only.
        for _, z in ipairs({ -25.4, 25.4 }) do
            for index = 0, 6 do
                local x = cx - 30 + index * 10
                prop(parent, "CATWALK / rail post " .. side .. ":" .. z .. ":" .. index,
                    Vector3.new(0.35, 4.1, 0.35), CFrame.new(x, 15.0, z),
                    COLOR.slate, Enum.Material.Metal, "Detail")
            end
            prop(parent, "CATWALK / safety rail " .. side .. ":" .. z,
                Vector3.new(61.5, 0.33, 0.32), CFrame.new(cx, 17.0, z),
                COLOR.orange, Enum.Material.Metal, "Detail")
            prop(parent, "CATWALK / kick plate " .. side .. ":" .. z,
                Vector3.new(61.5, 0.55, 0.17), CFrame.new(cx, 13.3, z),
                COLOR.ink, Enum.Material.Metal, "Detail")
        end
        -- Deck drainage channels add large-scale texture to the platform
        -- without the expense of full PBR maps before Studio asset import.
        for index = 1, 5 do
            local x = cx - 30 + index * 10
            prop(parent, "CATWALK / drain grate " .. side .. ":" .. index,
                Vector3.new(0.19, 0.05, 42), CFrame.new(x, 13.045, 0),
                COLOR.ink, Enum.Material.Metal, "Detail")
        end
        for _, z in ipairs({ -18, 18 }) do
            prop(parent, "CATWALK / warning panel " .. side .. ":" .. z,
                Vector3.new(10, 0.052, 1.0), CFrame.new(cx, 13.055, z),
                COLOR.orange, Enum.Material.SmoothPlastic, "Detail")
        end
    end
end

local function gantryRigging(parent)
    -- Suspended spreaders and cable runs above the combat area: architectural
    -- silhouettes, not physics ropes, and NEVER a hidden bullet blocker.
    for i, v in ipairs({
        Vector3.new(-146, 0, -145), Vector3.new(146, 0, -145),
        Vector3.new(-146, 0, 145), Vector3.new(146, 0, 145),
    }) do
        local trolleyX = v.X + (i % 2 == 0 and -8 or 8)
        prop(parent, "GANTRY / trolley carriage " .. i, Vector3.new(6, 1.2, 5.2),
            CFrame.new(trolleyX, 52.0, v.Z), COLOR.ink, Enum.Material.Metal, "Core")
        for _, dx in ipairs({ -2.1, 2.1 }) do
            for _, dz in ipairs({ -1.6, 1.6 }) do
                prop(parent, "GANTRY / winch cable " .. i .. ":" .. dx .. ":" .. dz,
                    Vector3.new(0.10, 11.0, 0.10),
                    CFrame.new(trolleyX + dx, 45.5, v.Z + dz),
                    COLOR.slate, Enum.Material.Metal, "Detail")
            end
        end
        prop(parent, "GANTRY / container spreader " .. i,
            Vector3.new(12.6, 0.9, 4.8), CFrame.new(trolleyX, 39.8, v.Z),
            COLOR.orange, Enum.Material.Metal, "Core")
        for _, dx in ipairs({ -5.7, 5.7 }) do
            prop(parent, "GANTRY / spreader foot " .. i .. ":" .. dx,
                Vector3.new(0.7, 1.35, 4.5), CFrame.new(trolleyX + dx, 39.0, v.Z),
                COLOR.ink, Enum.Material.Metal, "Detail")
        end
    end
end

function ArenaArt.build(arena)
    -- Internal folder identifier retained for the existing client LOD script.
    local previous = arena:FindFirstChild("NeonStrikeDecor")
    if previous then previous:Destroy() end
    local decor = Instance.new("Folder")
    decor.Name = "NeonStrikeDecor"
    decor.Parent = arena

    -- Repeated perimeter bracing gives walls material scale rather than glowing grids.
    for _, side in ipairs({ -1, 1 }) do
        for i = -3, 3 do
            local n = i * 43
            prop(decor, "BOUNDARY / upright EW " .. side .. ":" .. i,
                Vector3.new(1.2, 25, 2.8), CFrame.new(side * 173.9, 12.5, n),
                COLOR.slate, Enum.Material.Metal, "Core")
            prop(decor, "BOUNDARY / upright NS " .. side .. ":" .. i,
                Vector3.new(2.8, 25, 1.2), CFrame.new(n, 12.5, side * 173.9),
                COLOR.slate, Enum.Material.Metal, "Core")
        end
        span(decor, "BOUNDARY / cable service " .. side,
            Vector3.new(side * 170, 29, -153), Vector3.new(side * 170, 29, 153),
            1.25, COLOR.steel, "Core")
    end

    laneMarkings(decor)
    containerDetails(decor)
    cornerCranes(decor)
    warehouseArchitecture(decor)
    catwalkSafety(decor)
    gantryRigging(decor)
    silhouettes(decor)

    poster(decor, "SIGN / west logistics", Vector3.new(-142, 17, 134),
        Vector3.new(0, 0, -1), "IRON YARD\nWEST FREIGHT", COLOR.olive)
    poster(decor, "SIGN / east logistics", Vector3.new(142, 17, 134),
        Vector3.new(0, 0, -1), "IRON YARD\nEAST FREIGHT", COLOR.rust)
    poster(decor, "SIGN / safety", Vector3.new(0, 15, -169),
        Vector3.new(0, 0, 1), "LOADING ZONE\nAUTHORIZED PERSONNEL", COLOR.orange)
end

local function effect(name, className)
    local previous = Lighting:FindFirstChild(name)
    if previous and not previous:IsA(className) then
        previous:Destroy()
        previous = nil
    end
    if not previous then
        previous = Instance.new(className)
        previous.Name = name
        previous.Parent = Lighting
    end
    return previous
end

function ArenaArt.applyLighting()
    local grade = effect("IronYardGrade", "ColorCorrectionEffect")
    grade.Brightness = 0.01
    grade.Contrast = 0.07
    grade.Saturation = -0.025
    grade.TintColor = Color3.fromRGB(255, 250, 241)
    grade.Enabled = true

    -- Remove the previous neon-era glow instead of stacking post-processing.
    for _, name in ipairs({ "NeonStrikeBloom", "NeonStrikeGrade" }) do
        local previous = Lighting:FindFirstChild(name)
        if previous then previous:Destroy() end
    end
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if bloom then bloom.Enabled = false end

    local atmosphere = Lighting:FindFirstChild("IronYardAtmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "IronYardAtmosphere"
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.13
    atmosphere.Haze = 0.45
    atmosphere.Glare = 0
    atmosphere.Color = Color3.fromRGB(219, 223, 215)
    atmosphere.Decay = Color3.fromRGB(182, 190, 196)
end

return ArenaArt
