-- IRON YARD / client-only sector-accelerated visual LOD for mobile combat.
-- Hiding tiny details locally has no effect on server hitboxes, damage or navigation.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLOD = require(Shared:WaitForChild("ArtLODPolicy"))
local BotDetailCache = require(Shared:WaitForChild("BotDetailCache"))
local ArtSectorRegistry = require(Shared:WaitForChild("ArtSectorRegistry"))

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

-- A bot's visual inventory is constructed once. Incremental events handle
-- streaming and rebuilds without scanning every armor part once per second.
-- Only cosmetic Tier=Detail parts are ever modified; the Humanoid rig,
-- imported Core silhouettes and real hitboxes are left completely untouched.
local botCache = {}

local function releaseBot(model)
    local entry = botCache[model]
    if not entry then return end
    for _, connection in ipairs(entry.connections) do
        connection:Disconnect()
    end
    for part, connection in pairs(entry.partConnections) do
        connection:Disconnect()
        entry.partConnections[part] = nil
    end
    for part in pairs(entry.state.details) do
        if part.Parent then part.LocalTransparencyModifier = 0 end
        BotDetailCache.remove(entry.state, part)
    end
    botCache[model] = nil
end

local function watchBot(model)
    local entry = {
        state = BotDetailCache.new(),
        connections = {},
        partConnections = {},
    }
    botCache[model] = entry

    local function unwatchPart(part)
        local connection = entry.partConnections[part]
        if connection then
            connection:Disconnect()
            entry.partConnections[part] = nil
        end
        if BotDetailCache.remove(entry.state, part) and part.Parent then
            part.LocalTransparencyModifier = 0
        end
    end

    local function inspectPart(part)
        if not part:IsA("BasePart") then return end
        local tier = part:GetAttribute("NeonCosmeticTier")
        local changed = BotDetailCache.observe(entry.state, part, tier)
        if changed then
            -- A late-streamed Detail instantly inherits the bot's current
            -- visibility. Changing Detail to Core restores its real opacity.
            part.LocalTransparencyModifier =
                tier == "Detail" and entry.state.hidden == true and 1 or 0
        end
        -- Only wait for a tier that has not yet replicated. The server sets
        -- tier before parenting, but streaming may deliver attributes later.
        if tier == nil and not entry.partConnections[part] then
            entry.partConnections[part] =
                part:GetAttributeChangedSignal("NeonCosmeticTier"):Connect(function()
                    inspectPart(part)
                end)
        elseif tier ~= nil then
            local connection = entry.partConnections[part]
            if connection then
                connection:Disconnect()
                entry.partConnections[part] = nil
            end
        end
    end

    table.insert(entry.connections, model.DescendantAdded:Connect(inspectPart))
    table.insert(entry.connections, model.DescendantRemoving:Connect(function(item)
        if item:IsA("BasePart") then unwatchPart(item) end
    end))
    for _, item in ipairs(model:GetDescendants()) do
        inspectPart(item)
    end
    return entry
end

local function getDistanceSquared(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local camera = Workspace.CurrentCamera
    local from = camera and camera.CFrame.Position
    if not from then
        local characterRoot = player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
        from = characterRoot and characterRoot.Position
    end
    if not from then return nil end
    local delta = root.Position - from
    return delta:Dot(delta)
end

local function updateModel(model)
    if not model:IsA("Model") or not model:GetAttribute("IsArenaBot") then return end
    local distanceSquared = getDistanceSquared(model)
    if not distanceSquared then return end
    local entry = botCache[model] or watchBot(model)
    local changed, hidden = BotDetailCache.decide(entry.state,
        distanceSquared, hideDetailBeyond, unhideDetailBefore)
    if not changed then return end
    for part in pairs(entry.state.details) do
        if part.Parent then
            local modifier = hidden and 1 or 0
            if part.LocalTransparencyModifier ~= modifier then
                part.LocalTransparencyModifier = modifier
            end
        end
    end
end

-- Server-authored visual art is static except for gantries moving
-- locally by at most 5.6 studs. Spatial sectors provide conservative
-- whole-group visibility decisions; only horizon sectors need individual
-- distance tests. Core silhouettes and gameplay parts are never included.
local artCache = {}
local artFolders = { "NeonStrikeDecor", "FreightLandmarks", "IronYardCoverSkins" }
local trackedArtFolders = {}

-- Streaming a single decoration should NOT rebuild thousands of parts.
-- Register once and listen for incremental additions/removals. Only Detail
-- is tracked; Core landmarks and real arena collision remain untouched.
local function releaseArtFolder(folder)
    local entry = artCache[folder]
    if not entry then return end
    for _, connection in ipairs(entry.connections) do connection:Disconnect() end
    for item, connection in pairs(entry.pendingTier) do
        connection:Disconnect()
        entry.pendingTier[item] = nil
    end
    for item in pairs(entry.registry.byPart) do
        if item.Parent then item.LocalTransparencyModifier = 0 end
        rendered[item] = nil
    end
    ArtSectorRegistry.clear(entry.registry)
    artCache[folder] = nil
end

local function getDetailGroups(folder, initialEye)
    local entry = artCache[folder]
    if entry then return entry end
    entry = {
        registry = ArtSectorRegistry.new(),
        pendingTier = {},
        connections = {},
        lastEye = initialEye,
    }
    artCache[folder] = entry

    local function unwatchPart(item)
        local pending = entry.pendingTier[item]
        if pending then
            pending:Disconnect()
            entry.pendingTier[item] = nil
        end
        if ArtSectorRegistry.remove(entry.registry, item) then
            rendered[item] = nil
            if item.Parent then item.LocalTransparencyModifier = 0 end
        end
    end

    local function inspectPart(item)
        if not item:IsA("BasePart") then return end
        local tier = item:GetAttribute("NeonArtTier")
        if tier == "Detail" then
            if ArtSectorRegistry.add(entry.registry, item, item.Position) then
                -- Apply visibility immediately to a late-streamed part,
                -- avoiding a distant visual flash before the next 1Hz poll.
                local eye = entry.lastEye
                if eye then
                    local offset = item.Position - eye
                    local hidden = ArtLOD.hiddenSquared(offset:Dot(offset),
                        false, artHideBeyond, artUnhideBefore)
                    rendered[item] = hidden
                    item.LocalTransparencyModifier = hidden and 1 or 0
                end
            end
        elseif ArtSectorRegistry.remove(entry.registry, item) then
            rendered[item] = nil
            item.LocalTransparencyModifier = 0
        end
        -- Tier may replicate after the BasePart. The listener is temporary,
        -- not a permanent attribute connection for every static decoration.
        if tier == nil and not entry.pendingTier[item] then
            entry.pendingTier[item] =
                item:GetAttributeChangedSignal("NeonArtTier"):Connect(function()
                    inspectPart(item)
                end)
        elseif tier ~= nil then
            local pending = entry.pendingTier[item]
            if pending then
                pending:Disconnect()
                entry.pendingTier[item] = nil
            end
        end
    end

    table.insert(entry.connections, folder.DescendantAdded:Connect(inspectPart))
    table.insert(entry.connections, folder.DescendantRemoving:Connect(function(item)
        if item:IsA("BasePart") then
            unwatchPart(item)
        else
            -- Removing an entire streamed Model may notify the container
            -- before its children; remove its detail references promptly.
            for _, desc in ipairs(item:GetDescendants()) do
                if desc:IsA("BasePart") then unwatchPart(desc) end
            end
        end
    end))
    -- One snapshot, indexed in bounded batches across Heartbeats instead
    -- of thousands of client Part checks on a single combat frame.
    -- New DescendantAdded events are still processed immediately.
    local initialParts = folder:GetDescendants()
    task.spawn(function()
        local batch = ArtLOD.bootstrapBatch(
            player:GetAttribute("IronYardGraphicsPreset"), isTouch)
        for index, item in ipairs(initialParts) do
            if artCache[folder] ~= entry or not folder:IsDescendantOf(Workspace) then
                return
            end
            -- Streaming may remove a snapshot item before its registration.
            if item:IsDescendantOf(folder) then inspectPart(item) end
            if index % batch == 0 then RunService.Heartbeat:Wait() end
        end
    end)
    return entry
end

local function applyGroupState(group, hidden)
    -- Apply on group-mode transition, including after streaming rebuilds:
    -- previous per-part LocalTransparencyModifier values may be stale.
    for item in pairs(group.parts) do
        if item.Parent then
            rendered[item] = hidden
            item.LocalTransparencyModifier = hidden and 1 or 0
        end
    end
end

local function updateArt()
    local arena = Workspace:FindFirstChild("NeonStrikeArena")
    local camera = Workspace.CurrentCamera
    local position = camera and camera.CFrame.Position
    for _, name in ipairs(artFolders) do
        local folder = arena and arena:FindFirstChild(name)
        local previous = trackedArtFolders[name]
        if previous ~= folder then
            if previous then releaseArtFolder(previous) end
            trackedArtFolders[name] = folder
        end
        if folder then
            local entry = getDetailGroups(folder, position)
            if position then
                entry.lastEye = position
                for _, group in pairs(entry.registry.byKey) do
                    local mode = ArtLOD.classify(group.bounds, position,
                        artHideBeyond, artUnhideBefore)
                    if mode == "HIDE" or mode == "SHOW" then
                        if mode ~= group.lastMode then
                            applyGroupState(group, mode == "HIDE")
                        end
                    else
                        -- Only sectors crossing the visibility horizon
                        -- need exact per-Part checks and hysteresis.
                        for item in pairs(group.parts) do
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
end

-- Avoid repeated GetDescendants() and transparency writes for static
-- visibility. The fixed 1 Hz poll now costs one root distance per live bot.
local activeBotFolder = nil
local folderRemovedConnection = nil

local function connectBotFolder(folder)
    if activeBotFolder == folder then return end
    if folderRemovedConnection then folderRemovedConnection:Disconnect() end
    folderRemovedConnection = nil
    for model in pairs(botCache) do releaseBot(model) end
    activeBotFolder = folder
    if folder then
        folderRemovedConnection = folder.ChildRemoved:Connect(releaseBot)
    end
end

while true do
    local folder = Workspace:FindFirstChild("NeonStrikeBots")
    connectBotFolder(folder)
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            updateModel(model)
        end
    end
    updateArt()
    task.wait(1)
end
