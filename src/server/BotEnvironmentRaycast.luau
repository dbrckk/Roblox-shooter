-- IRON YARD / one collision-safe terrain raycast filter per living bot.
-- Navigation and cover choose the same exclusions. Only rebuild the Roblox
-- filter list on a Player/Character roster change or a bot-folder replacement.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Policy = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("BotEnvironmentFilterPolicy"))

local Environment = {}
local generation = Policy.new()
local watchedPlayers = {}
local departing = setmetatable({}, { __mode = "k" })
local roster = {}
local rosterGeneration = -1

local function invalidateRoster()
    Policy.invalidate(generation)
end

local function watchPlayer(player)
    if watchedPlayers[player] then return end
    watchedPlayers[player] = {
        player.CharacterAdded:Connect(invalidateRoster),
        player.CharacterRemoving:Connect(invalidateRoster),
    }
    invalidateRoster()
end

local function unwatchPlayer(player)
    departing[player] = true
    local connections = watchedPlayers[player]
    if connections then
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        watchedPlayers[player] = nil
    end
    invalidateRoster()
end

local joinedConnection = Players.PlayerAdded:Connect(watchPlayer)
local leavingConnection = Players.PlayerRemoving:Connect(unwatchPlayer)
for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end

local function activeCharacters()
    if rosterGeneration == generation.generation then return roster end
    local current = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if not departing[player] then
            local character = player.Character
            if character then current[#current + 1] = character end
        end
    end
    roster = current
    rosterGeneration = generation.generation
    return current
end

function Environment.params(bot)
    local model = bot and bot.model
    if not model then return nil end
    local folder = Workspace:FindFirstChild("NeonStrikeBots")
    local version = generation.generation
    if not Policy.stale(bot.environmentRaycastParams,
        bot.environmentFilterGeneration, version,
        bot.environmentFilterModel, model,
        bot.environmentFilterFolder, folder) then
        return bot.environmentRaycastParams
    end

    local ignore = { model }
    if folder then ignore[#ignore + 1] = folder end
    for _, character in ipairs(activeCharacters()) do
        ignore[#ignore + 1] = character
    end

    local params = bot.environmentRaycastParams
    if not params then
        params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        params.RespectCanCollide = true
        bot.environmentRaycastParams = params
    end
    -- Roblox copies the filter list on assignment. Never mutate this list
    -- while a raycast is running; only replace on an observed generation.
    params.FilterDescendantsInstances = ignore
    bot.environmentFilterGeneration = version
    bot.environmentFilterModel = model
    bot.environmentFilterFolder = folder
    return params
end

-- The module is server-lifetime, but Studio teardown must not retain the
-- Player signals or the most recently observed character references.
script.Destroying:Connect(function()
    joinedConnection:Disconnect()
    leavingConnection:Disconnect()
    for player, connections in pairs(watchedPlayers) do
        for _, connection in ipairs(connections) do connection:Disconnect() end
        watchedPlayers[player] = nil
    end
    table.clear(roster)
end)

return Environment
