-- IRON YARD / local industrial grading and nearby fixture lighting.
-- Never modifies server hitboxes, arena collision or camera controls.
-- ECO stays bright and disables all dynamic lights; mobile is strictly capped.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Profile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnvironmentProfile"))
local touch = UserInputService.TouchEnabled

local function getOrCreate(name, className)
    local instance = Lighting:FindFirstChild(name)
    if instance and instance:IsA(className) then return instance end
    if instance then instance:Destroy() end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = Lighting
    return created
end

local grade = getOrCreate("IronYardGrade", "ColorCorrectionEffect")
local atmosphere = getOrCreate("IronYardAtmosphere", "Atmosphere")
local bloom = getOrCreate("IronYardSunGlint", "BloomEffect")
bloom.Intensity = 0.075
bloom.Size = 16
bloom.Threshold = 1.65
bloom.Enabled = false

local settings = nil
local function applyGraphics()
    settings = Profile.get(player:GetAttribute("IronYardGraphicsPreset"), touch)
    grade.Enabled = true
    grade.Brightness = settings.brightness
    grade.Contrast = settings.contrast
    grade.Saturation = settings.saturation
    grade.TintColor = Color3.fromRGB(255, 250, 242)
    atmosphere.Density = settings.density
    atmosphere.Haze = settings.haze
    atmosphere.Glare = settings.glare
    atmosphere.Color = Color3.fromRGB(218, 224, 217)
    atmosphere.Decay = Color3.fromRGB(183, 193, 202)
    bloom.Enabled = settings.bloom
    -- Keep long-distance silhouettes clear even on the highest preset.
    Lighting.ExposureCompensation = settings.exposure
    Lighting.ShadowSoftness = 0.33
    Lighting.EnvironmentDiffuseScale = 0.55
    Lighting.EnvironmentSpecularScale = 0.38
    Lighting.ColorShift_Top = Color3.fromRGB(12, 8, 2)
    Lighting.ColorShift_Bottom = Color3.fromRGB(4, 7, 9)
end
local graphicsConnection =
    player:GetAttributeChangedSignal("IronYardGraphicsPreset"):Connect(applyGraphics)
applyGraphics()

-- The arena/decor tree may stream out or be rebuilt between rounds.
-- Keep daylight grading active even if optional fixtures have not yet
-- arrived, and reconnect automatically when the folder appears.
local decor = nil
local decorAddedConnection = nil
local registered = setmetatable({}, { __mode = "k" })
local fixtures = {}

local function register(part)
    if not decor or not part:IsA("BasePart")
        or not part:IsDescendantOf(decor)
        or part:GetAttribute("IronYardLightFixture") ~= true
        or registered[part] then
        return
    end
    registered[part] = true
    table.insert(fixtures, { part = part, lamp = nil })
end

local function refreshDecor()
    local arena = Workspace:FindFirstChild("NeonStrikeArena")
    local current = arena and arena:FindFirstChild("NeonStrikeDecor")
    if current == decor then return end

    if decorAddedConnection then
        decorAddedConnection:Disconnect()
        decorAddedConnection = nil
    end
    -- Destroy lights from the obsolete arena before dropping its Parts.
    -- A weak-key registry alone cannot release entries still in fixtures.
    for _, entry in ipairs(fixtures) do
        if entry.lamp then entry.lamp:Destroy() end
    end
    table.clear(fixtures)
    table.clear(registered)
    decor = current
    if decor then
        decorAddedConnection = decor.DescendantAdded:Connect(register)
        for _, descendant in ipairs(decor:GetDescendants()) do
            register(descendant)
        end
    end
end
refreshDecor()

script.Destroying:Connect(function()
    graphicsConnection:Disconnect()
    if decorAddedConnection then decorAddedConnection:Disconnect() end
    for _, entry in ipairs(fixtures) do
        if entry.lamp then entry.lamp:Destroy() end
    end
    table.clear(fixtures)
end)

local function tuneLocalSpot(lamp, part)
    -- Warehouse: restrained warm task lighting for material relief.
    -- Catwalk: neutral-cool work lamps preserving enemy silhouettes.
    local role = part:GetAttribute("IronYardLightRole")
    local style = Profile.fixtureStyle(role,
        player:GetAttribute("IronYardGraphicsPreset"), touch)
    if not style then return end
    lamp.Color = Color3.fromRGB(style.red, style.green, style.blue)
    lamp.Angle = style.angle
    lamp.Range = style.range
    lamp.Brightness = style.brightness
end

local function createLocalSpot(part)
    local lamp = Instance.new("SpotLight")
    lamp.Name = "IronYardLocalSpot"
    lamp.Face = Enum.NormalId.Bottom
    lamp.Shadows = false
    tuneLocalSpot(lamp, part)
    lamp.Parent = part
    return lamp
end

-- 13 fixtures maximum, updated only once per 1.2 seconds. Light selection
-- follows the local camera and never consumes replicated server work.
local function updateFixtures()
    local camera = Workspace.CurrentCamera
    if not camera or not settings or not decor then return end

    local distances = {}
    -- Clean up streamed-out or replaced fixtures instead of accumulating
    -- stale entries during long sessions and arena reloads.
    for i = #fixtures, 1, -1 do
        local entry = fixtures[i]
        if not entry.part:IsDescendantOf(decor) then
            if entry.lamp then entry.lamp:Destroy() end
            registered[entry.part] = nil
            table.remove(fixtures, i)
        end
    end
    local eye = camera.CFrame.Position
    for _, entry in ipairs(fixtures) do
        distances[#distances + 1] = (entry.part.Position - eye).Magnitude
    end
    local selected = Profile.activeFixtureIndices(distances,
        player:GetAttribute("IronYardGraphicsPreset"), touch)
    for index, entry in ipairs(fixtures) do
        if selected[index] then
            if not entry.lamp then entry.lamp = createLocalSpot(entry.part) end
            -- Refresh in place after ECO/BAL/QUALITY changes: no light
            -- accumulation and no stale brightness when settings change.
            tuneLocalSpot(entry.lamp, entry.part)
            entry.lamp.Enabled = true
        elseif entry.lamp then
            entry.lamp.Enabled = false
        end
    end
end

while script.Parent do
    refreshDecor()
    updateFixtures()
    task.wait(1.2)
end
