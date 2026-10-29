-- NEON STRIKE - server-owned, original free-for-all arena match lifecycle.
-- Inspired by the clean mode/room separation visible in REA's public MIT FPS reference.
-- No proprietary Roblox game code, no external remotes, no persistence.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local BotService = require(script.Parent:WaitForChild("BotService"))
local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local WeaponService = require(script.Parent:WaitForChild("WeaponService"))
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
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
local lastPublishedSecond = nil

local function scoreFor(player)
    local stats = player:FindFirstChild("leaderstats")
    local eliminations = stats and stats:FindFirstChild("Eliminations")
    if eliminations and eliminations:IsA("IntValue") then
        return eliminations.Value
    end
    return 0
end

local lastStandingsPayload = nil

local function rankedStandings()
    local entries = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(entries, {
            name = player.DisplayName,
            eliminations = scoreFor(player),
            bot = false,
            userId = player.UserId,
            sortKey = player.UserId,
        })
    end
    for _, bot in ipairs(BotService.getScores()) do
        table.insert(entries, bot)
    end
    table.sort(entries, function(a, b)
        if a.eliminations ~= b.eliminations then
            return a.eliminations > b.eliminations
        end
        if a.bot ~= b.bot then return not a.bot end
        return a.sortKey < b.sortKey
    end)
    local standings = {}
    for i = 1, math.min(3, #entries) do
        local candidate = entries[i]
        standings[i] = {
            name = candidate.name,
            eliminations = candidate.eliminations,
            bot = candidate.bot,
            userId = candidate.userId,
        }
    end
    return HttpService:JSONEncode(standings)
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
    Workspace:SetAttribute("NeonMatchTimeLeft", remaining)
    Workspace:SetAttribute("NeonMatchScoreLimit", ELIMINATIONS_TO_WIN)
    publishStandings()
end

local function transition(nextPhase, seconds, result)
    phase = nextPhase
    winner = result or ""
    deadline = os.clock() + seconds
    lastPublishedSecond = nil
    publish(math.ceil(seconds))
end

local function leader()
    local best = -1
    local selectedName = nil
    local selectedPlayer = nil
    local tied = false
    for _, player in ipairs(Players:GetPlayers()) do
        local score = scoreFor(player)
        if score > best then
            best = score
            selectedName = player.DisplayName
            selectedPlayer = player
            tied = false
        elseif score == best then
            selectedPlayer = nil
            tied = true
        end
    end
    local botName, botScore, botsTied = BotService.getLeader()
    if botName and botScore > best then
        best = botScore
        selectedName = botName
        selectedPlayer = nil
        tied = botsTied
    elseif botName and botScore == best then
        tied = true
        selectedPlayer = nil
    end
    return selectedName, best, tied, selectedPlayer
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
    resetRoundScores()
    CombatAwards.resetRound()
    WeaponService.resetRound()
    BotService.resetRound()
    SpawnService.placePlayers()
    round += 1
    transition("LIVE", ROUND_SECONDS)
end

local function endRound()
    local name, topScore, tied, winningPlayer = leader()
    local result = "DRAW"
    if name and not tied and topScore > 0 then
        result = name
        -- Award victory to the actual Player reference, never to a matching
        -- display name (which is not unique and can be changed).
        if winningPlayer and winningPlayer.Parent then
            CombatAwards.recordVictory(winningPlayer)
        end
    end
    transition("RESULTS", RESULTS_SECONDS, result)
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
        local _, topScore = leader()
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
