-- IRON YARD / client-only sector-accelerated visual LOD for mobile combat.
-- Hiding tiny details locally has no effect on server hitboxes, damage or navigation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtLOD = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArtLODPolicy"))

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled
local hideDetailBeyond = 0
local unhideDetailBefore = 0
local artHideBeyond = 0
local artUnhideBefore = 0

local function updateGraphicsLimits()
    local limits = ArtLOD.limits(
        player:GetAttribute("IronYardGraphicsPreset"), isTouch)
    hideDetailBeyond = limits.botHide
    unhideDetailBefore = limits.botShow
    artHideBeyond = limits.artHide
    artUnhideBefore = limits.artShow
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


-- Server-authored visual art is static except for gantries moving
-- locally by at most 5.6 studs. Spatial sectors provide conservative
-- whole-group visibility decisions; only horizon sectors need individual
-- distance tests. Core silhouettes and gameplay parts are never included.
local artCache = setmetatable({}, { __mode = "k" })
local artFolders = { "NeonStrikeDecor", "FreightLandmarks", "IronYardCoverSkins" }

local function getDetailGroups(folder)
    local entry = artCache[folder]
    if not entry then
        entry = { groups = {}, dirty = true }
        artCache[folder] = entry
        folder.DescendantAdded:Connect(function(item)
            if item:IsA("BasePart") then
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
        local byKey = {}
        local groups = {}
        for _, item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart")
                and item:GetAttribute("NeonArtTier") == "Detail" then
                local position = item.Position
                local key = ArtLOD.cellKey(position.X, position.Z)
                if key then
                    local group = byKey[key]
                    if not group then
                        group = { parts = {}, bounds = {}, lastMode = nil }
                        byKey[key] = group
                        table.insert(groups, group)
                    end
                    if ArtLOD.extendBounds(group.bounds, position) then
                        table.insert(group.parts, item)
                    end
                end
            end
        end
        entry.groups = groups
        entry.dirty = false
    end
    return entry.groups
end

local function applyGroupState(group, hidden)
    -- Apply on group-mode transition, including after streaming rebuilds:
    -- previous per-part LocalTransparencyModifier values may be stale.
    for _, item in ipairs(group.parts) do
        if item.Parent then
            rendered[item] = hidden
            item.LocalTransparencyModifier = hidden and 1 or 0
        end
    end
end

local function updateArt()
    local arena = Workspace:FindFirstChild("NeonStrikeArena")
    local camera = Workspace.CurrentCamera
    if not arena or not camera then return end
    local position = camera.CFrame.Position
    for _, name in ipairs(artFolders) do
        local folder = arena:FindFirstChild(name)
        if folder then
            for _, group in ipairs(getDetailGroups(folder)) do
                local mode = ArtLOD.classify(group.bounds, position,
                    artHideBeyond, artUnhideBefore)
                if mode == "HIDE" or mode == "SHOW" then
                    if mode ~= group.lastMode then
                        applyGroupState(group, mode == "HIDE")
                    end
                else
                    -- Only groups crossing the current art visibility
                    -- horizon need accurate individual 3D distances.
                    for _, item in ipairs(group.parts) do
                        if item.Parent then
                            local offset = item.Position - position
                            local distanceSquared = offset:Dot(offset)
                            local wasHidden = rendered[item] or false
                            local hidden = ArtLOD.hiddenSquared(distanceSquared,
                                wasHidden, artHideBeyond, artUnhideBefore)
                            if hidden ~= wasHidden then
                                rendered[item] = hidden
                                item.LocalTransparencyModifier = hidden and 1 or 0
                            end
                        end
                    end
                end
                group.lastMode = mode
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
