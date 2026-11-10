-- IRON YARD / server-owned scoring with per-character event lifetimes.
-- Asynchronous replication must never let an old Humanoid count a death
-- in a later life, round, or after the player leaves.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
local Life = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("PlayerDeathLifecycle"))
local ScoreService = {}
local started = false
local playerBindings = {}

local function retireCharacter(state, character)
    if state.deathConnection then
        state.deathConnection:Disconnect()
        state.deathConnection = nil
    end
    Life.retire(state.life, character)
end

local function releasePlayer(player)
    local state = playerBindings[player]
    if not state then return end
    playerBindings[player] = nil
    if state.characterAdded then state.characterAdded:Disconnect() end
    if state.characterRemoving then state.characterRemoving:Disconnect() end
    retireCharacter(state, state.life.character)
end

local function attachPlayer(player)
    if player.Parent ~= Players or playerBindings[player] then return end
    local stats = player:FindFirstChild("leaderstats")
    if not stats then
        stats = Instance.new("Folder")
        stats.Name = "leaderstats"
        stats.Parent = player
    end
    for _, name in ipairs({"Eliminations", "Deaths"}) do
        if not stats:FindFirstChild(name) then
            local value = Instance.new("IntValue")
            value.Name = name
            value.Parent = stats
        end
    end

    local state = { life = Life.new(), deathConnection = nil }
    playerBindings[player] = state

    local function watchCharacter(character)
        if playerBindings[player] ~= state or player.Character ~= character
            or state.life.character == character then return end
        retireCharacter(state, state.life.character)
        local generation = Life.bind(state.life, character)
        task.spawn(function()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
                or character:WaitForChild("Humanoid", 10)
            if not humanoid or humanoid.Parent ~= character
                or player.Parent ~= Players or playerBindings[player] ~= state
                or not Life.bindHumanoid(state.life, generation, character,
                    humanoid, player.Character) then return end

            local function onDeath()
                if not Life.recordDeath(state.life, generation, character,
                    humanoid, player.Character,
                    Workspace:GetAttribute("NeonMatchPhase") == "LIVE") then
                    return
                end
                -- leaderstats can be replaced between rounds. Resolve the
                -- active container at the moment of a legitimate death.
                local currentStats = player:FindFirstChild("leaderstats")
                local deaths = currentStats and currentStats:FindFirstChild("Deaths")
                if deaths and deaths:IsA("IntValue") then
                    deaths.Value += 1
                end
                CombatAwards.recordDeath(player)
            end
            state.deathConnection = humanoid.Died:Connect(onDeath)
            -- Catch death before WaitForChild resolved, at most once.
            if humanoid.Health <= 0 then onDeath() end
        end)
    end

    state.characterAdded = player.CharacterAdded:Connect(watchCharacter)
    state.characterRemoving = player.CharacterRemoving:Connect(function(character)
        if state.life.character == character then retireCharacter(state, character) end
    end)
    if player.Character then task.defer(watchCharacter, player.Character) end
end

function ScoreService.start()
    if started then return end
    started = true
    Players.PlayerAdded:Connect(attachPlayer)
    Players.PlayerRemoving:Connect(releasePlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.defer(attachPlayer, player)
    end
end

return ScoreService
