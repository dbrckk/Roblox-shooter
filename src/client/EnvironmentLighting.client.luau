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
player:GetAttributeChangedSignal("IronYardGraphicsPreset"):Connect(applyGraphics)
applyGraphics()

local arena = Workspace:WaitForChild("NeonStrikeArena", 45)
local decor = arena and arena:WaitForChild("NeonStrikeDecor", 45)
if not decor then
    warn("[IRON YARD] Optional local industrial lights unavailable; daylight grading active")
    return
end

local registered = setmetatable({}, { __mode = "k" })
local fixtures = {}

local function register(part)
    if not part:IsA("BasePart")
        or part:GetAttribute("IronYardLightFixture") ~= true
        or registered[part] then
        return
    end
    registered[part] = true
    table.insert(fixtures, { part = part, lamp = nil })
end

for _, descendant in ipairs(decor:GetDescendants()) do register(descendant) end
decor.DescendantAdded:Connect(register)

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
    if not camera or not settings then return end

    local current = {}
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
    for _, entry in ipairs(fixtures) do
        table.insert(current, entry)
        table.insert(distances, (entry.part.Position - camera.CFrame.Position).Magnitude)
    end
    local selected = Profile.activeFixtureIndices(distances,
        player:GetAttribute("IronYardGraphicsPreset"), touch)
    for index, entry in ipairs(current) do
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
    updateFixtures()
    task.wait(1.2)
end
