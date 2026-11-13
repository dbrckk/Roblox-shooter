-- IRON YARD / secure opt-in world PBR MaterialVariant registration.
-- The default native world is always playable. No client-supplied IDs,
-- dynamic assets, InsertService or network calls are used by this module.
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Registry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldPbrAssetIds"))
local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldPbrPolicy"))
local WorldPbr = {}
local started = false
local ready = false

function WorldPbr.start()
    if started then return end
    started = true
    ready = false
    Workspace:SetAttribute("IronYardWorldPbrStatus", "FALLBACK")

    if game.CreatorType ~= Enum.CreatorType.User
        or not Policy.ready(Registry, game.CreatorId) then
        return
    end

    local staged = {}
    local ok, problem = pcall(function()
        for _, style in ipairs(Policy.Materials) do
            local variant = Instance.new("MaterialVariant")
            variant.Name = Policy.variantName(style.key)
            variant.BaseMaterial = Enum.Material[style.base]
            variant.StudsPerTile = style.tile
            local maps = Registry.materials[style.key]
            for _, channel in ipairs(Policy.Channels) do
                variant[channel] = "rbxassetid://" .. tostring(maps[channel])
            end
            table.insert(staged, variant)
        end
        for _, variant in ipairs(staged) do
            -- Duplicate variants with the same name/base are ambiguous.
            -- Fail closed rather than silently selecting another package.
            assert(MaterialService:FindFirstChild(variant.Name) == nil,
                "Conflicting IRON YARD world material")
        end
        for _, variant in ipairs(staged) do variant.Parent = MaterialService end
    end)
    if not ok then
        for _, variant in ipairs(staged) do variant:Destroy() end
        warn("[IRON YARD] World PBR material registration rejected; native fallback: "
            .. tostring(problem))
        return
    end
    ready = true
    -- CONFIGURED means validated numeric owner-owned asset references only,
    -- NOT a claim that images rendered on a particular Roblox device.
    Workspace:SetAttribute("IronYardWorldPbrStatus", "CONFIGURED")
end

function WorldPbr.apply(part, key)
    if not ready or not part or not part:IsA("BasePart") then return false end
    for _, style in ipairs(Policy.Materials) do
        if key == style.key and part.Material == Enum.Material[style.base] then
            part.MaterialVariant = Policy.variantName(key)
            -- MaterialVariant is not guaranteed to replicate to clients.
            -- Only an owner-verified, base-material-checked server path can
            -- label a collider for local visual assignment.
            part:SetAttribute("IronYardPbrMaterial", key)
            CollectionService:AddTag(part, "IronYardWorldPbr")
            return true
        end
    end
    return false
end

return WorldPbr
