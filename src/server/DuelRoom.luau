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
local REINVITE_DELAY = 30
local entries, order, pending, admitted = {}, {}, {}, {}
local reinviteAfter = {}
local leaving = {}
local closing = false
local expected
local started = false
local arrivalDeadline
local pairArrived = false
local rosterStore
local invitationSequence = 0

local function setState(player, state)
    if player.Parent == Players then player:SetAttribute("IronYardDuelTravel", state) end
end

local function clearRequest(player)
    entries[player] = nil
    local index = table.find(order, player)
    if index then table.remove(order, index) end
    if player.Parent == Players then
        player:SetAttribute("IronYardDuelSearchStartedAt", nil)
        player:SetAttribute("IronYardDuelOutgoingInvite", nil)
        player:SetAttribute("IronYardDuelReady", false)
    end
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

local function clearClosedInvitations(now, departingPlayer)
    for index = #order, 1, -1 do
        local player = order[index]
        local entry = entries[player]
        local target = entry.target
        if not target then continue end

        local state
        if now >= entry.expires then
            state = "INVITE_EXPIRED"
        elseif target == departingPlayer or target.Parent ~= Players then
            state = "INVITE_TARGET_LEFT"
        elseif pending[target] then
            state = "INVITE_TARGET_BUSY"
        else
            continue
        end
        clearRequest(player)
        setState(player, state)
    end
end

local function publishInvitations()
    local now = Workspace:GetServerTimeNow()
    local invitations = {}
    for _, player in ipairs(order) do
        local entry = entries[player]
        local target = entry.target
        if target and player.Parent == Players and entry.expires > now
            and not invitations[target] and not pending[target] then
            invitations[target] = entry.invitation
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local incoming = invitations[player]
        if player:GetAttribute("IronYardDuelInvitation") ~= incoming then
            player:SetAttribute("IronYardDuelInvitation", incoming)
        end
    end
end

local function reserve(first, second)
    clearRequest(first)
    clearRequest(second)
    local group = { first, second }
    local transfer = beginTransfer(group, "CONNECTING")
    clearClosedInvitations(Workspace:GetServerTimeNow())
    publishInvitations()
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

local function publishReinviteDeadlines(sender)
    local recipients = reinviteAfter[sender.UserId]
    local deadlines
    if recipients then
        deadlines = {}
        for recipientId, deadline in pairs(recipients) do
            deadlines[tostring(recipientId)] = deadline
        end
    end
    sender:SetAttribute("IronYardDuelReinviteDeadlines", deadlines and HttpService:JSONEncode(deadlines) or nil)
    if not recipients and sender:GetAttribute("IronYardDuelTravel") == "INVITE_COOLDOWN" then
        setState(sender, "")
    end
end

local function delayReinvite(sender, recipientId)
    local senderId = sender.UserId
    local recipients = reinviteAfter[senderId]
    if not recipients then
        recipients = {}
        reinviteAfter[senderId] = recipients
    end
    local expires = Workspace:GetServerTimeNow() + REINVITE_DELAY
    recipients[recipientId] = expires
    publishReinviteDeadlines(sender)
    task.delay(REINVITE_DELAY, function()
        if recipients[recipientId] ~= expires then return end
        recipients[recipientId] = nil
        if next(recipients) == nil then
            reinviteAfter[senderId] = nil
        end
        local currentSender = Players:GetPlayerByUserId(senderId)
        if currentSender then publishReinviteDeadlines(currentSender) end
    end)
end

function Room.request(player, enabled, target, invitation)
    if pending[player] then return end
    if invitation ~= nil and (target == nil or typeof(invitation) ~= "string") then return end
    if not enabled and invitation == nil then
        clearRequest(player)
        setState(player, "")
        return
    end
    local opponent
    if target ~= nil then
        if typeof(target) ~= "number" or target <= 0 or target >= 2^53 or target % 1 ~= 0 then return end
        opponent = Players:GetPlayerByUserId(target)
        if invitation ~= nil then
            local entry = opponent and entries[opponent]
            if entry and entry.target == player and not pending[opponent]
                and opponent.Parent == Players and Workspace:GetServerTimeNow() < entry.expires
                and entry.invitation == invitation then
                if enabled then
                    reserve(opponent, player)
                else
                    delayReinvite(opponent, player.UserId)
                    clearRequest(opponent)
                    setState(opponent, "INVITE_DECLINED")
                    publishInvitations()
                end
            end
            return
        end
        local recipients = reinviteAfter[player.UserId]
        local expires = recipients and recipients[target]
        if expires and Workspace:GetServerTimeNow() < expires then
            -- A blocked invitation leaves an existing search or request intact.
            if not entries[player] then setState(player, "INVITE_COOLDOWN") end
            return
        end
        if not opponent or opponent == player or pending[opponent] then
            clearRequest(player)
            setState(player, "UNAVAILABLE")
            return
        end
    end
    local previous = entries[player]
    local now = Workspace:GetServerTimeNow()
    if opponent and previous and previous.target == opponent and now < previous.expires then
        return
    end
    if not previous then table.insert(order, player) end
    local entry = { target = opponent }
    local outgoingInvite
    if opponent then
        invitationSequence += 1
        local expiryMillis = math.floor((now + INVITE_TIMEOUT) * 1000)
        entry.expires = expiryMillis / 1000
        -- Publish the identity and deadline together so the HUD never mixes two invitations.
        entry.invitation = string.format("%d:%d:%.0f", player.UserId, invitationSequence, expiryMillis)
        outgoingInvite = string.format("%d:%.0f", opponent.UserId, expiryMillis)
        player:SetAttribute("IronYardDuelSearchStartedAt", nil)
    elseif not previous or previous.target then
        player:SetAttribute("IronYardDuelSearchStartedAt", now)
    end
    entries[player] = entry
    player:SetAttribute("IronYardDuelOutgoingInvite", outgoingInvite)
    player:SetAttribute("IronYardDuelReady", true)
    setState(player, opponent and "INVITED" or "SEARCHING")
end

function Room.match()
    clearClosedInvitations(Workspace:GetServerTimeNow())
    local first, second = Queue.pair(entries, order, function(player)
        return player.Parent == Players and not pending[player]
    end)
    if first then
        reserve(first, second)
    else
        publishInvitations()
    end
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
    else
        Players.PlayerAdded:Connect(function(player)
            if reinviteAfter[player.UserId] then publishReinviteDeadlines(player) end
        end)
    end
    Players.PlayerRemoving:Connect(function(player)
        clearRequest(player)
        pending[player] = nil
        leaving[player] = nil
        if not Room.isDedicated then
            clearClosedInvitations(Workspace:GetServerTimeNow(), player)
            publishInvitations()
        end
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
