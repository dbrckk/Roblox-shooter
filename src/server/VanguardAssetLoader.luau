-- IRON YARD / optional owner-controlled PBR asset delivery.
-- The game never downloads or executes scripts from uploaded Model packages:
-- it selects only seven MeshParts with expected names from each package.
-- Without complete uploaded assets, procedural VANGUARD stays playable.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VanguardAssetIds"))

local VanguardAssetLoader = {}
local started = false
local COLORS = { "olive", "sand", "slate", "rust" }
local PIECES = { "torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "rifle" }

local function normalize(name)
    return string.lower(name):gsub("[^a-z0-9]", "")
end

local function pieceName(name)
    local n = normalize(name)
    for _, piece in ipairs(PIECES) do
        local normalized = normalize(piece)
        if n == normalized or n == "vanguard" .. normalized
            or n:find("vanguard" .. normalized, 1, true) then
            return piece
        end
    end
    return nil
end

local function extractPackage(owner, palette)
    local id = AssetIds.paletteModelIds[palette]
    assert(typeof(id) == "number" and id > 0 and id % 1 == 0,
        "Missing uploaded VANGUARD model asset ID: " .. palette)
    local loaded = InsertService:LoadAsset(id)
    assert(loaded and loaded:IsA("Model"), "Roblox asset is not a Model package")
    local selected = {}
    -- Imported GLB package may contain nested Model instances. Only meshes
    -- matching the original 7-part inventory are copied; no scripts, props
    -- or creator-uploaded code can enter the playable game.
    for _, item in ipairs(loaded:GetDescendants()) do
        if item:IsA("MeshPart") then
            local name = pieceName(item.Name)
            if name then
                assert(selected[name] == nil, "Duplicate imported mesh " .. name)
                assert(item.MeshId ~= "", "Empty imported mesh data: " .. name)
                assert(item:FindFirstChildOfClass("SurfaceAppearance") ~= nil,
                    "Missing embedded PBR SurfaceAppearance on " .. name)
                selected[name] = item
            end
        end
    end
    for _, name in ipairs(PIECES) do
        assert(selected[name] ~= nil, "Missing imported VANGUARD mesh " .. name)
    end
    local paletteFolder = Instance.new("Folder")
    paletteFolder.Name = palette
    for _, name in ipairs(PIECES) do
        local clone = selected[name]:Clone()
        clone.Name = name
        clone.Anchored = false
        clone.Massless = true
        clone.CanCollide = false
        clone.CanTouch = false
        clone.CanQuery = false
        clone.Parent = paletteFolder
    end
    loaded:Destroy()
    paletteFolder.Parent = owner
end

function VanguardAssetLoader.start()
    if started then return end
    started = true
    Workspace:SetAttribute("IronYardPbrTemplatesLoaded", false)

    -- Preserve manually imported Studio templates; never overwrite user work.
    if ServerStorage:FindFirstChild("VanguardTemplates") then
        return
    end
    if typeof(AssetIds) ~= "table" or typeof(AssetIds.paletteModelIds) ~= "table" then
        warn("[IRON YARD] Missing VANGUARD asset registry; using procedural visuals")
        return
    end
    if game.CreatorType ~= Enum.CreatorType.User or game.CreatorId ~= AssetIds.ownerUserId then
        -- Foreign/group experiences must not load another user's assets.
        return
    end
    for _, palette in ipairs(COLORS) do
        local id = AssetIds.paletteModelIds[palette]
        if typeof(id) ~= "number" or id <= 0 then return end
    end

    local staging = Instance.new("Folder")
    staging.Name = "_VanguardTemplatesStaging"
    local success, message = pcall(function()
        for _, palette in ipairs(COLORS) do
            extractPackage(staging, palette)
        end
    end)
    if not success then
        staging:Destroy()
        warn("[IRON YARD] Imported VANGUARD models are incomplete; procedural fallback: "
            .. tostring(message))
        return
    end

    staging.Name = "VanguardTemplates"
    staging.Parent = ServerStorage
    Workspace:SetAttribute("IronYardPbrTemplatesLoaded", true)
    print("[IRON YARD] Loaded 28 owner-controlled PBR MeshParts across four palettes.")
end

return VanguardAssetLoader
