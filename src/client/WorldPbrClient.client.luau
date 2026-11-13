-- IRON YARD / non-replicated Roblox MaterialVariant client delivery.
-- Server tags ONLY authorized real arena colliders after owner and base-material
-- validation. This script changes visuals locally; physics and hitboxes stay server-owned.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldPbrPolicy"))
local player = Players.LocalPlayer
local TAG = "IronYardWorldPbr"
local KEY = "IronYardPbrMaterial"
local PREFIX = "IronYardPbr_"
local watched = {}
local connections = {}

local function render(part)
    if not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then
        return
    end
    local desired = Policy.clientVariant(part:GetAttribute(KEY),
        part.Material.Name, player:GetAttribute("IronYardGraphicsPreset"))
    if desired == nil then return end -- Never alter unrelated or invalid parts.

    if desired ~= "" then
        -- A tag/attribute or MaterialVariant may replicate in either order.
        -- Never fall back to an unapproved material or a fabricated asset ID.
        if Workspace:GetAttribute("IronYardWorldPbrStatus") ~= "CONFIGURED"
            or not MaterialService:GetMaterialVariant(part.Material, desired) then
            desired = ""
        end
    end
    if part.MaterialVariant ~= desired then
        part.MaterialVariant = desired
    end
end

local function reconcile()
    for part in pairs(watched) do render(part) end
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
        if current:sub(1, #PREFIX) == PREFIX then
            part.MaterialVariant = ""
        end
    end
end

local function watch(part)
    if not part:IsA("BasePart") or watched[part] then return end
    watched[part] = {
        part:GetAttributeChangedSignal(KEY):Connect(function()
            render(part)
        end),
        part.AncestryChanged:Connect(function()
            render(part)
        end),
    }
    render(part)
end

-- CollectionService tag signals handle late replication and streaming.
-- At most the real 24 PBR-tagged gameplay surfaces are tracked: no per-frame
-- arena scans, no network events and no new Parts.
table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(watch))
table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(unwatch))
table.insert(connections, player:GetAttributeChangedSignal("IronYardGraphicsPreset"):Connect(reconcile))
table.insert(connections, Workspace:GetAttributeChangedSignal("IronYardWorldPbrStatus"):Connect(reconcile))
table.insert(connections, MaterialService.ChildAdded:Connect(function(child)
    if child:IsA("MaterialVariant") then reconcile() end
end))
table.insert(connections, MaterialService.ChildRemoved:Connect(function(child)
    if child:IsA("MaterialVariant") then reconcile() end
end))
for _, part in ipairs(CollectionService:GetTagged(TAG)) do watch(part) end

script.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for part in pairs(watched) do unwatch(part) end
end)
