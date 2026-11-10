-- IRON YARD / local rooftop extraction vapor for original industrial artwork.
-- The real server map never emits parts, particle streams, light or sound.
-- Rendered vapor is purely cosmetic and cannot affect combat or navigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(shared:WaitForChild("EnvironmentProfile"))
local VaporPool = require(shared:WaitForChild("ExhaustWispPool"))
local arena = Workspace:WaitForChild("NeonStrikeArena", 45)
local decor = arena and arena:WaitForChild("NeonStrikeDecor", 45)
if not decor then
    warn("[IRON YARD] Exhaust ambience disabled: optional roof art unavailable")
    return
end

local registered = setmetatable({}, { __mode = "k" })
local emitters = {}
local vaporSlots = {}
local activeVaporIndices = {}
local animationStepAt = 0
local START_SIZE = Vector3.new(0.66, 0.36, 0.66)
local END_SIZE = Vector3.new(2.18, 1.04, 2.18)
local VAPOR_COLOR = Color3.fromRGB(189, 197, 193)

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

-- One pool serves every rooftop exhaust, whatever the current quality
-- preset. Animation is local only and never enters hit registration.
local function makeWisp(entry, index, now, cap)
    local part = entry.part
    if not part or not part:IsDescendantOf(decor) then return false end
    local slot, slotIndex = VaporPool.claim(vaporSlots, now, cap)
    if not slot then return false end

    local side = index % 2 == 0 and 1 or -1
    -- Keep the vapor above the duct, never in walkable combat lanes.
    local from = part.Position + Vector3.new(
        side * 0.37, part.Size.Y * 0.5 + 1.15, -side * 0.25)
    local puff = slot.part
    if not puff then
        puff = Instance.new("Part")
        puff.Name = "IronYardExhaustWisp"
        puff.Shape = Enum.PartType.Ball
        puff.Anchored = true
        puff.CanCollide = false
        puff.CanQuery = false
        puff.CanTouch = false
        puff.CastShadow = false
        puff.Material = Enum.Material.SmoothPlastic
        puff.Color = VAPOR_COLOR
        slot.part = puff
    end
    slot.fromPosition = from
    slot.toPosition = from + Vector3.new(side * 0.78, 3.15, 0.62)
    activeVaporIndices[slotIndex] = true
    puff.Size = START_SIZE
    puff.Transparency = 0.78
    puff.Position = from
    puff.Parent = Workspace
    return true
end

-- Quad.Out is the same interpolation as the old TweenInfo. Capped at 30Hz
-- for a maximum of 12 soft vapor blobs. The idle path does no pool work.
local animationConnection = RunService.RenderStepped:Connect(function()
    if not next(activeVaporIndices) then return end
    local now = os.clock()
    if now < animationStepAt then return end
    animationStepAt = now + 1 / 30
    local cap = VaporPool.cap(Profile.get(
        player:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled))
    for index in pairs(activeVaporIndices) do
        local slot = vaporSlots[index]
        local eased = slot and VaporPool.alpha(slot, now, index <= cap)
        local puff = slot and slot.part
        if eased and puff then
            puff.Position = slot.fromPosition:Lerp(slot.toPosition, eased)
            puff.Size = START_SIZE:Lerp(END_SIZE, eased)
            puff.Transparency = 0.78 + 0.22 * eased
        else
            activeVaporIndices[index] = nil
            if puff and puff.Parent then puff.Parent = nil end
        end
    end
end)

-- A removed LocalScript must not orphan local Workspace Parts.
script.Destroying:Connect(function()
    animationConnection:Disconnect()
    for _, slot in ipairs(vaporSlots) do
        if slot.part then slot.part:Destroy() end
    end
    table.clear(activeVaporIndices)
end)

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
        local cap = VaporPool.cap(settings)
        if cap > 0 then
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
                    makeWisp(entry, i, now, cap)
                    entry.nextAt = now + settings.exhaustInterval + (i % 3) * 0.10
                end
            end
        end
    end
end
