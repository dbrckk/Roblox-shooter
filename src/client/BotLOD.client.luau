-- NEON STRIKE / client-only visual LOD for high-frequency mobile combat.
-- Hiding tiny details locally has no effect on server hitboxes, damage or navigation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled
local hideDetailBeyond = isTouch and 65 or 120
local unhideDetailBefore = hideDetailBeyond - 12
local artHideBeyond = isTouch and 110 or 195
local artUnhideBefore = artHideBeyond - 16

local function updateGraphicsLimits()
    local preset = player:GetAttribute("IronYardGraphicsPreset")
    if preset == "ECO" then
        hideDetailBeyond = 38
        artHideBeyond = 70
    elseif preset == "QUALITY" then
        hideDetailBeyond = isTouch and 112 or 170
        artHideBeyond = isTouch and 165 or 245
    else
        hideDetailBeyond = isTouch and 65 or 120
        artHideBeyond = isTouch and 110 or 195
    end
    unhideDetailBefore = hideDetailBeyond - 12
    artUnhideBefore = artHideBeyond - 16
end
player:GetAttributeChangedSignal("IronYardGraphicsPreset"):Connect(updateGraphicsLimits)
updateGraphicsLimits()
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
    rendered[model] = hidden
    -- Revisit streamed-in body cosmetics even if the hide state is unchanged.
    -- Without this, late network replication can make distant detail reappear.
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") and item:GetAttribute("NeonCosmeticTier") == "Detail" then
            item.LocalTransparencyModifier = hidden and 1 or 0
        end
    end
end


local artCache = setmetatable({}, { __mode = "k" })
local artFolders = { "NeonStrikeDecor", "FreightLandmarks" }

local function getDetailParts(folder)
    local entry = artCache[folder]
    if not entry then
        entry = { parts = {}, dirty = true }
        artCache[folder] = entry
        folder.DescendantAdded:Connect(function(item)
            if item:IsA("BasePart") and item:GetAttribute("NeonArtTier") == "Detail" then
                entry.dirty = true
            end
        end)
        folder.DescendantRemoving:Connect(function(item)
            if item:IsA("BasePart") then
                entry.dirty = true
            end
        end)
    end
    if entry.dirty then
        entry.parts = {}
        for _, item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart") and item:GetAttribute("NeonArtTier") == "Detail" then
                table.insert(entry.parts, item)
            end
        end
        entry.dirty = false
    end
    return entry.parts
end

local function updateArt()
    local arena = Workspace:FindFirstChild("NeonStrikeArena")
    local camera = Workspace.CurrentCamera
    if not arena or not camera then return end
    local position = camera.CFrame.Position
    for _, name in ipairs(artFolders) do
        local folder = arena:FindFirstChild(name)
        if folder then
            for _, item in ipairs(getDetailParts(folder)) do
                if item.Parent then
                    local distance = (item.Position - position).Magnitude
                    local wasHidden = rendered[item] or false
                    local hidden = (wasHidden and distance > artUnhideBefore) or distance > artHideBeyond
                    if hidden ~= wasHidden then
                        rendered[item] = hidden
                        item.LocalTransparencyModifier = hidden and 1 or 0
                    end
                end
            end
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
    updateArt()
    task.wait(1)
end
