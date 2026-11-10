-- IRON YARD / floor-contact dust for confirmed bot eliminations.
-- Purely local, transient geometry; never touches authoritative hitboxes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Plan = require(shared:WaitForChild("BotDeathPlan"))
local DustPool = require(shared:WaitForChild("BotDeathDustPool"))

local player = Players.LocalPlayer
local bound = setmetatable({}, { __mode = "k" })
local dustSlots = {}
local activeDustIndices = {}
local nextAnimationAt = 0
local START_SIZE = Vector3.new(0.22, 0.15, 0.22)
local END_SIZE = Vector3.new(0.58, 0.30, 0.58)
local DUST_COLOR = Color3.fromRGB(146, 139, 123)

-- One bounded local renderer for every bot's death dust. The 30 Hz
-- updates execute only while at least one fragment is active.
local animationConnection = RunService.RenderStepped:Connect(function()
    if not next(activeDustIndices) then return end
    local now = os.clock()
    if now < nextAnimationAt then return end
    nextAnimationAt = now + 1 / 30
    local cap = DustPool.cap(player:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    for index in pairs(activeDustIndices) do
        local slot = dustSlots[index]
        local eased = slot and DustPool.ease(slot, now, index <= cap)
        local puff = slot and slot.part
        if eased and puff then
            puff.Position = slot.fromPosition:Lerp(slot.toPosition, eased)
            puff.Size = START_SIZE:Lerp(END_SIZE, eased)
            puff.Transparency = 0.64 + eased * 0.36
        else
            activeDustIndices[index] = nil
            if puff and puff.Parent then puff.Parent = nil end
        end
    end
end)

script.Destroying:Connect(function()
    animationConnection:Disconnect()
    for _, slot in ipairs(dustSlots) do
        if slot.part then slot.part:Destroy() end
    end
    table.clear(activeDustIndices)
end)

local function dustAt(model)
    if not model.Parent then return end
    local root = model:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then return end
    local distance = (root.Position - camera.CFrame.Position).Magnitude
    local budget = Plan.dustBudget(player:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled, distance)
    if not budget then return end
    local cap = DustPool.cap(player:GetAttribute("IronYardGraphicsPreset"),
        UserInputService.TouchEnabled)
    if cap <= 0 then return end

    -- Only animate a real nearby horizontal floor, never an airborne false
    -- dust cloud over an open catwalk. One bounded raycast per elimination.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { model }
    params.IgnoreWater = true
    params.RespectCanCollide = true
    local floor = Workspace:Raycast(root.Position + Vector3.new(0, 3, 0),
        Vector3.new(0, -9, 0), params)
    if not floor or floor.Normal.Y < 0.65 then return end

    local center = floor.Position + floor.Normal * 0.12
    local now = os.clock()
    for index = 1, budget.fragments do
        local slot, slotIndex = DustPool.claim(dustSlots, now,
            budget.duration, cap)
        if not slot then
            -- Under a four-bot crossfire, an already-visible fragment
            -- wins over a new purely cosmetic one. No extra Parts are made.
            break
        end
        local angle = (index - 1) * math.pi * 2 / budget.fragments
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local from = center + direction * 0.17
        local puff = slot.part
        if not puff then
            puff = Instance.new("Part")
            puff.Name = "IronYardDefeatDust"
            puff.Shape = Enum.PartType.Ball
            puff.Color = DUST_COLOR
            puff.Material = Enum.Material.SmoothPlastic
            puff.Anchored = true
            puff.CanCollide = false
            puff.CanQuery = false
            puff.CanTouch = false
            puff.CastShadow = false
            slot.part = puff
        end
        slot.fromPosition = from
        slot.toPosition = center + direction * 1.15
            + Vector3.new(0, 0.32, 0)
        activeDustIndices[slotIndex] = true
        puff.Size = START_SIZE
        puff.Transparency = 0.64
        puff.Position = from
        puff.Parent = Workspace
    end
end

local function bind(model)
    if not model:IsA("Model") or bound[model] then return end
    if model:GetAttribute("IsArenaBot") ~= true then return end
    bound[model] = true
    task.spawn(function()
        local humanoid = model:WaitForChild("Humanoid", 5)
        if not humanoid or not model.Parent then return end
        humanoid.Died:Connect(function()
            -- Match the server's settle pose; do not generate at the instant
            -- of impact or when a character is destroyed for round reset.
            task.delay(0.64, function()
                if model.Parent then dustAt(model) end
            end)
        end)
    end)
end

local folder = Workspace:WaitForChild("NeonStrikeBots")
folder.ChildAdded:Connect(bind)
for _, child in ipairs(folder:GetChildren()) do bind(child) end
