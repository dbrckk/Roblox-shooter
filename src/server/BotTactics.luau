-- IRON YARD / bounded, server-owned combat movement for AI opponents.
-- Decisions use only previously observed enemy positions. No through-wall tracking.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local BotTactics = {}
local COVER_HOLD_SECONDS = 2.4
local EDGE_LIMIT = 163

local function environmentParams(bot)
    local ignore = { bot.model }
    local folder = Workspace:FindFirstChild("NeonStrikeBots")
    if folder then table.insert(ignore, folder) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(ignore, player.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

local function groundedGoal(bot, proposed, params)
    if math.abs(proposed.X) > EDGE_LIMIT or math.abs(proposed.Z) > EDGE_LIMIT then return nil end
    -- Test from the bot's walking plane. Avoid marching off a catwalk
    -- or into the top of a high container.
    local castFrom = Vector3.new(proposed.X, bot.root.Position.Y + 4, proposed.Z)
    local hit = Workspace:Raycast(castFrom, Vector3.new(0, -10, 0), params)
    if not hit or hit.Normal.Y < 0.65 then return nil end
    local ground = hit.Position + Vector3.new(0, 3.4, 0)
    if math.abs(ground.Y - bot.root.Position.Y) > 3.5 then return nil end
    return ground
end

local function coverApproachClear(bot, destination, params)
    local current = bot.root.Position
    local direction = Vector3.new(destination.X - current.X, 0, destination.Z - current.Z)
    if direction.Magnitude < 2 then return true end
    local side = Vector3.new(-direction.Z, 0, direction.X).Unit * 1.25
    -- A single centre ray ignores a humanoid's shoulders. Reject a cover
    -- candidate when a freight wall blocks any of the three walking lanes.
    for _, lateral in ipairs({ Vector3.zero, side, -side }) do
        local origin = current + lateral + Vector3.new(0, -0.65, 0)
        if Workspace:Raycast(origin, direction, params) then return false end
    end
    -- A walkable endpoint alone is insufficient if there is a catwalk gap.
    local middle = current + direction * 0.5
    local surface = Workspace:Raycast(
        Vector3.new(middle.X, current.Y + 4, middle.Z),
        Vector3.new(0, -11, 0), params)
    return surface ~= nil and surface.Normal.Y >= 0.68
        and math.abs(surface.Position.Y + 3.4 - current.Y) <= 3.5
end

local function selectCover(bot, seenPosition, now)
    local current = bot.root.Position
    local flat = Vector3.new(seenPosition.X - current.X, 0, seenPosition.Z - current.Z)
    if flat.Magnitude < 5 then return nil end
    local toward = flat.Unit
    local sideways = Vector3.new(-toward.Z, 0, toward.X)
    local params = environmentParams(bot)

    -- Four sampled retreat lanes, not a map-wide search. Max ~12 raycasts
    -- every 2.4s per injured/reloading bot, bounded for low-end Android servers.
    local candidates = {
        current - toward * 19 + sideways * 12,
        current - toward * 19 - sideways * 12,
        current - toward * 28 + sideways * 7,
        current - toward * 28 - sideways * 7,
    }
    local best, bestScore = nil, -math.huge
    for i, raw in ipairs(candidates) do
        local candidate = groundedGoal(bot, raw, params)
        if candidate and coverApproachClear(bot, candidate, params) then
            local offset = candidate - current
            local start = seenPosition + Vector3.new(0, 1.0, 0)
            local finish = candidate + Vector3.new(0, 1.0, 0)
            local blockingCover = Workspace:Raycast(start, finish - start, params) ~= nil
            -- Reject unreachable cover; prefer an actual solid obstacle
            -- shielding the bot, not an unreachable destination behind one.
            local sideBias = (i % 2 == (bot.slot % 2)) and 2 or 0
            local score = (blockingCover and 65 or 0)
                + 18 - offset.Magnitude * 0.28 + sideBias
            if score > bestScore then
                best, bestScore = candidate, score
            end
        end
    end
    bot.coverGoal = best
    bot.coverGoalUntil = now + COVER_HOLD_SECONDS
    return best
end

function BotTactics.reset(bot)
    bot.coverGoal = nil
    bot.coverGoalUntil = 0
end

function BotTactics.defensiveGoal(bot, knownPosition, now)
    if not knownPosition then
        BotTactics.reset(bot)
        return nil
    end

    local healthRatio = bot.humanoid.Health / math.max(1, bot.humanoid.MaxHealth)
    local recentlyHit = now - (bot.lastDamageAt or -math.huge) < 4.5
    local needsCover = (healthRatio < 0.68 and recentlyHit)
        or bot.ammoRemaining <= 0 or bot.reloadUntil > now
    if not needsCover then
        BotTactics.reset(bot)
        return nil
    end

    -- A failed search (nil coverGoal) is still cached for the same 2.4 s
    -- window. Otherwise four candidates × four raycasts run every AI tick
    -- when a wounded bot cannot find any reachable cover.
    if now < (bot.coverGoalUntil or 0) then
        return bot.coverGoal
    end
    -- If the selected lane is unreachable, do not resample the same lane
    -- indefinitely. Clear it and alternate the next retreat side.
    if bot.coverGoal and bot.stuckRecoveries and bot.stuckRecoveries > 0 then
        bot.strafeSign = -bot.strafeSign
    end
    return selectCover(bot, knownPosition, now)
end

-- Bounded investigation after a formerly visible target is lost.
-- Movement uses ONLY the last verified sighting, never the hidden target.
-- Two safe side sweeps plus the observed point, with ground-height checks
-- so an investigation cannot send a bot onto a freight container roof.
function BotTactics.investigateGoal(bot, lastSeen, elapsed, now)
    if not lastSeen or elapsed < 0 or elapsed >= 9 then return nil end
    local current = bot.root.Position
    local flat = Vector3.new(lastSeen.X - current.X, 0, lastSeen.Z - current.Z)
    local toward
    if flat.Magnitude > 0.15 then
        toward = flat.Unit
    else
        local look = bot.root.CFrame.LookVector
        local projected = Vector3.new(look.X, 0, look.Z)
        toward = projected.Magnitude > 0.15 and projected.Unit or Vector3.new(0, 0, -1)
    end
    local side = Vector3.new(-toward.Z, 0, toward.X) * bot.strafeSign
    local phase = math.floor(elapsed / 3.0)
    local raw = lastSeen
    if phase == 1 then
        raw = lastSeen + side * 12
    elseif phase >= 2 then
        raw = lastSeen - side * 13
    end
    local params = environmentParams(bot)
    return groundedGoal(bot, raw, params)
        or groundedGoal(bot, lastSeen, params)
end

function BotTactics.flankGoal(bot, lastKnownPosition, now)
    if not lastKnownPosition then return nil end
    -- Stable finite-duration search; never follow the invisible target's
    -- actual position after losing sight.
    local current = bot.root.Position
    local flat = Vector3.new(lastKnownPosition.X - current.X, 0, lastKnownPosition.Z - current.Z)
    if flat.Magnitude < 12 then return lastKnownPosition end
    local toward = flat.Unit
    local side = Vector3.new(-toward.Z, 0, toward.X) * bot.strafeSign
    local destination = lastKnownPosition - toward * 10 + side * 18
    local params = environmentParams(bot)
    -- Ground the flank on walkable surfaces and reject ledges or freight
    -- containers. A blocked flank falls back to the last observed position.
    local grounded = groundedGoal(bot, destination, params)
    if grounded then return grounded end
    return groundedGoal(bot, lastKnownPosition, params) or bot.root.Position
end

return BotTactics
