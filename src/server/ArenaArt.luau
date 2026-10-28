-- NEON STRIKE / INDUSTRIAL ARENA ART
-- Original, deterministic environment art. Strictly non-colliding so paths and gunplay
-- never depend on visual-only props. Asset IDs / marketplace downloads not required.
local Lighting = game:GetService("Lighting")
local ArenaArt = {}
local CYAN = Color3.fromRGB(42, 208, 244)
local GOLD = Color3.fromRGB(255, 158, 68)
local IRON = Color3.fromRGB(54, 67, 84)
local DARK = Color3.fromRGB(20, 29, 43)
local CLOUD = Color3.fromRGB(111, 129, 148)

local function prop(parent, name, size, cf, color, material, tier, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cf
    p.Shape = shape or Enum.PartType.Block
    p.Color = color or IRON
    p.Material = material or Enum.Material.Metal
    p:SetAttribute("NeonArtTier", tier or "Detail")
    p.Parent = parent
    return p
end

local function beam(parent, name, a, b, thickness, color, material, tier)
    local dir = b - a
    local size = Vector3.new(thickness, thickness, dir.Magnitude)
    local cf = CFrame.lookAt((a + b) * 0.5, b)
    return prop(parent, name, size, cf, color, material, tier)
end

local function display(parent, name, position, facing, message, tint)
    local anchor = prop(parent, name, Vector3.new(14, 5, 0.25),
        CFrame.lookAt(position, position + facing), DARK, Enum.Material.Metal, "Core")
    local surface = Instance.new("SurfaceGui")
    surface.Name = "ArenaBillboard"
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(640, 230)
    surface.LightInfluence = 0.2
    surface.Parent = anchor

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = DARK
    background.BackgroundTransparency = 0.03
    background.Parent = surface

    local stroke = Instance.new("UIStroke")
    stroke.Color = tint
    stroke.Thickness = 6
    stroke.Parent = background

    local text = Instance.new("TextLabel")
    text.Name = "Copy"
    text.Size = UDim2.new(1, -34, 1, -25)
    text.Position = UDim2.fromOffset(17, 12)
    text.BackgroundTransparency = 1
    text.Text = message
    text.TextColor3 = tint
    text.Font = Enum.Font.GothamBlack
    text.TextScaled = true
    text.TextWrapped = true
    text.Parent = background
end

local function addLane(parent, axis, at, n)
    for segment = -3, 3 do
        local cross = segment * 33
        if axis == "X" then
            prop(parent, "FLOOR / guide " .. n .. "." .. segment,
                Vector3.new(14, 0.04, 0.23), CFrame.new(cross, 0.04, at),
                CYAN, Enum.Material.Neon, "Detail")
        else
            prop(parent, "FLOOR / guide " .. n .. "." .. segment,
                Vector3.new(0.23, 0.04, 14), CFrame.new(at, 0.04, cross),
                GOLD, Enum.Material.Neon, "Detail")
        end
    end
end

function ArenaArt.build(arena)
    local previous = arena:FindFirstChild("NeonStrikeDecor")
    if previous then previous:Destroy() end
    local decor = Instance.new("Folder")
    decor.Name = "NeonStrikeDecor"
    decor.Parent = arena

    -- Industrial silhouette: inset wall ribs, edge signals, maintenance ducting.
    for _, side in ipairs({ -1, 1 }) do
        for i = -3, 3 do
            local coordinate = i * 43
            prop(decor, "WALL / rib EW " .. side .. ":" .. i,
                Vector3.new(1.25, 28, 2.5), CFrame.new(side * 173.7, 14, coordinate),
                IRON, Enum.Material.Metal, "Core")
            prop(decor, "WALL / signal EW " .. side .. ":" .. i,
                Vector3.new(0.3, 24, 0.22), CFrame.new(side * 172.9, 13, coordinate),
                i % 2 == 0 and CYAN or GOLD, Enum.Material.Neon, "Detail")
            prop(decor, "WALL / rib NS " .. side .. ":" .. i,
                Vector3.new(2.5, 28, 1.25), CFrame.new(coordinate, 14, side * 173.7),
                IRON, Enum.Material.Metal, "Core")
            prop(decor, "WALL / signal NS " .. side .. ":" .. i,
                Vector3.new(0.22, 24, 0.3), CFrame.new(coordinate, 13, side * 172.9),
                i % 2 == 0 and GOLD or CYAN, Enum.Material.Neon, "Detail")
        end
        -- Long overhead service pipe and parallel emissive conduits.
        beam(decor, "POWER / main conduit " .. side,
            Vector3.new(side * 167, 32, -154), Vector3.new(side * 167, 32, 154),
            1.6, CLOUD, Enum.Material.Metal, "Core")
        beam(decor, "POWER / energized core " .. side,
            Vector3.new(side * 167, 33, -155), Vector3.new(side * 167, 33, 155),
            0.27, side == 1 and CYAN or GOLD, Enum.Material.Neon, "Detail")
    end

    -- Stage floor is physically unchanged: thin, visual-only flight markings.
    addLane(decor, "X", -128, 1)
    addLane(decor, "X", 128, 2)
    addLane(decor, "Z", -128, 3)
    addLane(decor, "Z", 128, 4)

    -- Four landmark towers with neon crown, kinetic-looking rings, and safe silhouettes.
    for i, location in ipairs({
        Vector3.new(-148, 21, -145),
        Vector3.new(148, 21, -145),
        Vector3.new(-148, 21, 145),
        Vector3.new(148, 21, 145),
    }) do
        local c = i % 2 == 0 and GOLD or CYAN
        prop(decor, "REACTOR / body " .. i, Vector3.new(5, 22, 5),
            CFrame.new(location), IRON, Enum.Material.Metal, "Core")
        prop(decor, "REACTOR / glass " .. i, Vector3.new(2.2, 18, 2.2),
            CFrame.new(location), c, Enum.Material.Neon, "Detail")
        for ring = 1, 3 do
            prop(decor, "REACTOR / collar " .. i .. ":" .. ring,
                Vector3.new(7.3, 0.6, 7.3),
                CFrame.new(location + Vector3.new(0, (ring - 2) * 6, 0)),
                DARK, Enum.Material.Metal, "Core")
            prop(decor, "REACTOR / halo " .. i .. ":" .. ring,
                Vector3.new(7.4, 0.14, 7.4),
                CFrame.new(location + Vector3.new(0, (ring - 2) * 6 + 0.35, 0)),
                c, Enum.Material.Neon, "Detail")
        end
        local point = Instance.new("PointLight")
        point.Name = "ReactorGlow"
        point.Color = c
        point.Brightness = 0.85
        point.Range = 25
        point.Shadows = false
        point.Parent = decor:FindFirstChild("REACTOR / glass " .. i)
    end

    for _, side in ipairs({ -1, 1 }) do
        display(decor, "SCOREBOARD / " .. side,
            Vector3.new(side * 140, 16, side * 132),
            Vector3.new(0, 0, -side),
            "N E O N\nS T R I K E",
            side == -1 and CYAN or GOLD)
        for i = 1, 4 do
            local x = side * (74 + i * 17)
            local z = 150 - i * 18
            prop(decor, "SUPPORT / plating " .. side .. ":" .. i,
                Vector3.new(12, 0.07, 2.2), CFrame.new(x, 0.045, z),
                side == 1 and GOLD or CYAN, Enum.Material.Neon, "Detail")
        end
    end
end

local function replaceEffect(name, className)
    local effect = Lighting:FindFirstChild(name)
    if effect and not effect:IsA(className) then
        effect:Destroy()
        effect = nil
    end
    if not effect then
        effect = Instance.new(className)
        effect.Name = name
        effect.Parent = Lighting
    end
    return effect
end

function ArenaArt.applyLighting()
    local correction = replaceEffect("NeonStrikeGrade", "ColorCorrectionEffect")
    correction.Brightness = 0.01
    correction.Contrast = 0.13
    correction.Saturation = 0.07
    correction.TintColor = Color3.fromRGB(228, 237, 255)
    correction.Enabled = true

    local bloom = replaceEffect("NeonStrikeBloom", "BloomEffect")
    bloom.Intensity = 0.19
    bloom.Size = 17
    bloom.Threshold = 1.42
    bloom.Enabled = true
end

return ArenaArt
