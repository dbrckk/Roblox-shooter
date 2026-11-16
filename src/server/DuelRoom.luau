-- Public lobbies pair consenting players, then hand them to a Roblox
-- reserved server of this same place. Only the server-side roster admits
-- players at the destination. Transfer data only correlates failure events.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Queue = require(Shared:WaitForChild("DuelQueue"))

local Room = {}
Room.isLocal = RunService:IsStudio()
Room.isDedicated = not Room.isLocal and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local ROSTER_TTL = 120
local TRAVEL_TIMEOUT = 40
local ARRIVAL_TIMEOUT = 40
local INVITE_TIMEOUT = 30
local entries, order, pending, admitted = {}, {}, {}, {}
local leaving = {}
local closing = false
local expected
local started = false
local arrivalDeadline
local pairArrived = false
local rosterStore

local function setState(player, state)
    if player.Parent == Players then player:SetAttribute("IronYardDuelTravel", state) end
end

local function clearRequest(player)
    entries[player] = nil
    local index = table.find(order, player)
    if index then table.remove(order, index) end
    if player.Parent == Players then player:SetAttribute("IronYardDuelReady", false) end
end

local function finishTransfer(player, transfer, state)
    if pending[player] ~= transfer then return end
    pending[player] = nil
    setState(player, state)
end

local function beginTransfer(group, state)
    local transfer = {
        attempts = {},
        retries = {},
    }
    for _, player in ipairs(group) do
        pending[player] = transfer
        setState(player, state)
    end
    task.delay(TRAVEL_TIMEOUT, function()
        for _, player in ipairs(group) do finishTransfer(player, transfer, "FAILED") end
    end)
    return transfer
end

local function teleport(group, transfer, code)
    -- Each TeleportAsync call has its own identity, even for a retry to
    -- the same room. A delayed failure from the previous call is stale.
    local attempt = HttpService:GenerateGUID(false)
    for _, player in ipairs(group) do transfer.attempts[player] = attempt end
    local options = Instance.new("TeleportOptions")
    if code then options.ReservedServerAccessCode = code end
    options:SetTeleportData({ ironYardTransfer = attempt })
    local ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, group, options)
    if not ok then
        for _, player in ipairs(group) do
            if transfer.attempts[player] == attempt then
                finishTransfer(player, transfer, "FAILED")
            end
        end
    end
end

local function reserve(first, second)
    clearRequest(first)
    clearRequest(second)
    local group = { first, second }
    local transfer = beginTransfer(group, "CONNECTING")
    task.spawn(function()
        local ok, code = pcall(function()
            local reservedCode, serverId = TeleportService:ReserveServerAsync(game.PlaceId)
            local saved = rosterStore:SetAsync(serverId, { first.UserId, second.UserId }, ROSTER_TTL)
            if saved ~= true then return nil end
            return reservedCode
        end)
        if not ok or not code or pending[first] ~= transfer or pending[second] ~= transfer
            or first.Parent ~= Players or second.Parent ~= Players then
            for _, player in ipairs(group) do finishTransfer(player, transfer, "FAILED") end
            return
        end
        transfer.code = code
        teleport(group, transfer, code)
    end)
end

local function updateInvitations()
    local now = os.clock()
    for index = #order, 1, -1 do
        local player = order[index]
        local entry = entries[player]
        if entry.target and (entry.target.Parent ~= Players or now >= entry.expires) then
            clearRequest(player)
            setState(player, "INVITE_EXPIRED")
        end
    end
    local invitations = {}
    for _, player in ipairs(order) do
        local target = entries[player].target
        if target and not invitations[target] and not pending[target] then
            invitations[target] = player.UserId
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local incoming = invitations[player]
        if player:GetAttribute("IronYardDuelInvitation") ~= incoming then
            player:SetAttribute("IronYardDuelInvitation", incoming)
        end
    end
end

function Room.request(player, enabled, target)
    if pending[player] then return end
    if not enabled then
        clearRequest(player)
        setState(player, "")
        return
    end
    local opponent
    if target ~= nil then
        if typeof(target) ~= "number" or target <= 0 or target >= 2^53 or target % 1 ~= 0 then return end
        opponent = Players:GetPlayerByUserId(target)
        if not opponent or opponent == player or pending[opponent] then
            clearRequest(player)
            setState(player, "UNAVAILABLE")
            return
        end
    end
    if not entries[player] then table.insert(order, player) end
    entries[player] = { target = opponent, expires = os.clock() + INVITE_TIMEOUT }
    player:SetAttribute("IronYardDuelReady", true)
    setState(player, opponent and "INVITED" or "SEARCHING")
end

function Room.match()
    updateInvitations()
    local first, second = Queue.pair(entries, order, function(player)
        return player.Parent == Players and not pending[player]
    end)
    if first then reserve(first, second) end
end

function Room.players()
    if not Room.isDedicated then return Players:GetPlayers() end
    local group = {}
    if not expected then return group end
    for _, id in ipairs(expected) do
        local player = admitted[id]
        if player and player.Parent == Players then table.insert(group, player) end
    end
    return group
end

function Room.combatantCount()
    if not Room.isDedicated then return #Players:GetPlayers() end
    local count = 0
    for _, player in pairs(admitted) do
        if player.Parent == Players then count += 1 end
    end
    return count
end

function Room.arrivalSecondsLeft()
    if pairArrived or not arrivalDeadline then return nil end
    return math.max(0, math.ceil(arrivalDeadline - os.clock()))
end

function Room.returnToFfa(player, retryRequested)
    if not Room.isDedicated or admitted[player.UserId] ~= player
        or player.Parent ~= Players or pending[player] then return end
    if leaving[player] and not retryRequested then return end
    -- A room that starts sending players back cannot start a new duel.
    -- Failed transfers can be retried explicitly without reopening it.
    leaving[player] = true
    if not closing then
        closing = true
        Workspace:SetAttribute("IronYardDuelExitStarted", true)
    end
    player:SetAttribute("IronYardDuelReady", false)
    local group = { player }
    local transfer = beginTransfer(group, "RETURNING")
    task.spawn(teleport, group, transfer)
end

function Room.isClosing()
    return closing
end

local function admit(player)
    local expires = os.clock() + 12
    while player.Parent == Players and not expected and os.clock() < expires do
        local ok, roster = pcall(rosterStore.GetAsync, rosterStore, game.PrivateServerId)
        if ok and type(roster) == "table" and #roster == 2
            and type(roster[1]) == "number" and type(roster[2]) == "number"
            and roster[1] ~= roster[2] then expected = roster end
        if not expected then task.wait(1) end
    end
    if player.Parent ~= Players then return end
    if not expected or not table.find(expected, player.UserId) then
        player:Kick("Unable to verify this 1v1 room. Rejoin IRON YARD to play FFA.")
        return
    end
    admitted[player.UserId] = player
    local now = os.clock()
    arrivalDeadline = arrivalDeadline or now + ARRIVAL_TIMEOUT
    local first, second = admitted[expected[1]], admitted[expected[2]]
    if now < arrivalDeadline and first and first.Parent == Players
        and second and second.Parent == Players then
        pairArrived = true
    end
end

function Room.start()
    if started or Room.isLocal then return end
    started = true
    rosterStore = MemoryStoreService:GetHashMap("IronYardDuelRoomsV1")
    if Room.isDedicated then
        Players.PlayerAdded:Connect(admit)
        for _, player in ipairs(Players:GetPlayers()) do task.spawn(admit, player) end
    end
    Players.PlayerRemoving:Connect(function(player)
        clearRequest(player)
        pending[player] = nil
        leaving[player] = nil
        if admitted[player.UserId] == player then
            admitted[player.UserId] = nil
            pairArrived = false
        end
    end)
    TeleportService.TeleportInitFailed:Connect(function(player, _, _, placeId, options)
        local transfer = pending[player]
        if not transfer or not options or placeId ~= game.PlaceId then return end
        local attempt = transfer.attempts[player]
        if not attempt then return end
        local data = options:GetTeleportData()
        if type(data) ~= "table" or data.ironYardTransfer ~= attempt then return end
        transfer.attempts[player] = nil
        if transfer.retries[player] then
            finishTransfer(player, transfer, "FAILED")
            return
        end
        transfer.retries[player] = true
        task.delay(1.5, function()
            if pending[player] == transfer and player.Parent == Players then
                teleport({ player }, transfer, transfer.code)
            end
        end)
    end)
end

return Room
