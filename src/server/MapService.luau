-- IRON YARD: bright competitive freight-terminal arena, authored entirely in Luau.
-- Collision geometry and mantle/wallrun attributes are authoritative.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ArenaArt = require(script.Parent:WaitForChild("ArenaArt"))
local IndustrialProps = require(script.Parent:WaitForChild("IndustrialProps"))
local MapService = {}
local started = false

local P = {
    concrete = Color3.fromRGB(178, 174, 161),
    asphalt = Color3.fromRGB(106, 110, 108),
    pale = Color3.fromRGB(207, 201, 182),
    wall = Color3.fromRGB(154, 150, 136),
    olive = Color3.fromRGB(111, 124, 100),
    rust = Color3.fromRGB(165, 100, 70),
    blue = Color3.fromRGB(85, 124, 147),
    cover = Color3.fromRGB(99, 107, 105),
    yellow = Color3.fromRGB(221, 175, 75),
    dark = Color3.fromRGB(66, 73, 73),
}

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanTouch = false
    p.Size = size
    p.Position = position
    p.Color = color or P.concrete
    p.Material = material or Enum.Material.Concrete
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function marking(parent, name, size, position, color)
    local p = part(parent, name, size, position, color, Enum.Material.SmoothPlastic)
    p.CanCollide = false
    p.CanQuery = false
    p.CastShadow = false
    return p
end

local function climbWall(parent, name, size, position, color)
    local p = part(parent, name, size, position, color or P.wall, Enum.Material.Concrete)
    p:SetAttribute("WallRunnable", true)
    return p
end

local function container(parent, name, x, z, h, paint)
    local base = part(parent, "CONTAINER / " .. name,
        Vector3.new(24, h, 22), Vector3.new(x, h / 2, z), paint, Enum.Material.Metal)
    base:SetAttribute("MantleTarget", true)
    -- Visible raised metal lip: decorative and deliberately excluded from raycasts.
    marking(parent, "CONTAINER / top rim " .. name, Vector3.new(24.2, 0.18, 22.2),
        Vector3.new(x, h + 0.10, z), P.dark)
    return base
end

local function warehouse(parent)
    -- Three-path movement around a central processing bay.
    climbWall(parent, "WAREHOUSE / west wall", Vector3.new(3, 16, 72),
        Vector3.new(-30, 8, 11), P.wall)
    climbWall(parent, "WAREHOUSE / east wall", Vector3.new(3, 16, 72),
        Vector3.new(30, 8, 11), P.wall)
    climbWall(parent, "WAREHOUSE / north bulkhead", Vector3.new(64, 16, 3),
        Vector3.new(0, 8, 61), P.wall)

    -- Readable lower cover and mantle steps along the central approach.
    local low = part(parent, "VAULT / packing station", Vector3.new(14, 5, 9),
        Vector3.new(-10, 2.5, 82), P.olive, Enum.Material.Metal)
    low:SetAttribute("MantleTarget", true)
    local ledge = part(parent, "VAULT / raised loading deck", Vector3.new(17, 3, 12),
        Vector3.new(13, 7, 85), P.concrete, Enum.Material.Concrete)
    ledge:SetAttribute("MantleTarget", true)

    -- A pair of short combat covers, avoiding the spawn routes.
    for _, side in ipairs({ -1, 1 }) do
        part(parent, "WAREHOUSE / cover " .. side, Vector3.new(9, 4.3, 12),
            Vector3.new(side * 47, 2.15, -8), P.cover, Enum.Material.Metal)
    end
end

local function highground(parent)
    for _, side in ipairs({ -1, 1 }) do
        local platform = part(parent, "CATWALK / loading platform " .. side,
            Vector3.new(64, 3, 52), Vector3.new(side * 118, 11.5, 0), P.concrete)
        platform:SetAttribute("MantleTarget", true)
        for step = 1, 5 do
            part(parent, "CATWALK / access stair " .. side .. ":" .. step,
                Vector3.new(18, step * 2, 5),
                Vector3.new(side * 76, step, -30 + step * 5), P.cover, Enum.Material.Metal)
        end
        climbWall(parent, "CATWALK / side bulkhead " .. side,
            Vector3.new(2.5, 16, 64), Vector3.new(side * 148, 8, -60), P.wall)
        marking(parent, "CATWALK / caution rail " .. side,
            Vector3.new(61, 0.15, 0.5), Vector3.new(side * 118, 13.2, -26), P.yellow)
    end
end

local function buildArena(folder)
    part(folder, "TERMINAL / floor", Vector3.new(356, 2, 356),
        Vector3.new(0, -1, 0), P.asphalt, Enum.Material.Concrete)

    for _, side in ipairs({ -1, 1 }) do
        climbWall(folder, "BOUNDARY / east-west " .. side,
            Vector3.new(4, 38, 356), Vector3.new(side * 177, 19, 0), P.wall)
        climbWall(folder, "BOUNDARY / north-south " .. side,
            Vector3.new(356, 38, 4), Vector3.new(0, 19, side * 177), P.wall)
        -- Thin road-edge markings communicate boundaries without light pollution.
        marking(folder, "ROAD / longitudinal line " .. side,
            Vector3.new(0.32, 0.06, 320), Vector3.new(side * 154, 0.05, 0), P.pale)
        marking(folder, "ROAD / cross line " .. side,
            Vector3.new(320, 0.06, 0.32), Vector3.new(0, 0.05, side * 155), P.pale)
    end

    warehouse(folder)

    local paint = { P.blue, P.olive, P.rust, P.pale }
    for row = -1, 1 do
        for column = -1, 1 do
            if not (row == 0 and column == 0) then
                local x, z = column * 100, row * 103
                local height = 15 + ((row + column + 6) % 3) * 6
                container(folder, row .. ":" .. column, x, z, height,
                    paint[((row + 1) * 3 + (column + 1)) % #paint + 1])
                for n = -1, 1, 2 do
                    part(folder, "COVER / concrete barrier " .. row .. ":" .. column .. ":" .. n,
                        Vector3.new(13, 5.5, 6),
                        Vector3.new(x + n * 20, 2.75, z + 27), P.concrete)
                end
            end
        end
    end

    highground(folder)

    -- Coarse solid silhouettes for freight props, never visual-only ghosts.
    -- The IndustrialProps module draws non-queryable detail around these bodies.
    for _, forklift in ipairs({
        { x = -72, z = -115, paint = P.yellow },
        { x = 72, z = 115, paint = P.olive },
    }) do
        local collision = part(folder, "INDUSTRIAL / forklift body",
            Vector3.new(8, 3.1, 11), Vector3.new(forklift.x, 1.55, forklift.z),
            forklift.paint, Enum.Material.Metal)
        collision:SetAttribute("MantleTarget", true)
    end
    for i, point in ipairs({
        Vector2.new(0, -128),
        Vector2.new(-100, 52),
        Vector2.new(100, 52),
        Vector2.new(-100, -55),
        Vector2.new(100, -55),
    }) do
        local crate = part(folder, "INDUSTRIAL / pallet stack " .. i,
            Vector3.new(9, 3.7, 9), Vector3.new(point.X, 1.85, point.Y),
            P.rust, Enum.Material.WoodPlanks)
        crate:SetAttribute("MantleTarget", true)
    end

    -- Short obstacles break long sightlines while keeping side-to-side navigation open.
    for i = 1, 16 do
        local angle = i * math.pi / 8
        local radius = 57 + i % 3 * 10
        local x, z = math.cos(angle) * radius, math.sin(angle) * radius
        if z > -46 or math.abs(x) > 35 then
            local barrier = part(folder, "COVER / movable roadblock " .. i,
                Vector3.new(13, 5, 5), Vector3.new(x, 2.5, z), P.cover)
            barrier.CFrame = CFrame.new(x, 2.5, z) * CFrame.Angles(0, angle, 0)
        end
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "IRON YARD | Player Spawn"
    spawn.Anchored = true
    spawn.Size = Vector3.new(18, 1, 18)
    spawn.Position = Vector3.new(0, 0.5, 130)
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Duration = 0 -- server-side shield logic is used instead
    spawn.Material = Enum.Material.Concrete
    spawn.Transparency = 0
    spawn.Color = P.pale
    spawn.Parent = folder

    local briefing = part(folder, "BRIEFING / rules sign",
        Vector3.new(28, 13, 1), Vector3.new(0, 7, 160), P.dark, Enum.Material.Metal)
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.CanvasSize = Vector2.new(920, 340)
    signGui.Parent = briefing
    local signText = Instance.new("TextLabel")
    signText.BackgroundTransparency = 1
    signText.Size = UDim2.fromScale(1, 1)
    signText.Font = Enum.Font.GothamBold
    signText.TextScaled = true
    signText.TextWrapped = true
    signText.Text = "IRON YARD\nFREIGHT TERMINAL\nFIRST TO 15 ELIMINATIONS"
    signText.TextColor3 = P.pale
    signText.Parent = signGui
end

function MapService.start()
    if started then return end
    started = true
    -- Keep this internal folder identifier unchanged for compatibility with
    -- existing client LOD and other systems; it is not player-facing branding.
    local previous = Workspace:FindFirstChild("NeonStrikeArena")
    if previous then previous:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "NeonStrikeArena"
    folder.Parent = Workspace

    Lighting.ClockTime = 13.8
    Lighting.Brightness = 2.1
    Lighting.Ambient = Color3.fromRGB(133, 137, 128)
    Lighting.OutdoorAmbient = Color3.fromRGB(122, 133, 138)
    Lighting.FogColor = Color3.fromRGB(205, 207, 201)
    Lighting.FogStart = 300
    Lighting.FogEnd = 900
    Lighting.ShadowSoftness = 0.28
    Workspace:SetAttribute("ArenaTheme", "IRON_YARD_DAYLIGHT")
    buildArena(folder)
    ArenaArt.build(folder)
    IndustrialProps.build(folder)
    ArenaArt.applyLighting()
end

return MapService
