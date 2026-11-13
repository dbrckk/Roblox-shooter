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
local lastNoSafePadWarningAt = -math.huge

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

    -- Never teleport a real player or an NPC inside a metal crate or wall.
    -- The emergency grid is bounded to 49 overlap checks only after all
    -- curated positions (and the central SpawnLocation) were obstructed.
    local x, z = SpawnSafety.chooseEmergencyPad(function(px, pz)
        return clearAt(Vector3.new(px, 3.4, pz), character)
    end, function(px, pz)
        return scoreAt(Vector3.new(px, 3.4, pz))
    end)
    if x ~= nil then return Vector3.new(x, 3.4, z) end
    if os.clock() - lastNoSafePadWarningAt >= 10 then
        lastNoSafePadWarningAt = os.clock()
        warn("[IRON YARD] No collision-free FFA spawn found; preserving existing positions")
    end
    return nil
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

-- Commit a prevalidated spawn without yielding or changing the chosen pad.
-- FFA selects a flexible position; duels validate TWO opposite pads first.
local function applyPlacement(character, root, humanoid, position, faceToward)
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
end

function SpawnService.place(player, character, preferredPosition, faceToward, otherCharacter)
    if not player or not character or player.Character ~= character
        or not character.Parent then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return false end
    local position = typeof(preferredPosition) == "Vector3"
        and clearAt(preferredPosition, character, otherCharacter) and preferredPosition
        or safestPosition(character)
    if not position then
        -- A failed search must not materialize as CFrame.new(nil) or a
        -- forced teleport into a solid part. Existing Roblox rigs stay alive.
        return false
    end
    applyPlacement(character, root, humanoid, position, faceToward)
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
                -- CharacterAdded callbacks may resume after the duel server
                -- has already positioned and anchored both combatants.
                -- A late FFA spawn must not move them or refresh their shield.
                if Workspace:GetAttribute("IronYardMatchMode") == "DUEL" then
                    return
                end
                -- On a temporarily saturated arena, retry the genuine
                -- physical check on this same rig. Never touch a replacement
                -- character or an active 1v1 during delayed attempts.
                for attempt = 1, 3 do
                    if player.Character ~= character or not root:IsDescendantOf(Workspace)
                        or Workspace:GetAttribute("IronYardMatchMode") == "DUEL" then
                        return
                    end
                    if SpawnService.place(player, character) then return end
                    if attempt < 3 then task.wait(0.7) end
                end
                warn("[IRON YARD] Could not reposition current player to a clear FFA pad")
            end
        end)
    end
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        task.defer(onCharacter, player.Character)
    end
end

function SpawnService.placeDuelPair(a, b, bout)
    if not a or not b or a == b or a.Parent ~= Players or b.Parent ~= Players
        then return false end
    local aChar, bChar = a.Character, b.Character
    if not aChar or not bChar
        or not aChar:IsDescendantOf(Workspace)
        or not bChar:IsDescendantOf(Workspace) then return false end
    local function combatReady(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not root
            or root.Anchored then return nil, nil end
        return root, humanoid
    end
    local aRoot, aHumanoid = combatReady(aChar)
    local bRoot, bHumanoid = combatReady(bChar)
    if not aRoot or not bRoot then return false end

    -- Verify BOTH opposite pads and both original living characters before
    -- committing ANY teleport. The general FFA spawn fallback is deliberately
    -- not used here: it can silently break duel fairness on pad rechecks.
    local clear = {}
    for i, position in ipairs(candidates) do
        clear[i] = clearAt(position, aChar, bChar)
    end
    local firstIndex, secondIndex = DuelSpawnPlan.select(clear, bout)
    if not firstIndex then return false end
    local first, second = candidates[firstIndex], candidates[secondIndex]
    if not clearAt(first, aChar, bChar)
        or not clearAt(second, aChar, bChar) then return false end
    if a.Parent ~= Players or b.Parent ~= Players
        or not aChar:IsDescendantOf(Workspace)
        or not bChar:IsDescendantOf(Workspace)
        or not DuelSpawnPlan.canCommit(a, b, aChar, bChar,
            aRoot.Parent == aChar and aHumanoid.Parent == aChar
                and not aRoot.Anchored and aHumanoid.Health > 0,
            bRoot.Parent == bChar and bHumanoid.Parent == bChar
                and not bRoot.Anchored and bHumanoid.Health > 0)
        then return false end

    -- Both non-yielding placements use their exact opposite pad; no
    -- first-player move can be followed by a recoverable second-player
    -- validation failure or a fallback to unrelated FFA spawn points.
    applyPlacement(aChar, aRoot, aHumanoid, first, second)
    applyPlacement(bChar, bRoot, bHumanoid, second, first)
    return true
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
