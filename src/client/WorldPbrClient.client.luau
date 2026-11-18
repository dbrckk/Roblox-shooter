-- IRON YARD / non-replicated Roblox MaterialVariant client delivery.
-- Server tags authorized arena surfaces after owner and base-material
-- validation. This script changes visuals locally; physics and hitboxes stay server-owned.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldPbrPolicy"))
local player = Players.LocalPlayer
local TAG = "IronYardWorldPbr"
local KEY = "IronYardPbrMaterial"
local batchSize = UserInputService.TouchEnabled and 12 or 32
local watched = {}
local connections = {}
local queue, queued = {}, {}
local head, tail = 1, 0
local refreshRequested = false
local batchConnection
local disposed = false

local function render(part, preset, configured, available)
    if not part:IsDescendantOf(Workspace) then return end
    local base = part.Material
    local desired = Policy.clientVariant(part:GetAttribute(KEY), base.Name, preset)
    if desired == nil then
        -- A previously valid key can become invalid when its base material
        -- or replicated attribute changes. Remove ONLY our exact whitelisted
        -- visual override; never replace an unrelated system's variant.
        if Policy.isOwnedVariant(part.MaterialVariant) then
            part.MaterialVariant = ""
        end
        return
    end

    if desired ~= "" then
        -- A tag/attribute or MaterialVariant may replicate in either order.
        -- Never fall back to an unapproved material or a fabricated asset ID.
        if configured and available[desired] == nil then
            available[desired] = MaterialService:GetMaterialVariant(base, desired) ~= nil
        end
        if not configured or not available[desired] then desired = "" end
    end
    -- ECO removes only approved IRON YARD variants, never third-party
    -- materials that a separate local system may have chosen.
    if desired == "" and not Policy.isOwnedVariant(part.MaterialVariant) then
        return
    end
    if part.MaterialVariant ~= desired then
        part.MaterialVariant = desired
    end
end

local function unwatch(part)
    local entry = watched[part]
    if not entry then return end
    for _, connection in ipairs(entry) do connection:Disconnect() end
    watched[part] = nil
    -- When a tag is removed from an existing collider, restore the native
    -- surface only if this script previously selected our named variant.
    if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
        local current = part.MaterialVariant
        if Policy.isOwnedVariant(current) then
            part.MaterialVariant = ""
        end
    end
end

local function enqueue(part)
    if queued[part] then return end
    tail += 1
    queue[tail] = part
    queued[part] = true
end

local scheduleBatch
local function watch(part)
    if watched[part] then return end
    local function markDirty()
        if disposed or not watched[part] then return end
        enqueue(part)
        scheduleBatch()
    end
    watched[part] = {
        part:GetAttributeChangedSignal(KEY):Connect(markDirty),
        -- During streamed/rebuilt maps, a collider can change native
        -- material while its original PBR tag remains attached.
        part:GetPropertyChangedSignal("Material"):Connect(markDirty),
        part.AncestryChanged:Connect(markDirty),
    }
end

local function applyBatch()
    if disposed then return end
    -- Coalesce material replication and graphics changes before scanning the
    -- registry. Already queued parts will read the latest state on their turn.
    if refreshRequested then
        refreshRequested = false
        for part in pairs(watched) do enqueue(part) end
    end
    local preset = player:GetAttribute("IronYardGraphicsPreset")
    local configured = Workspace:GetAttribute("IronYardWorldPbrStatus") == "CONFIGURED"
    local available = {}
    for _ = head, math.min(tail, head + batchSize - 1) do
        local part = queue[head]
        queue[head] = nil
        queued[part] = nil
        head += 1
        -- A streaming removal can beat this batch. Never register a
        -- detached or no-longer-tagged part from an earlier snapshot.
        if part:IsDescendantOf(game) and CollectionService:HasTag(part, TAG) then
            watch(part)
            render(part, preset, configured, available)
        end
    end
    if head > tail and not refreshRequested then
        head, tail = 1, 0
        batchConnection:Disconnect()
        batchConnection = nil
    end
end

scheduleBatch = function()
    if not batchConnection then batchConnection = RunService.Heartbeat:Connect(applyBatch) end
end

local function addPart(part)
    if disposed or not part:IsA("BasePart") then return end
    enqueue(part)
    scheduleBatch()
end

local function requestRefresh()
    if disposed then return end
    refreshRequested = true
    scheduleBatch()
end

-- CollectionService tag signals handle late replication and streaming.
-- Track only PBR-tagged surfaces. No per-frame arena scans or network events.
table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(addPart))
table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(unwatch))
table.insert(connections, player:GetAttributeChangedSignal("IronYardGraphicsPreset"):Connect(requestRefresh))
table.insert(connections, Workspace:GetAttributeChangedSignal("IronYardWorldPbrStatus"):Connect(requestRefresh))
table.insert(connections, MaterialService.ChildAdded:Connect(function(child)
    if child:IsA("MaterialVariant") then requestRefresh() end
end))
table.insert(connections, MaterialService.ChildRemoved:Connect(function(child)
    if child:IsA("MaterialVariant") then requestRefresh() end
end))
for _, part in ipairs(CollectionService:GetTagged(TAG)) do addPart(part) end

script.Destroying:Connect(function()
    disposed = true
    if batchConnection then batchConnection:Disconnect() end
    table.clear(queue)
    table.clear(queued)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for part in pairs(watched) do unwatch(part) end
end)
