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
local PracticeMode = require(Shared:WaitForChild("PracticeMode"))

local Room = {}
Room.isLocal = RunService:IsStudio()
Room.isDedicated = not Room.isLocal and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local ROSTER_TTL = 120
local TRAVEL_TIMEOUT = 40
local TRAVEL_RETRY_DELAY = 1.5
local ARRIVAL_TIMEOUT = 40
local INVITE_TIMEOUT = 30
local REINVITE_DELAY = 30
local entries, order, pending, admitted = {}, {}, {}, {}
local reinviteAfter = {}
local leaving = {}
local returnOnly = {}
local closing = false
local expected
local started = false
local arrivalDeadline
local rosterArrived = false
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

local function leaveTeam(player, state)
    local entry = entries[player]
    local teammate = entry and entry.teammate
    clearRequest(player)
    if teammate and entries[teammate] and entries[teammate].teammate == player then
        clearRequest(teammate)
        setState(teammate, state)
    end
end

local function queueTeam(first, second, now)
    for _, player in ipairs({first, second}) do clearRequest(player) end
    for _, player in ipairs({first, second}) do
        local teammate = player == first and second or first
        entries[player] = { teammate = teammate, captain = first, startedAt = now }
        table.insert(order, player)
        player:SetAttribute("IronYardDuelSearchStartedAt", now)
        player:SetAttribute("IronYardDuelReady", true)
        setState(player, "TEAM_SEARCHING")
    end
end

local function finishTransfer(player, transfer, state)
    if pending[player] ~= transfer then return end
    pending[player] = nil
    setState(player, state)
end

local function beginTransfer(group, state)
    local transfer = {
        group = group,
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

local teleport

local function transferFailed(player, transfer, attempt)
    if pending[player] ~= transfer or transfer.attempts[player] ~= attempt then return end
    transfer.attempts[player] = nil
    if transfer.retries[player] then
        finishTransfer(player, transfer, "FAILED")
        return
    end
    transfer.retries[player] = true
    task.delay(TRAVEL_RETRY_DELAY, function()
        if pending[player] == transfer and player.Parent == Players then
            teleport({ player }, transfer)
        end
    end)
end

teleport = function(group, transfer)
    -- Each TeleportAsync call has its own identity, even for a retry to
    -- the same room. A delayed failure from the previous call is stale.
    local attempt = HttpService:GenerateGUID(false)
    for _, player in ipairs(group) do transfer.attempts[player] = attempt end
    local options = Instance.new("TeleportOptions")
    if transfer.code then options.ReservedServerAccessCode = transfer.code end
    options:SetTeleportData({ ironYardTransfer = attempt })
    local ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, group, options)
    if not ok then
        for _, player in ipairs(group) do
            transferFailed(player, transfer, attempt)
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
        elseif pending[target] or PracticeMode.active(target) or (entries[target] and entries[target].teammate) then
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
            and not invitations[target] and not pending[target] and not PracticeMode.active(target) then
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

local function reserve(group)
    local ids = {}
    for index, player in ipairs(group) do
        ids[index] = player.UserId
        clearRequest(player)
    end
    local transfer = beginTransfer(group, "CONNECTING")
    clearClosedInvitations(Workspace:GetServerTimeNow())
    publishInvitations()
    local function groupIntact()
        for _, player in ipairs(group) do
            if pending[player] ~= transfer or player.Parent ~= Players then return false end
        end
        return true
    end
    task.spawn(function()
        local ok, code = pcall(function()
            local reservedCode, serverId = TeleportService:ReserveServerAsync(game.PlaceId)
            if not groupIntact() then return nil end
            local saved = rosterStore:SetAsync(serverId, ids, ROSTER_TTL)
            if saved ~= true then return nil end
            return reservedCode
        end)
        if not ok or not code or not groupIntact() then
            for _, player in ipairs(group) do finishTransfer(player, transfer, "FAILED") end
            return
        end
        transfer.code = code
        teleport(group, transfer)
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

function Room.request(player, enabled, target, invitation, teamInvite)
    if pending[player] or player.Parent ~= Players or PracticeMode.active(player) then return end
    if teamInvite ~= nil and (teamInvite ~= true or not enabled or target == nil or invitation ~= nil) then return end
    if invitation ~= nil and (target == nil or typeof(invitation) ~= "string") then return end
    if not enabled and invitation == nil then
        leaveTeam(player, "TEAM_CANCELLED")
        setState(player, "")
        return
    end
    if entries[player] and entries[player].teammate then return end
    local opponent
    if target ~= nil then
        if typeof(target) ~= "number" or target <= 0 or target >= 2^53 or target % 1 ~= 0 then return end
        opponent = Players:GetPlayerByUserId(target)
        if invitation ~= nil then
            local entry = opponent and entries[opponent]
            if entry and entry.target == player and not pending[opponent]
                and opponent.Parent == Players and Workspace:GetServerTimeNow() < entry.expires
                and not PracticeMode.active(opponent) and entry.invitation == invitation then
                if enabled then
                    if entry.teamInvite then
                        queueTeam(opponent, player, Workspace:GetServerTimeNow())
                        clearClosedInvitations(Workspace:GetServerTimeNow())
                        publishInvitations()
                    else
                        reserve({opponent, player})
                    end
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
        if not opponent or opponent == player or pending[opponent] or PracticeMode.active(opponent)
            or (entries[opponent] and entries[opponent].teammate) then
            clearRequest(player)
            setState(player, "UNAVAILABLE")
            return
        end
    end
    local previous = entries[player]
    local now = Workspace:GetServerTimeNow()
    if opponent and previous and previous.target == opponent and previous.teamInvite == teamInvite and now < previous.expires then
        return
    end
    if not previous then table.insert(order, player) end
    local entry = { target = opponent, teamInvite = teamInvite }
    local outgoingInvite
    if opponent then
        invitationSequence += 1
        local expiryMillis = math.floor((now + INVITE_TIMEOUT) * 1000)
        entry.expires = expiryMillis / 1000
        -- Publish the identity and deadline together so the HUD never mixes two invitations.
        entry.invitation = string.format("%d:%d:%.0f", player.UserId, invitationSequence, expiryMillis)
        outgoingInvite = string.format("%d:%.0f", opponent.UserId, expiryMillis)
        if teamInvite then
            entry.invitation ..= ":2"
            outgoingInvite ..= ":2"
        end
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
    local function available(player)
        return player.Parent == Players and not pending[player] and not PracticeMode.active(player)
    end
    local first, second = Queue.pair(entries, order, available)
    if first then reserve({first, second}) end

    local a
    for _, player in ipairs(order) do
        local entry = entries[player]
        if entry.captain == player and available(player) and available(entry.teammate) then
            if a then
                local now = Workspace:GetServerTimeNow()
                print(string.format("[IRON YARD] 2v2 matched; team queue seconds %.1f / %.1f",
                    now - entries[a].startedAt, now - entry.startedAt))
                -- The roster alternates teams A, B, A, B through every rematch.
                reserve({a, player, entries[a].teammate, entry.teammate})
                break
            end
            a = player
        end
    end
    publishInvitations()
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

function Room.requiredPlayers()
    return expected and #expected or 2
end

function Room.arrivalSecondsLeft()
    if rosterArrived or not arrivalDeadline then return nil end
    return math.max(0, math.ceil(arrivalDeadline - os.clock()))
end

function Room.returnToFfa(player, retryRequested)
    local isCombatant = admitted[player.UserId] == player
    if not Room.isDedicated or player.Parent ~= Players or pending[player]
        or (not isCombatant and not returnOnly[player]) then return end
    if leaving[player] and not retryRequested then return end
    -- A room that starts sending players back cannot start a new duel.
    -- Failed transfers can be retried explicitly without reopening it.
    leaving[player] = true
    if isCombatant and not closing then
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

local function validRoster(roster)
    if type(roster) ~= "table" or (#roster ~= 2 and #roster ~= 4) then return false end
    local seen = {}
    for index = 1, #roster do
        local id = roster[index]
        if type(id) ~= "number" or not (id > 0 and id < 2^53 and id % 1 == 0)
            or seen[id] then return false end
        seen[id] = true
    end
    return true
end

local function admit(player)
    local expires = os.clock() + 12
    while player.Parent == Players and not expected and os.clock() < expires do
        local ok, roster = pcall(rosterStore.GetAsync, rosterStore, game.PrivateServerId)
        if not expected and ok and validRoster(roster) then expected = roster end
        if not expected then task.wait(1) end
    end
    if player.Parent ~= Players then return end
    if not expected then
        -- A roster outage permits a public return without admitting anyone to combat.
        returnOnly[player] = true
        Room.returnToFfa(player)
        return
    end
    if not table.find(expected, player.UserId) then
        player:Kick("Unable to verify this duel room. Rejoin IRON YARD to play FFA.")
        return
    end
    admitted[player.UserId] = player
    local now = os.clock()
    arrivalDeadline = arrivalDeadline or now + ARRIVAL_TIMEOUT
    if now < arrivalDeadline and Room.combatantCount() == #expected then
        rosterArrived = true
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
        leaveTeam(player, "TEAM_PARTNER_LEFT")
        local transfer = pending[player]
        pending[player] = nil
        leaving[player] = nil
        returnOnly[player] = nil
        if not Room.isDedicated then
            -- Once teleport is dispatched, departure can be a successful transfer.
            if transfer and not transfer.code then
                for _, partner in ipairs(transfer.group) do
                    finishTransfer(partner, transfer, "DUEL_PARTNER_LEFT")
                end
            end
            clearClosedInvitations(Workspace:GetServerTimeNow(), player)
            publishInvitations()
        end
        if admitted[player.UserId] == player then
            admitted[player.UserId] = nil
            rosterArrived = false
        end
    end)
    TeleportService.TeleportInitFailed:Connect(function(player, _, _, placeId, options)
        local transfer = pending[player]
        if not transfer or not options or placeId ~= game.PlaceId then return end
        local attempt = transfer.attempts[player]
        if not attempt then return end
        local data = options:GetTeleportData()
        if type(data) ~= "table" or data.ironYardTransfer ~= attempt then return end
        transferFailed(player, transfer, attempt)
    end)
end

return Room
