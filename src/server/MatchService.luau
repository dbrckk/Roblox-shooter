-- NEON STRIKE - server-owned, original free-for-all arena match lifecycle.
-- Inspired by the clean mode/room separation visible in REA's public MIT FPS reference.
-- No proprietary Roblox game code, no external remotes, no persistence.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local BotService = require(script.Parent:WaitForChild("BotService"))
local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local SupplyService = require(script.Parent:WaitForChild("SupplyService"))
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
local RoundStandings = require(script.Parent:WaitForChild("RoundStandings"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DuelRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelRules"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local PrecisionNet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet"))
local MatchService = {}
local started = false

local COUNTDOWN_SECONDS = 6
local ROUND_SECONDS = 240
local RESULTS_SECONDS = 12
local ELIMINATIONS_TO_WIN = 15
local DUEL_BOUT_SECONDS = 80
local DUEL_BREAK_SECONDS = 7
local duel = nil
local mode = "FFA"

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
    local players = Players:GetPlayers()
    if #players ~= 2 then return nil end
    if DuelRules.canStart(#players,
        players[1]:GetAttribute("IronYardDuelReady"),
        players[2]:GetAttribute("IronYardDuelReady")) then
        table.sort(players, function(a,b) return a.UserId < b.UserId end)
        return players
    end
    return nil
end

local function duelParticipants()
    if not duel then return nil, nil end
    return Players:GetPlayerByUserId(duel.aId),
        Players:GetPlayerByUserId(duel.bId)
end

local function duelPlayersIntact()
    if not duel or #Players:GetPlayers() ~= 2 then return false end
    local a,b = duelParticipants()
    return a ~= nil and b ~= nil and a.Parent == Players and b.Parent == Players
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
    Workspace:SetAttribute("IronYardDuelPlayerA", duel and duel.aId or 0)
    Workspace:SetAttribute("IronYardDuelPlayerB", duel and duel.bId or 0)
    Workspace:SetAttribute("IronYardDuelScoreA", duel and duel.aWins or 0)
    Workspace:SetAttribute("IronYardDuelScoreB", duel and duel.bWins or 0)
    Workspace:SetAttribute("IronYardDuelBout", duel and duel.bouts or 0)
end

local function currentStandings()
    local entries = {}
    for _, player in ipairs(Players:GetPlayers()) do
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

local function endDuel(reason, winningSide)
    if not duel then return end
    local snapshot = RoundStandings.build(duelRows(), round)
    snapshot.mode = "DUEL"
    snapshot.bouts = duel.bouts
    snapshot.reason = reason
    snapshot.winnerUserId = winningSide == "A" and duel.aId
        or winningSide == "B" and duel.bId or 0
    snapshot.winner = winningSide == "A" and duel.aName
        or winningSide == "B" and duel.bName or "DRAW"
    finalResult = snapshot
    Workspace:SetAttribute("IronYardFinalStandings", HttpService:JSONEncode(snapshot))
    local winningPlayer = snapshot.winnerUserId > 0
        and Players:GetPlayerByUserId(snapshot.winnerUserId) or nil
    if winningPlayer then CombatAwards.recordVictory(winningPlayer) end
    transition("RESULTS", RESULTS_SECONDS, snapshot.winner,
        snapshot.winnerUserId)
end

local function startDuelBout()
    if not duel or not duelPlayersIntact() then return false end
    local a,b = duelParticipants()
    -- Characters are Roblox-owned. Wait for both real, living rigs after
    -- RespawnTime rather than spawning an unfair one-sided duel.
    local function alive(p)
        local c = p and p.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return c and h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart")
    end
    if not alive(a) or not alive(b) then return false end
    if not SpawnService.placeDuelPair(a,b,duel.bouts+1) then return false end
    WeaponService.resetRound()
    duel.bouts += 1
    publishDuelScores()
    transition("LIVE", DUEL_BOUT_SECONDS)
    return true
end

local function startDuelSeries(players)
    duel = {
        aId=players[1].UserId, bId=players[2].UserId,
        aName=players[1].DisplayName, bName=players[2].DisplayName,
        aWins=0, bWins=0, bouts=0,
    }
    mode = "DUEL"
    Workspace:SetAttribute("IronYardMatchMode", mode)
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
    local a,b,n,complete,winner=DuelRules.advance(
        duel.aWins,duel.bWins,duel.bouts-1,result)
    if not a then return end
    duel.aWins,duel.bWins = a,b
    -- DuelRules.advance counts resolved bouts. The currently started bout
    -- was already included in duel.bouts at spawn; never count it twice.
    duel.bouts = n
    publishDuelScores()
    if complete then
        endDuel("SCORE_LIMIT", winner)
    else
        transition("DUEL_BREAK", DUEL_BREAK_SECONDS)
    end
end

local function startRound()
    if #Players:GetPlayers() == 0 then
        transition("WAITING", 0)
        return
    end
    finalResult = nil
    Workspace:SetAttribute("IronYardFinalStandings", "")
    local candidates=readyPlayers()
    if candidates then
        startDuelSeries(candidates)
        return
    end
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
    if duel and phase ~= "RESULTS" and not duelPlayersIntact() then
        local a,b = duelParticipants()
        -- A third observer cancels the duel without gifting a victory.
        local side = #Players:GetPlayers() == 1
            and (a and "A" or b and "B" or nil) or nil
        endDuel(side and "FORFEIT" or "LOBBY_CHANGED", side)
        return
    end
    if #Players:GetPlayers() == 0 then
        if phase ~= "WAITING" then
            transition("WAITING", 0)
        end
        return
    end

    if phase == "WAITING" then
        transition("COUNTDOWN", COUNTDOWN_SECONDS)
        return
    end

    local remaining = math.max(0, math.ceil(deadline - os.clock()))
    if remaining ~= lastPublishedSecond then
        lastPublishedSecond = remaining
        publish(remaining)
    end

    if phase == "COUNTDOWN" then
        if remaining <= 0 then
            startRound()
        end
    elseif phase == "LIVE" then
        if duel then
            local a,b=duelParticipants()
            local function health(p)
                local c=p and p.Character
                local h=c and c:FindFirstChildOfClass("Humanoid")
                return h and h.Health or 0, h and h.MaxHealth or 100
            end
            local ah,am=health(a)
            local bh,bm=health(b)
            local result=DuelRules.boutWinner(ah,am,bh,bm,remaining<=0)
            if result then finishDuelBout(result) end
        else
            local standings = currentStandings().standings
            local topScore = standings[1] and standings[1].eliminations or 0
            if topScore >= ELIMINATIONS_TO_WIN or remaining <= 0 then
                endRound()
            end
        end
    elseif phase == "DUEL_BREAK" and remaining <= 0 then
        if not startDuelBout() then transition("DUEL_BREAK", 1) end
    elseif phase == "RESULTS" and remaining <= 0 then
        duel = nil
        mode = "FFA"
        Workspace:SetAttribute("IronYardMatchMode", mode)
        publishDuelScores()
        transition("COUNTDOWN", COUNTDOWN_SECONDS)
    end
end

function MatchService.start()
    if started then return end
    started = true
    local remotes = PrecisionNet.getRemotes(true)
    remotes.SetDuelReady.OnServerEvent:Connect(function(player, enabled)
        if not RemoteGuard.allow(player, "SetDuelReady") then return end
        if typeof(enabled) ~= "boolean" then return end
        if player.Parent ~= Players then return end
        player:SetAttribute("IronYardDuelReady", enabled)
    end)
    Workspace:SetAttribute("IronYardMatchMode", mode)
    Workspace:SetAttribute("IronYardDuelReadyCount", 0)
    publishDuelScores()
    transition("WAITING", 0)
    task.spawn(function()
        while true do
            local readyCount=0
            for _, player in ipairs(Players:GetPlayers()) do
                if player:GetAttribute("IronYardDuelReady")==true then
                    readyCount+=1
                end
            end
            if Workspace:GetAttribute("IronYardDuelReadyCount")~=readyCount then
                Workspace:SetAttribute("IronYardDuelReadyCount",readyCount)
            end
            tick()
            task.wait(0.20)
        end
    end)
end

return MatchService
