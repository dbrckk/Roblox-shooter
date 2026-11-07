-- IRON YARD / local rooftop extraction vapor for original industrial artwork.
-- The real server map never emits parts, particle streams, light or sound.
-- Rendered vapor is purely cosmetic and cannot affect combat or navigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Profile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnvironmentProfile"))
local arena = Workspace:WaitForChild("NeonStrikeArena", 45)
local decor = arena and arena:WaitForChild("NeonStrikeDecor", 45)
if not decor then
    warn("[IRON YARD] Exhaust ambience disabled: optional roof art unavailable")
    return
end

local registered = setmetatable({}, { __mode = "k" })
local emitters = {}

local function register(part)
    if not part:IsA("BasePart")
        or part:GetAttribute("IronYardExhaustVent") ~= true
        or registered[part] then return end
    registered[part] = true
    table.insert(emitters, {
        part = part,
        nextAt = os.clock() + #emitters * 0.17,
    })
end

for _, descendant in ipairs(decor:GetDescendants()) do
    register(descendant)
end
decor.DescendantAdded:Connect(register)

local function makeWisp(entry, index)
    local part = entry.part
    if not part or not part:IsDescendantOf(decor) then return end
    -- The cap is just above this duct's top. Do not spawn vapor inside
    -- a walkable lane or at the origin of a bullet ray.
    local side = index % 2 == 0 and 1 or -1
    local from = part.Position + Vector3.new(
        side * 0.37, part.Size.Y * 0.5 + 1.15, -side * 0.25)
    local puff = Instance.new("Part")
    puff.Name = "IronYardExhaustWisp"
    puff.Shape = Enum.PartType.Ball
    puff.Anchored = true
    puff.CanCollide = false
    puff.CanQuery = false
    puff.CanTouch = false
    puff.CastShadow = false
    puff.Material = Enum.Material.SmoothPlastic
    puff.Color = Color3.fromRGB(189, 197, 193)
    puff.Transparency = 0.78
    puff.Size = Vector3.new(0.66, 0.36, 0.66)
    puff.Position = from
    puff.Parent = Workspace

    local duration = 1.08
    TweenService:Create(puff,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = from + Vector3.new(side * 0.78, 3.15, 0.62),
            Size = Vector3.new(2.18, 1.04, 2.18),
            Transparency = 1,
        }):Play()
    Debris:AddItem(puff, duration + 0.04)
end

-- Tiny bounded 5Hz work, rather than allocating an emitter for every
-- decorative rooftop part or doing per-frame geometry/physics updates.
while script.Parent do
    task.wait(0.2)
    local camera = Workspace.CurrentCamera
    if camera then
        for i = #emitters, 1, -1 do
            local entry = emitters[i]
            if not entry.part:IsDescendantOf(decor) then
                registered[entry.part] = nil
                table.remove(emitters, i)
            end
        end
        local preset = player:GetAttribute("IronYardGraphicsPreset")
        local settings = Profile.get(preset, UserInputService.TouchEnabled)
        if settings.exhausts > 0 then
            local distances = {}
            for _, entry in ipairs(emitters) do
                distances[#distances + 1] =
                    (entry.part.Position - camera.CFrame.Position).Magnitude
            end
            local selected = Profile.activeExhaustIndices(distances, preset,
                UserInputService.TouchEnabled)
            local now = os.clock()
            for i, entry in ipairs(emitters) do
                if selected[i] and now >= entry.nextAt then
                    makeWisp(entry, i)
                    entry.nextAt = now + settings.exhaustInterval + (i % 3) * 0.10
                end
            end
        end
    end
end
