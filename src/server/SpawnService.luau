-- NEON STRIKE / server-owned player spawning, tactical safety and short spawn shield.
-- A candidate must be clear of physical cover and far from live combatants.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpawnSafety = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpawnSafety"))
local DuelSpawnPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelSpawnPlan"))

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
    local positions, ignoredCharacters = {}, {}
    if excludeCharacter then table.insert(ignoredCharacters, excludeCharacter) end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character ~= excludeCharacter then
            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                table.insert(positions, root.Position)
                table.insert(ignoredCharacters, character)
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
                table.insert(ignoredCharacters, model)
            end
        end
    end
    return positions, ignoredCharacters
end

local function clearAt(position, character, otherCharacter)
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = { character }
    if otherCharacter then table.insert(ignored, otherCharacter) end
    overlap.FilterDescendantsInstances = ignored
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
    local others, ignoredCharacters = livePositions(character)
    -- Cover visibility is measured against solid gameplay geometry, not
    -- decorative non-colliding trim, transparent VFX or another combatant.
    local sight = RaycastParams.new()
    sight.FilterType = Enum.RaycastFilterType.Exclude
    sight.FilterDescendantsInstances = ignoredCharacters
    sight.IgnoreWater = true
    sight.RespectCanCollide = true

    local function scoreAt(position)
        local nearest = 200
        local exposedCount = 0
        local nearestExposed = SpawnSafety.EXPOSURE_RANGE
        local from = position + Vector3.new(0, 1.4, 0)
        for _, enemy in ipairs(others) do
            local distance = (enemy - position).Magnitude
            nearest = math.min(nearest, distance)
            -- This is spawn-only work, never called every frame. Avoid
            -- raycasting distant threats that cannot pressure a fresh spawn.
            if distance < SpawnSafety.EXPOSURE_RANGE then
                local to = enemy + Vector3.new(0, 1.4, 0)
                if not Workspace:Raycast(from, to - from, sight) then
                    exposedCount += 1
                    nearestExposed = math.min(nearestExposed, distance)
                end
            end
        end
        return SpawnSafety.score(nearest, exposedCount, nearestExposed,
            rng:NextNumber(-6, 6))
    end

    local best, bestScore = nil, -math.huge
    for _, position in ipairs(candidates) do
        if clearAt(position, character) then
            local score = scoreAt(position)
            if score > bestScore then
                best, bestScore = position, score
            end
        end
    end
    if best then return best end

    -- All twelve edge pads may become obstructed by a future arena update.
    -- The original Roblox spawn pad is a final validated fallback before
    -- considering a blocked edge: avoid teleporting into cargo collisions.
    local centralPad = Vector3.new(0, 3.4, 130)
    if clearAt(centralPad, character) then return centralPad end

    for _, position in ipairs(candidates) do
        local score = scoreAt(position)
        if score > bestScore then
            best, bestScore = position, score
        end
    end
    warn("IRON YARD: no unobstructed spawn pad; using fallback under shield")
    return best or centralPad
end
function SpawnService.selectSafeSpawn(excludeCharacter)
    return safestPosition(excludeCharacter)
end

function SpawnService.protectCharacter(character, seconds)
    if character and character.Parent then
        character:SetAttribute("NeonSpawnProtectedUntil",
            Workspace:GetServerTimeNow() + math.max(0, seconds or SPAWN_SHIELD_SECONDS))
    end
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

function SpawnService.place(player, character, preferredPosition, faceToward, otherCharacter)
    if not character or player.Character ~= character or not character.Parent then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    local position = typeof(preferredPosition) == "Vector3"
        and clearAt(preferredPosition, character, otherCharacter) and preferredPosition
        or safestPosition(character)
    local yaw = rng:NextNumber(-math.pi, math.pi)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local origin = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
    if typeof(faceToward) == "Vector3" then
        origin = CFrame.lookAt(position,
            Vector3.new(faceToward.X, position.Y, faceToward.Z))
    end
    character:PivotTo(origin)
    humanoid.Health = humanoid.MaxHealth
    SpawnService.protectCharacter(character, SPAWN_SHIELD_SECONDS)
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

function SpawnService.placeDuelPair(a, b, bout)
    if not a or not b or a == b then return false end
    local aChar, bChar = a.Character, b.Character
    if not aChar or not bChar
        or not aChar:IsDescendantOf(Workspace)
        or not bChar:IsDescendantOf(Workspace) then return false end
    local function combatReady(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health > 0
            and character:FindFirstChild("HumanoidRootPart") ~= nil
    end
    if not combatReady(aChar) or not combatReady(bChar) then return false end

    -- Validate BOTH pads before teleporting either player. Player bodies
    -- are ignored as temporary obstacles, but physical cover is not.
    -- Missing pads cannot silently fall back to a close FFA spawn.
    local clear = {}
    for i, position in ipairs(candidates) do
        clear[i] = clearAt(position, aChar, bChar)
    end
    local firstIndex, secondIndex = DuelSpawnPlan.select(clear, bout)
    if not firstIndex then return false end
    local first, second = candidates[firstIndex], candidates[secondIndex]
    return SpawnService.place(a, aChar, first, second, bChar)
        and SpawnService.place(b, bChar, second, first, aChar)
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
