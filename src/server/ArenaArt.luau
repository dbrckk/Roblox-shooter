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

local function containerDetails(parent)
    for row = -1, 1 do
        for column = -1, 1 do
            if row ~= 0 or column ~= 0 then
                local x, z = column * 100, row * 103
                local h = 15 + ((row + column + 6) % 3) * 6
                -- Container doors/ribs visually explain cover and add scale.
                local edge = h / 2
                for i = -2, 2 do
                    local localX = i * 4.2
                    for _, face in ipairs({ -1, 1 }) do
                        prop(parent, "FREIGHT / corrugation " .. row .. ":" .. column .. ":" .. i .. ":" .. face,
                            Vector3.new(0.28, h - 1, 0.28),
                            CFrame.new(x + localX, edge, z + face * 11.08),
                            COLOR.slate, Enum.Material.Metal, "Detail")
                    end
                end
                local plateColor = (column + row) % 2 == 0 and COLOR.paper or COLOR.orange
                prop(parent, "FREIGHT / serial plate " .. row .. ":" .. column,
                    Vector3.new(5, 1.3, 0.18),
                    CFrame.new(x, h - 2.3, z - 11.22),
                    plateColor, Enum.Material.SmoothPlastic, "Core")
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
