-- NEON STRIKE / server-owned player spawning, tactical safety and short spawn shield.
-- A candidate must be clear of physical cover and far from live combatants.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SpawnService = {}
local started = false
local rng = Random.new()
local SPAWN_SHIELD_SECONDS = 2.5

-- Ground is at y=0. All positions are near stable, unobstructed lanes.
local candidates = {
    Vector3.new(-144, 3.4, 145),
    Vector3.new(144, 3.4, 145),
    Vector3.new(-144, 3.4, -144),
    Vector3.new(144, 3.4, -144),
    Vector3.new(-70, 3.4, 145),
    Vector3.new(70, 3.4, 145),
    Vector3.new(-70, 3.4, -145),
    Vector3.new(70, 3.4, -145),
    Vector3.new(0, 3.4, 140),
    Vector3.new(0, 3.4, -142),
    Vector3.new(-145, 3.4, 16),
    Vector3.new(145, 3.4, 16),
}

local function livePositions(excludeCharacter)
    local positions = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character ~= excludeCharacter then
            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                table.insert(positions, root.Position)
            end
        end
    end
    local bots = Workspace:FindFirstChild("NeonStrikeBots")
    if bots then
        for _, model in ipairs(bots:GetChildren()) do
            local root = model:FindFirstChild("HumanoidRootPart")
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                table.insert(positions, root.Position)
            end
        end
    end
    return positions
end

local function clearAt(position, character)
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = { character }
    overlap.RespectCanCollide = true
    overlap.MaxParts = 1
    -- Search starts above the floor; the arena base is not an obstacle.
    return #Workspace:GetPartBoundsInBox(
        CFrame.new(position + Vector3.new(0, 1, 0)),
        Vector3.new(4.2, 5.3, 4.2),
        overlap
    ) == 0
end

local function safestPosition(character)
    local others = livePositions(character)
    local best, bestScore = nil, -math.huge
    for _, position in ipairs(candidates) do
        if clearAt(position, character) then
            local minimum = 200
            for _, enemy in ipairs(others) do
                minimum = math.min(minimum, (enemy - position).Magnitude)
            end
            -- Tie breaker avoids choosing an identical vacant corner forever.
            local score = minimum + rng:NextNumber(-6, 6)
            if score > bestScore then
                best, bestScore = position, score
            end
        end
    end
    -- All candidates occupied: prefer the most distant, still bounded to the map.
    if not best then
        for _, position in ipairs(candidates) do
            local minimum = 200
            for _, enemy in ipairs(others) do
                minimum = math.min(minimum, (enemy - position).Magnitude)
            end
            if minimum > bestScore then
                best, bestScore = position, minimum
            end
        end
    end
    return best or candidates[1]
end

function SpawnService.isProtected(character)
    if not character then return false end
    local protectedUntil = character:GetAttribute("NeonSpawnProtectedUntil")
    return typeof(protectedUntil) == "number" and protectedUntil > Workspace:GetServerTimeNow()
end

function SpawnService.clearProtection(character)
    if character then
        character:SetAttribute("NeonSpawnProtectedUntil", 0)
    end
end

function SpawnService.place(player, character)
    if not character or player.Character ~= character or not character.Parent then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    local position = safestPosition(character)
    local yaw = rng:NextNumber(-math.pi, math.pi)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    character:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
    humanoid.Health = humanoid.MaxHealth
    character:SetAttribute("NeonSpawnProtectedUntil", Workspace:GetServerTimeNow() + SPAWN_SHIELD_SECONDS)
    return true
end

local function watchPlayer(player)
    local function onCharacter(character)
        task.spawn(function()
            local root = character:WaitForChild("HumanoidRootPart", 10)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not root or not humanoid then return end
            -- CharacterAdded may fire before Roblox has parented the rig.
            for _ = 1, 15 do
                if not character.Parent or not root:IsDescendantOf(Workspace) then
                    task.wait(0.1)
                else
                    break
                end
            end
            if player.Character == character and root:IsDescendantOf(Workspace) then
                SpawnService.place(player, character)
            end
        end)
    end
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        task.defer(onCharacter, player.Character)
    end
end

function SpawnService.placePlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            SpawnService.place(player, player.Character)
        end
    end
end

function SpawnService.start()
    if started then return end
    started = true
    Players.PlayerAdded:Connect(watchPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        task.defer(watchPlayer, player)
    end
end

return SpawnService
