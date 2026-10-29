local Players = game:GetService("Players")
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
local ScoreService = {}
local started = false

local function attachPlayer(player)
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
    local function watchCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Died:Connect(function()
                local deaths = stats:FindFirstChild("Deaths")
                if deaths then deaths.Value += 1 end
                CombatAwards.recordDeath(player)
            end)
        end
    end
    player.CharacterAdded:Connect(watchCharacter)
    if player.Character then task.defer(watchCharacter, player.Character) end
end

function ScoreService.start()
    if started then return end
    started = true
    Players.PlayerAdded:Connect(attachPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.defer(attachPlayer, player)
    end
end

return ScoreService
