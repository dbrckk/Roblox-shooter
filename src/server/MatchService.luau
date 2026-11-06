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
local MatchService = {}
local started = false

local COUNTDOWN_SECONDS = 6
local ROUND_SECONDS = 240
local RESULTS_SECONDS = 12
local ELIMINATIONS_TO_WIN = 15

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
    Workspace:SetAttribute("NeonMatchScoreLimit", ELIMINATIONS_TO_WIN)
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

local function startRound()
    if #Players:GetPlayers() == 0 then
        transition("WAITING", 0)
        return
    end
    finalResult = nil
    Workspace:SetAttribute("IronYardFinalStandings", "")
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
        local standings = currentStandings().standings
        local topScore = standings[1] and standings[1].eliminations or 0
        if topScore >= ELIMINATIONS_TO_WIN or remaining <= 0 then
            endRound()
        end
    elseif phase == "RESULTS" and remaining <= 0 then
        transition("COUNTDOWN", COUNTDOWN_SECONDS)
    end
end

function MatchService.start()
    if started then return end
    started = true
    transition("WAITING", 0)
    task.spawn(function()
        while true do
            tick()
            task.wait(0.20)
        end
    end)
end

return MatchService
