-- NEON STRIKE - server-owned, original free-for-all arena match lifecycle.
-- Inspired by the clean mode/room separation visible in REA's public MIT FPS reference.
-- No proprietary Roblox game code, no external remotes, no persistence.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local MapService = require(script.Parent:WaitForChild("MapService"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local DuelRoom = require(script.Parent:WaitForChild("DuelRoom"))
local DuelCombatState = require(script.Parent:WaitForChild("DuelCombatState"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local SupplyService = require(script.Parent:WaitForChild("SupplyService"))
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
local RoundStandings = require(script.Parent:WaitForChild("RoundStandings"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DuelSpawnPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelSpawnPlan"))
local DuelRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelRules"))
local MatchLobbyPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchLobbyPolicy"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local PrecisionNet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet"))
local PracticeMode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
local PracticeRange = require(script.Parent:WaitForChild("PracticeRange"))
local MatchService = {}
local started = false

local COUNTDOWN_SECONDS = 6
local ROUND_SECONDS = 240
local RESULTS_SECONDS = 12
local ELIMINATIONS_TO_WIN = 15
local DUEL_BOUT_SECONDS = 80
local DUEL_BREAK_SECONDS = 7
local duel = nil
local lastDuelArena = nil
local lobbyMode = DuelRoom.isDedicated and "DUEL" or "FFA"
local mode = lobbyMode

local phase = "WAITING"
local deadline = 0
local round = 0
local winner = ""
local winnerUserId = 0
local lastPublishedSecond = nil
local finalResult = nil

local function scoreFor(player)
    local stats = player:FindFirstChild("leaderstats")
    local eliminations = stats and stats:FindFirstChild("Eliminations")
    if eliminations and eliminations:IsA("IntValue") then
        return eliminations.Value
    end
    return 0
end

local lastStandingsPayload = nil

local function readyPlayers()
    local players = DuelRoom.players()
    if #players ~= DuelRoom.requiredPlayers() then return nil end
    for _, player in ipairs(players) do
        if PracticeMode.active(player) or player:GetAttribute("IronYardDuelReady") ~= true then return nil end
    end
    if not DuelRoom.isDedicated then
        table.sort(players, function(a, b) return a.UserId < b.UserId end)
    end
    return players
end

local function dedicatedRoster(players)
    return #players == DuelRoom.requiredPlayers() and not DuelRoom.isClosing()
end

local function duelParticipants()
    if not duel then return nil, nil end
    return duel.aPlayer, duel.bPlayer
end

local function duelPlayersIntact()
    if not duel then return false end
    local players = DuelRoom.players()
    if #duel.players == 2 then
        local a, b = duelParticipants()
        return a.Parent == Players and b.Parent == Players
            and DuelRules.sameParticipants(players, a, b)
    end
    if #players ~= #duel.players then return false end
    for _, player in ipairs(duel.players) do
        if player.Parent ~= Players or not table.find(players, player) then return false end
    end
    return true
end

local function duelRows()
    if not duel then return {} end
    return {
        {name=duel.aName, eliminations=duel.aWins, deaths=0,
            userId=duel.aId, bot=false, sortKey=duel.aId},
        {name=duel.bName, eliminations=duel.bWins, deaths=0,
            userId=duel.bId, bot=false, sortKey=duel.bId},
    }
end

local function publishDuelScores()
    Workspace:SetAttribute("IronYardDuelArena", duel and duel.arena or "")
    Workspace:SetAttribute("IronYardDuelPlayerA", duel and duel.aId or 0)
    Workspace:SetAttribute("IronYardDuelPlayerB", duel and duel.bId or 0)
    Workspace:SetAttribute("IronYardDuelPlayerA2", duel and duel.players[3] and duel.players[3].UserId or 0)
    Workspace:SetAttribute("IronYardDuelPlayerB2", duel and duel.players[4] and duel.players[4].UserId or 0)
    Workspace:SetAttribute("IronYardDuelScoreA", duel and duel.aWins or 0)
    Workspace:SetAttribute("IronYardDuelScoreB", duel and duel.bWins or 0)
    Workspace:SetAttribute("IronYardDuelBout", duel and duel.bouts or 0)
end

local function currentStandings()
    local entries = {}
    for _, player in ipairs(DuelRoom.players()) do
        if PracticeMode.active(player) then continue end
        local stats = player:FindFirstChild("leaderstats")
        local deaths = stats and stats:FindFirstChild("Deaths")
        table.insert(entries, {
            name = player.DisplayName,
            eliminations = scoreFor(player),
            deaths = deaths and deaths:IsA("IntValue") and deaths.Value or 0,
            bot = false,
            userId = player.UserId,
            sortKey = player.UserId,
        })
    end
    if duel then
        return RoundStandings.build(duelRows(), round)
    end
    for _, bot in ipairs(BotService.getScores()) do
        table.insert(entries, bot)
    end
    return RoundStandings.build(entries, round)
end

local function rankedStandings()
    -- Never recalculate the podium during RESULTS: late joins and departures
    -- cannot rewrite the winner or another player's final placement.
    local result = phase == "RESULTS" and finalResult or currentStandings()
    local topThree = {}
    for i = 1, math.min(3, #result.standings) do
        topThree[i] = result.standings[i]
    end
    return HttpService:JSONEncode(topThree)
end

local function publishStandings()
    local payload = rankedStandings()
    if payload ~= lastStandingsPayload then
        lastStandingsPayload = payload
        Workspace:SetAttribute("IronYardStandings", payload)
    end
end

local function publish(remaining)
    Workspace:SetAttribute("NeonMatchPhase", phase)
    Workspace:SetAttribute("NeonMatchRound", round)
    Workspace:SetAttribute("NeonMatchWinner", winner)
    Workspace:SetAttribute("IronYardWinnerUserId", winnerUserId)
    Workspace:SetAttribute("NeonMatchTimeLeft", remaining)
    Workspace:SetAttribute("NeonMatchScoreLimit", duel and DuelRules.WIN_LIMIT or ELIMINATIONS_TO_WIN)
    publishStandings()
end

local function transition(nextPhase, seconds, result, winningUserId)
    phase = nextPhase
    winner = result or ""
    winnerUserId = winningUserId or 0
    deadline = os.clock() + seconds
    lastPublishedSecond = nil
    publish(math.ceil(seconds))
end

local function resetRoundScores()
    for _, player in ipairs(Players:GetPlayers()) do
        local stats = player:FindFirstChild("leaderstats")
        if stats then
            for _, name in ipairs({ "Eliminations", "Deaths" }) do
                local value = stats:FindFirstChild(name)
                if value and value:IsA("IntValue") then
                    value.Value = 0
                end
            end
        end
    end
end

-- Anchors are owned by the current duel preparation only. Every exit,
-- including a disconnect, result, stale respawn or lobby change, releases
-- exactly those references. Never unanchor unrelated new characters.
local function releaseDuelPrep()
    if not duel or not duel.prep then return end
    for _, entry in ipairs(duel.prep) do
        if entry.root and entry.root.Parent and entry.root.Anchored then
            entry.root.Anchored = false
            entry.root.AssemblyLinearVelocity = Vector3.zero
            entry.root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    duel.prep = nil
end

local function endDuel(reason, winningSide)
    if not duel then return end
    DuelCombatState.clear()
    releaseDuelPrep()
    duel.liveCharacters = nil
    -- An abandoned duel may end with the winner on fewer bout points.
    -- Keep every real score, but give the verified surviving champion rank 1
    -- in the result card instead of contradicting the winner banner.
    local forfeitChampion = reason == "FORFEIT"
        and (winningSide == "A" and duel.aId
            or winningSide == "B" and duel.bId or nil) or nil
    local teams = #duel.players == 4
    local rows = duelRows()
    if teams then
        rows[1].name, rows[2].name = "TEAM A", "TEAM B"
        rows[1].sortKey, rows[2].sortKey = 1, 2
    end
    local snapshot = RoundStandings.build(rows, round, forfeitChampion)
    snapshot.mode = "DUEL"
    snapshot.arena = duel.arena
    snapshot.bouts = duel.bouts
    snapshot.reason = reason
    snapshot.winnerUserId = winningSide == "A" and duel.aId
        or winningSide == "B" and duel.bId or 0
    snapshot.winner = winningSide == "A" and rows[1].name
        or winningSide == "B" and rows[2].name or "DRAW"
    local winningIndex = winningSide == "A" and 1 or winningSide == "B" and 2 or nil
    if teams then
        snapshot.teams = {
            {duel.aId, duel.players[3].UserId},
            {duel.bId, duel.players[4].UserId},
        }
        snapshot.winnerTeam = winningIndex
    end
    finalResult = snapshot
    Workspace:SetAttribute("IronYardFinalStandings", HttpService:JSONEncode(snapshot))
    -- A forfeit or interrupted series never awards the victory bonus.
    if winningIndex and (reason == "SCORE_LIMIT" or reason == "BOUT_LIMIT") then
        for index = winningIndex, #duel.players, 2 do
            local winningPlayer = duel.players[index]
            if winningPlayer.Parent == Players then CombatAwards.recordVictory(winningPlayer) end
        end
    end
    transition("RESULTS", RESULTS_SECONDS, snapshot.winner,
        snapshot.winnerUserId)
end

local function startDuelBout()
    if not duel or not duelPlayersIntact() then return false end
    local players = duel.players
    local prep = {}
    for index, player in ipairs(players) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or root.Anchored or not humanoid or humanoid.Health <= 0 then return false end
        prep[index] = {character = character, root = root}
    end
    local placed
    if #players == 4 then
        placed = SpawnService.placeDuelTeams(players, duel.bouts + 1, duel.arena)
    else
        placed = SpawnService.placeDuelPair(players[1], players[2], duel.bouts + 1, duel.arena)
    end
    if not placed then return false end

    -- All anchors belong to this prep. Exceptions are recovered by the scheduler.
    duel.prep = prep
    for index, entry in ipairs(prep) do
        MovementService.resetDuelMovement(players[index])
        entry.root.AssemblyLinearVelocity = Vector3.zero
        entry.root.AssemblyAngularVelocity = Vector3.zero
        entry.root.Anchored = true
    end
    -- Retain the recovery deadline over repeated failed preparations.
    transition("DUEL_PREP", DuelRules.PREP_SECONDS)
    return true
end

-- An interrupted preparation must release every original root immediately.
-- Checking the original character generations prevents a late respawn
-- from inheriting the abandoned preparation.
local function duelPrepState()
    local prep = duel and duel.prep
    if type(prep) ~= "table" or #prep ~= #duel.players then return "INTERRUPTED" end
    local function liveAndAnchored(entry, character)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return type(entry) == "table" and character ~= nil and character == entry.character
            and entry.root ~= nil and entry.root.Parent ~= nil and entry.root.Anchored
            and entry.root:IsDescendantOf(character) and humanoid ~= nil and humanoid.Health > 0
    end
    if #duel.players == 2 then
        local a, b = duelParticipants()
        return DuelRules.prepState(prep, a.Character, liveAndAnchored(prep[1], a.Character),
            b.Character, liveAndAnchored(prep[2], b.Character))
    end
    for index, player in ipairs(duel.players) do
        if not liveAndAnchored(prep[index], player.Character) then return "INTERRUPTED" end
    end
    return "READY"
end

local function retryInterruptedDuelPrep()
    if not duel then return false end
    DuelCombatState.clear()
    releaseDuelPrep()
    duel.liveCharacters = nil
    -- Keep the original 20-second recovery budget, including repeated
    -- interrupted preparations; never start a new deadline on each retry.
    duel.waitSince = duel.waitSince or os.clock()
    transition("DUEL_BREAK", DUEL_BREAK_SECONDS)
    return false
end

local function startLiveDuelBout()
    if not duel or not duelPlayersIntact() then return false end
    if duelPrepState() ~= "READY" then
        return retryInterruptedDuelPrep()
    end
    local players = duel.players
    releaseDuelPrep()
    Workspace:SetAttribute("IronYardDuelLastResult", "")
    if not DuelCombatState.begin(table.unpack(players)) then
        return retryInterruptedDuelPrep()
    end
    WeaponService.resetRound()
    duel.liveCharacters = {}
    for index, player in ipairs(players) do
        local character = player.Character
        duel.liveCharacters[index] = character
        SpawnService.clearProtection(character)
        character:SetAttribute("IronYardLiveDuelEpoch", Workspace:GetAttribute("IronYardFireEpoch"))
    end
    duel.waitSince = nil
    duel.bouts += 1
    publishDuelScores()
    transition("LIVE", DUEL_BOUT_SECONDS)
    return true
end

local function startDuelSeries(players)
    local arena = DuelSpawnPlan.nextArena(lastDuelArena, game.JobId)
    MapService.prepareDuelArena(arena)
    lastDuelArena = arena
    DuelCombatState.clear()
    finalResult = nil
    Workspace:SetAttribute("IronYardFinalStandings", "")
    duel = {
        players=players, aPlayer=players[1], bPlayer=players[2],
        aId=players[1].UserId, bId=players[2].UserId,
        aName=players[1].DisplayName, bName=players[2].DisplayName,
        aWins=0, bWins=0, bouts=0, waitSince=os.clock(), arena=arena,
    }
    -- A rematch requires fresh consent from every original participant.
    for _, player in ipairs(players) do player:SetAttribute("IronYardDuelReady", false) end
    mode = "DUEL"
    Workspace:SetAttribute("IronYardMatchMode", mode)
    Workspace:SetAttribute("IronYardDuelLastResult", "")
    publishDuelScores()
    -- Clear every FFA bot synchronously before the first valid duel shot.
    BotService.reconcileNow()
    BotService.resetRound()
    resetRoundScores()
    CombatAwards.resetRound()
    SupplyService.resetRound()
    round += 1
    if not startDuelBout() then transition("DUEL_BREAK", 2) end
end

local function finishDuelBout(result)
    if not duel then return end
    DuelCombatState.clear()
    local a,b,n,complete,winner,finishReason=DuelRules.advance(
        duel.aWins,duel.bWins,duel.bouts-1,result)
    if not a then return end
    duel.aWins,duel.bWins = a,b
    Workspace:SetAttribute("IronYardDuelLastResult", result)
    -- DuelRules.advance counts resolved bouts. The currently started bout
    -- was already included in duel.bouts at spawn; never count it twice.
    duel.bouts = n
    publishDuelScores()
    duel.liveCharacters = nil
    if complete then
        endDuel(finishReason, winner)
    else
        duel.waitSince = os.clock()
        transition("DUEL_BREAK", DUEL_BREAK_SECONDS)
    end
end

local function startRound()
    local players = DuelRoom.players()
    if #players == 0 then
        transition("WAITING", 0)
        return
    end
    finalResult = nil
    Workspace:SetAttribute("IronYardFinalStandings", "")
    if DuelRoom.isDedicated then
        if dedicatedRoster(players) then
            startDuelSeries(players)
        else
            DuelRoom.returnPlayersToFfa(players)
            transition("WAITING", 0)
        end
        return
    end
    local candidates = DuelRoom.isLocal and readyPlayers()
    if candidates then
        startDuelSeries(candidates)
        return
    end
    DuelCombatState.clear()
    duel = nil
    mode = "FFA"
    Workspace:SetAttribute("IronYardMatchMode", mode)
    publishDuelScores()
    BotService.reconcileNow()
    resetRoundScores()
    CombatAwards.resetRound()
    WeaponService.resetRound()
    SupplyService.resetRound()
    BotService.resetRound()
    SpawnService.placePlayers()
    round += 1
    transition("LIVE", ROUND_SECONDS)
end

local function endRound()
    finalResult = currentStandings()
    -- Require a verified elimination in this completed FFA. Late arrivals
    -- without play and operators in the practice range cannot complete it.
    for _, player in ipairs(DuelRoom.players()) do
        if not PracticeMode.active(player) and scoreFor(player) > 0 then
            CombatAwards.recordFfaCompletion(player)
        end
    end
    -- One authoritative, self-contained snapshot for the whole lobby.
    -- Writing it BEFORE switching phases lets clients render a consistent
    -- podium even under delayed or reordered attribute replication.
    Workspace:SetAttribute("IronYardFinalStandings", HttpService:JSONEncode(finalResult))
    if finalResult.winnerUserId > 0 then
        local winningPlayer = Players:GetPlayerByUserId(finalResult.winnerUserId)
        if winningPlayer and winningPlayer.Parent then
            CombatAwards.recordVictory(winningPlayer)
        end
    end
    transition("RESULTS", RESULTS_SECONDS,
        finalResult.winner, finalResult.winnerUserId)
end

local function tick()
    if not DuelRoom.isDedicated and not DuelRoom.isLocal then DuelRoom.match() end
    local players = DuelRoom.players()
    local size = DuelRoom.requiredPlayers()
    if Workspace:GetAttribute("IronYardDuelSize") ~= size then
        Workspace:SetAttribute("IronYardDuelSize", size)
    end
    if DuelRoom.isDedicated and Workspace:GetAttribute("IronYardDuelArrivedCount") ~= #players then
        Workspace:SetAttribute("IronYardDuelArrivedCount", #players)
    end
    -- Last disconnect is not an abandoned 1v1 with a surviving winner.
    -- Clear stale duel mode and public RESULTS before the next player joins.
    if MatchLobbyPolicy.shouldReset(#players, phase, mode, duel ~= nil, lobbyMode) then
        DuelCombatState.clear()
        releaseDuelPrep()
        duel = nil
        mode = lobbyMode
        finalResult = nil
        Workspace:SetAttribute("IronYardMatchMode", mode)
        Workspace:SetAttribute("IronYardDuelLastResult", "")
        Workspace:SetAttribute("IronYardFinalStandings", "")
        publishDuelScores()
        transition("WAITING", 0)
        return
    end
    if #players == 0 then return end
    if duel and phase ~= "RESULTS" and not duelPlayersIntact() then
        local a,b = duelParticipants()
        -- Player object references remain truthy after disconnect. Only
        -- the original combatant still present in the live roster can win.
        local side = DuelRules.forfeitSide(players, a, b)
        if #duel.players == 4 then
            local missing = {}
            for index, participant in ipairs(duel.players) do
                if participant.Parent ~= Players or not table.find(players, participant) then
                    missing[index % 2] = true
                end
            end
            side = missing[0] and not missing[1] and "A" or missing[1] and not missing[0] and "B" or nil
        end
        endDuel(side and "FORFEIT" or "LOBBY_CHANGED", side)
        return
    end
    if phase == "WAITING" then
        local arrivalSeconds = DuelRoom.isDedicated and DuelRoom.arrivalSecondsLeft() or nil
        if DuelRoom.isDedicated and (not dedicatedRoster(players) or arrivalSeconds == 0) then
            if DuelRoom.isClosing() or arrivalSeconds == 0 then
                if lastPublishedSecond ~= 0 then
                    lastPublishedSecond = 0
                    publish(0)
                end
                DuelRoom.returnPlayersToFfa(players)
            elseif arrivalSeconds and arrivalSeconds ~= lastPublishedSecond then
                lastPublishedSecond = arrivalSeconds
                publish(arrivalSeconds)
            end
            return
        end
        transition("COUNTDOWN", COUNTDOWN_SECONDS)
        return
    end

    local remaining = math.max(0, math.ceil(deadline - os.clock()))
    if remaining ~= lastPublishedSecond then
        lastPublishedSecond = remaining
        publish(remaining)
    end

    if phase == "COUNTDOWN" then
        if DuelRoom.isDedicated and not dedicatedRoster(players) then
            DuelRoom.returnPlayersToFfa(players)
            transition("WAITING", 0)
        elseif remaining <= 0 then
            startRound()
        end
    elseif phase == "LIVE" then
        -- The two humans explicitly requested a duel; start now rather
        -- than forcing them to wait out the remainder of a four-minute FFA.
        if DuelRoom.isLocal and not duel and mode == "FFA" then
            local candidates = readyPlayers()
            if candidates then
                startDuelSeries(candidates)
                return
            end
        end
        if duel then
            local health, maximum = {}, {}
            for index, player in ipairs(duel.players) do
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                health[index], maximum[index] = DuelRules.healthForBout(
                    duel.liveCharacters[index], character,
                    humanoid and humanoid.Health or 0, humanoid and humanoid.MaxHealth or 100)
            end
            local expired = remaining <= 0
            local result
            if #duel.players == 4 then
                result = DuelRules.teamBoutWinner(health, maximum, expired)
            else
                result = DuelRules.boutWinner(health[1], maximum[1], health[2], maximum[2], expired)
            end
            if result then finishDuelBout(result) end
        else
            local standings = currentStandings().standings
            local topScore = standings[1] and standings[1].eliminations or 0
            if topScore >= ELIMINATIONS_TO_WIN or remaining <= 0 then
                endRound()
            end
        end
    elseif phase == "DUEL_PREP" then
        -- A dead/replaced character or unexpectedly missing prep must
        -- not leave the lobby hanging until the next matching deadline.
        if duelPrepState() ~= "READY" then
            retryInterruptedDuelPrep()
        elseif remaining <= 0 then
            startLiveDuelBout()
        end
    elseif phase == "DUEL_BREAK" and remaining <= 0 then
        if DuelRules.recoveryExpired(duel and duel.waitSince, os.clock()) then
            endDuel("SPAWN_TIMEOUT", nil)
        elseif not startDuelBout() then
            transition("DUEL_BREAK", 1)
        end
    elseif phase == "RESULTS" and remaining <= 0 then
        if DuelRoom.isDedicated then
            if duel and duel.returnStarted then return end
            local rematch = readyPlayers()
            if rematch and duelPlayersIntact() and dedicatedRoster(rematch) then
                DuelCombatState.clear()
                duel = nil
                publishDuelScores()
                transition("COUNTDOWN", COUNTDOWN_SECONDS)
            elseif duel then
                duel.returnStarted = true
                DuelRoom.returnPlayersToFfa(players)
            end
            return
        end
        DuelCombatState.clear()
        duel = nil
        mode = "FFA"
        Workspace:SetAttribute("IronYardMatchMode", mode)
        Workspace:SetAttribute("IronYardDuelLastResult", "")
        publishDuelScores()
        transition("COUNTDOWN", COUNTDOWN_SECONDS)
    end
end

local function setPractice(player, enabled, session)
    if not RemoteGuard.allow(player, "SetPracticeRange") then return end
    if typeof(enabled) ~= "boolean" or not PracticeMode.matches(player, session)
        or enabled == PracticeMode.active(player) then return end

    local function deny(reason)
        player:SetAttribute("IronYardPracticeNotice", reason)
    end
    if mode ~= "FFA" or DuelRoom.isDedicated then return deny("FFA ONLY") end
    if player:GetAttribute("IronYardDuelReady") == true
        or player:GetAttribute("IronYardDuelTravel") == "CONNECTING" then
        return deny("CANCEL DUEL SEARCH FIRST")
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or root.Anchored or not humanoid or humanoid.Health <= 0
        or not character:IsDescendantOf(Workspace) then
        return deny("WAIT FOR RESPAWN")
    end
    if enabled then
        if phase == "LIVE" and not WeaponService.canEnterPractice(player, character) then
            return deny("WAIT 5S AFTER COMBAT")
        end
        MovementService.resetDuelMovement(player)
        PracticeRange.enter(player, humanoid.Health, round)
        SpawnService.placeInPractice(player, character)
    else
        local room = PracticeRange.room(player)
        if not room or not SpawnService.place(player, character) then
            return deny("FFA SPAWN BUSY · RETRY")
        end
        if room.round == round then humanoid.Health = math.min(room.health, humanoid.MaxHealth) end
        MovementService.resetDuelMovement(player)
        PracticeRange.leave(player)
    end
    WeaponService.onPracticeChanged(player, enabled)
    player:SetAttribute("IronYardPracticeNotice", nil)
end

function MatchService.start()
    if started then return end
    started = true
    DuelCombatState.clear()
    DuelRoom.start()
    local remotes = PrecisionNet.getRemotes(true)
    remotes.SetPracticeRange.OnServerEvent:Connect(setPractice)
    remotes.ResetPracticeStats.OnServerEvent:Connect(function(player, session, revision)
        if RemoteGuard.allow(player, "ResetPracticeStats") then
            PracticeRange.resetStats(player, session, revision)
        end
    end)
    remotes.StartPracticeDrill.OnServerEvent:Connect(function(player, session, previousId)
        if not RemoteGuard.allow(player, "StartPracticeDrill") then return end
        local character = PracticeRange.startDrill(player, session, previousId)
        if not character then return end
        MovementService.resetDuelMovement(player)
        SpawnService.placeInPractice(player, character)
        WeaponService.refillPracticeMagazines(player)
    end)
    remotes.SetDuelReady.OnServerEvent:Connect(function(player, enabled, target, invitation, requestedRound, teamInvite)
        if not RemoteGuard.allow(player, "SetDuelReady") then return end
        if typeof(enabled) ~= "boolean" then return end
        if player.Parent ~= Players or PracticeMode.active(player) then return end
        if invitation ~= nil and (DuelRoom.isDedicated or DuelRoom.isLocal) then return end
        if DuelRoom.isDedicated then
            -- A delayed vote or cancellation belongs to the results that sent it.
            if phase == "RESULTS" and os.clock() < deadline
                and requestedRound == round and duel and not duel.returnStarted and duelPlayersIntact()
                and dedicatedRoster(DuelRoom.players())
                and table.find(duel.players, player) then
                player:SetAttribute("IronYardDuelReady", enabled)
            end
        elseif DuelRoom.isLocal then
            if enabled and (#Players:GetPlayers() > 2 or
                (duel ~= nil and phase ~= "RESULTS")) then return end
            player:SetAttribute("IronYardDuelReady", enabled)
        else
            DuelRoom.request(player, enabled, target, invitation, teamInvite)
        end
    end)
    remotes.ReturnToFfa.OnServerEvent:Connect(function(player, requestedPhase, requestedRound)
        if not RemoteGuard.allow(player, "ReturnToFfa") then return end
        if not DuelRoom.isDedicated or requestedRound ~= round then return end
        -- Opponent arrival can advance the lobby while the button press is in flight.
        -- Results are a separate decision and cannot close the next countdown.
        local fromLobby = requestedPhase == "WAITING" or requestedPhase == "COUNTDOWN"
        local inLobby = not duel and (phase == "WAITING" or phase == "COUNTDOWN")
        local fromCurrentResults = requestedPhase == "RESULTS" and phase == "RESULTS"
        if (fromLobby and inLobby) or fromCurrentResults then
            DuelRoom.returnToFfa(player, true)
        end
    end)
    Workspace:SetAttribute("IronYardDedicatedDuel", DuelRoom.isDedicated)
    Workspace:SetAttribute("IronYardDuelLocal", DuelRoom.isLocal)
    Workspace:SetAttribute("IronYardMatchMode", mode)
    Workspace:SetAttribute("IronYardDuelReadyCount", 0)
    Workspace:SetAttribute("IronYardDuelLastResult", "")
    publishDuelScores()
    transition("WAITING", 0)
    task.spawn(function()
        -- The match scheduler is a single long-lived task. An unexpected
        -- Roblox service exception must not permanently stop all rounds,
        -- timers and duel recovery for every player in this server.
        local consecutiveFailures = 0
        local lastWarningAt = -math.huge
        while started do
            local ok, err = pcall(function()
                local readyCount = 0
                for _, player in ipairs(DuelRoom.players()) do
                    if player:GetAttribute("IronYardDuelReady") == true then
                        readyCount += 1
                    end
                end
                if Workspace:GetAttribute("IronYardDuelReadyCount") ~= readyCount then
                    Workspace:SetAttribute("IronYardDuelReadyCount", readyCount)
                end
                tick()
            end)
            if ok then
                consecutiveFailures = 0
            else
                consecutiveFailures += 1
                local now = os.clock()
                if now - lastWarningAt >= 10 then
                    lastWarningAt = now
                    warn("[IRON YARD] Match scheduler failed; recovering: " .. tostring(err))
                end
                if consecutiveFailures >= 3 then
                    -- A partially executed duel can leave real players
                    -- anchored. Release ONLY the original duel prep roots,
                    -- discard stale bout state and resume an ordinary lobby.
                    -- Never award a win or reset player progression on error.
                    local recovered, recoveryErr = pcall(function()
                        DuelCombatState.clear()
                        releaseDuelPrep()
                        duel = nil
                        mode = lobbyMode
                        finalResult = nil
                        Workspace:SetAttribute("IronYardMatchMode", mode)
                        Workspace:SetAttribute("IronYardDuelLastResult", "")
                        Workspace:SetAttribute("IronYardFinalStandings", "")
                        publishDuelScores()
                        transition("WAITING", 0)
                    end)
                    if not recovered then
                        warn("[IRON YARD] Match recovery failed: " .. tostring(recoveryErr))
                    end
                    consecutiveFailures = 0
                end
            end
            -- A failing tick must still yield. No tight retry loop.
            task.wait(0.20)
        end
    end)
end

return MatchService
