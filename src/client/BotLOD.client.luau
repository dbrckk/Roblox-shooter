-- NEON STRIKE / client-only visual LOD for high-frequency mobile combat.
-- Hiding tiny details locally has no effect on server hitboxes, damage or navigation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled
local hideDetailBeyond = isTouch and 65 or 120
local unhideDetailBefore = hideDetailBeyond - 12
local rendered = setmetatable({}, { __mode = "k" })

local function getDistance(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local camera = Workspace.CurrentCamera
    local from = camera and camera.CFrame.Position
    if not from then
        local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        from = characterRoot and characterRoot.Position
    end
    if not from then return nil end
    return (root.Position - from).Magnitude
end

local function updateModel(model)
    if not model:IsA("Model") or not model:GetAttribute("IsArenaBot") then return end
    local distance = getDistance(model)
    if not distance then return end

    local wasHidden = rendered[model] or false
    local hidden = wasHidden and distance > unhideDetailBefore or distance > hideDetailBeyond
    if hidden == wasHidden then return end
    rendered[model] = hidden
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") and item:GetAttribute("NeonCosmeticTier") == "Detail" then
            item.LocalTransparencyModifier = hidden and 1 or 0
        end
    end
end

-- Never touch core parts or gameplay rig. 4 bots * ~60 parts at 1 Hz.
while true do
    local folder = Workspace:FindFirstChild("NeonStrikeBots")
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            updateModel(model)
        end
    end
    task.wait(1)
end
