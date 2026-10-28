-- NEON STRIKE: entirely original, procedural geometry (no third-party models).
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local MapService = {}
local started = false
local MAIN = Color3.fromRGB(32, 43, 59)
local MID = Color3.fromRGB(61, 76, 92)
local CYAN = Color3.fromRGB(41, 208, 242)
local AMBER = Color3.fromRGB(255, 139, 68)
local STEEL = Color3.fromRGB(90, 103, 118)

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Color = color or MAIN
    p.Material = material or Enum.Material.Metal
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function neon(parent, name, size, position, color)
    local p = part(parent, name, size, position, color or CYAN, Enum.Material.Neon)
    p.CanCollide = false
    p.CanQuery = false
    p.CastShadow = false
    return p
end

local function runnableWall(parent, name, size, position)
    local p = part(parent, name, size, position, MAIN)
    p:SetAttribute("WallRunnable", true)
    return p
end

local function buildArena(folder)
    part(folder, "CONCRETE | ground", Vector3.new(356, 2, 356),
        Vector3.new(0, -1, 0), Color3.fromRGB(35, 44, 58), Enum.Material.Concrete)

    for _, side in ipairs({-1, 1}) do
        runnableWall(folder, "PERIMETER | east-west | " .. side,
            Vector3.new(4, 42, 356), Vector3.new(side * 177, 21, 0))
        runnableWall(folder, "PERIMETER | north-south | " .. side,
            Vector3.new(356, 42, 4), Vector3.new(0, 21, side * 177))
        neon(folder, "PERIMETER | horizontal light | " .. side,
            Vector3.new(352, 0.3, 0.4), Vector3.new(0, 8, side * 174.8), CYAN)
    end

    -- Keep the center corridor open for the source framework's training dummies.
    runnableWall(folder, "WALL RUN | left",
        Vector3.new(2.6, 17, 72), Vector3.new(-30, 8.5, 11))
    runnableWall(folder, "WALL RUN | right",
        Vector3.new(2.6, 17, 72), Vector3.new(30, 8.5, 11))
    neon(folder, "WALL RUN | left guide", Vector3.new(0.3, 0.3, 65),
        Vector3.new(-28.55, 11, 11))
    neon(folder, "WALL RUN | right guide", Vector3.new(0.3, 0.3, 65),
        Vector3.new(28.55, 11, 11))
    runnableWall(folder, "WALL RUN | cross",
        Vector3.new(65, 16, 2), Vector3.new(0, 8, 61))

    local mantle = part(folder, "MANTLE | low", Vector3.new(14, 5, 9),
        Vector3.new(-10, 2.5, 82), MID)
    mantle:SetAttribute("MantleTarget", true)
    local ledge = part(folder, "MANTLE | platform", Vector3.new(17, 3, 12),
        Vector3.new(13, 7, 85), MID)
    ledge:SetAttribute("MantleTarget", true)

    for row = -1, 1 do
        for column = -1, 1 do
            if not (row == 0 and column == 0) then
                local x, z = column * 100, row * 103
                local height = 15 + ((row + column + 6) % 3) * 6
                local tower = part(folder, "CARGO | " .. row .. ":" .. column,
                    Vector3.new(24, height, 22), Vector3.new(x, height / 2, z), MID)
                tower:SetAttribute("MantleTarget", true)
                neon(folder, "CARGO | roof signal " .. row .. ":" .. column,
                    Vector3.new(24.3, 0.25, 22.3),
                    tower.Position + Vector3.new(0, tower.Size.Y / 2 + 0.13, 0),
                    (column == 0) and AMBER or CYAN)
                for n = -1, 1, 2 do
                    part(folder, "COVER | " .. row .. ":" .. column .. ":" .. n,
                        Vector3.new(13, 5.5, 6), Vector3.new(x + n * 20, 2.75, z + 27), STEEL)
                end
            end
        end
    end

    for _, side in ipairs({-1, 1}) do
        local platform = part(folder, "ELEVATION | " .. side, Vector3.new(64, 3, 52),
            Vector3.new(side * 118, 11.5, 0), MID)
        platform:SetAttribute("MantleTarget", true)
        for step = 1, 5 do
            part(folder, "STAIRS | " .. side .. ":" .. step,
                Vector3.new(18, step * 2, 5), Vector3.new(side * 76, step, -30 + step * 5),
                STEEL)
        end
        runnableWall(folder, "FLANK | " .. side, Vector3.new(2.5, 16, 64),
            Vector3.new(side * 148, 8, -60))
        neon(folder, "ELEVATION | edge | " .. side, Vector3.new(61, 0.3, 0.3),
            Vector3.new(side * 118, 13.2, -26), AMBER)
    end

    for i = 1, 16 do
        local angle = i * math.pi / 8
        local radius = 57 + i % 3 * 10
        local x, z = math.cos(angle) * radius, math.sin(angle) * radius
        if z > -46 or math.abs(x) > 35 then
            local cover = part(folder, "BARRICADE | " .. i, Vector3.new(13, 5, 5),
                Vector3.new(x, 2.5, z), STEEL)
            cover.CFrame = CFrame.new(x, 2.5, z) * CFrame.Angles(0, angle, 0)
        end
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "NEON STRIKE | Player Spawn"
    spawn.Anchored = true
    spawn.Size = Vector3.new(18, 1, 18)
    spawn.Position = Vector3.new(0, 0.5, 130)
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Duration = 3
    spawn.Material = Enum.Material.Neon
    spawn.Transparency = 0.25
    spawn.Color = CYAN
    spawn.Parent = folder

    local briefing = part(folder, "SPAWN | briefing",
        Vector3.new(28, 13, 1), Vector3.new(0, 7, 160), MAIN)
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.CanvasSize = Vector2.new(920, 340)
    signGui.Parent = briefing
    local signText = Instance.new("TextLabel")
    signText.BackgroundTransparency = 1
    signText.Size = UDim2.fromScale(1, 1)
    signText.Font = Enum.Font.GothamBold
    signText.TextScaled = true
    signText.Text = "NEON STRIKE\nTRAINING ZONE\nFOLLOW THE BLUE LIGHTS"
    signText.TextColor3 = CYAN
    signText.Parent = signGui
end

function MapService.start()
    if started then return end
    started = true
    local previous = Workspace:FindFirstChild("NeonStrikeArena")
    if previous then previous:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "NeonStrikeArena"
    folder.Parent = Workspace
    Lighting.ClockTime = 19
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(67, 79, 107)
    Lighting.OutdoorAmbient = Color3.fromRGB(24, 36, 51)
    Lighting.FogColor = Color3.fromRGB(33, 44, 65)
    Lighting.FogEnd = 550
    buildArena(folder)
end

return MapService
