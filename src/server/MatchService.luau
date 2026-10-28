-- NEON STRIKE - server-owned, original free-for-all arena match lifecycle.
-- Inspired by the clean mode/room separation visible in REA's public MIT FPS reference.
-- No proprietary Roblox game code, no external remotes, no persistence.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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

local function publish(remaining)
    Workspace:SetAttribute("NeonMatchPhase", phase)
    Workspace:SetAttribute("NeonMatchRound", round)
    Workspace:SetAttribute("NeonMatchWinner", winner)
    Workspace:SetAttribute("NeonMatchTimeLeft", remaining)
    Workspace:SetAttribute("NeonMatchScoreLimit", ELIMINATIONS_TO_WIN)
end

local function transition(nextPhase, seconds, result)
    phase = nextPhase
    winner = result or ""
    deadline = os.clock() + seconds
    lastPublishedSecond = nil
    publish(math.ceil(seconds))
end

local function scoreFor(player)
    local stats = player:FindFirstChild("leaderstats")
    local eliminations = stats and stats:FindFirstChild("Eliminations")
    if eliminations and eliminations:IsA("IntValue") then
        return eliminations.Value
    end
    return 0
end

local function leader()
    local best = -1
    local selected = nil
    local tied = false
    for _, player in ipairs(Players:GetPlayers()) do
        local score = scoreFor(player)
        if score > best then
            best = score
            selected = player
            tied = false
        elseif score == best then
            tied = true
        end
    end
    return selected, best, tied
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

local startPositions = {
    Vector3.new(-132, 5, 139),
    Vector3.new(132, 5, 139),
    Vector3.new(-132, 5, -139),
    Vector3.new(132, 5, -139),
    Vector3.new(0, 5, 128),
    Vector3.new(0, 5, -135),
    Vector3.new(-80, 5, 144),
    Vector3.new(80, 5, -144),
}

local function positionPlayers()
    for index, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 and root then
            humanoid.Health = humanoid.MaxHealth
            local spot = startPositions[(index - 1) % #startPositions + 1]
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = CFrame.new(spot)
        end
    end
end

local function startRound()
    if #Players:GetPlayers() == 0 then
        transition("WAITING", 0)
        return
    end
    resetRoundScores()
    positionPlayers()
    round += 1
    transition("LIVE", ROUND_SECONDS)
end

local function endRound()
    local player, topScore, tied = leader()
    local result = "DRAW"
    if player and not tied and topScore > 0 then
        result = player.DisplayName
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
