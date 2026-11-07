-- IRON YARD / bounded, server-owned combat movement for AI opponents.
-- Decisions use only previously observed enemy positions. No through-wall tracking.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotCombatResponse = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotCombatResponse"))
local BotEngagementPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotEngagementPlan"))
local BotCoverPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotCoverPlan"))
local BotSoundSearchPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotSoundSearchPlan"))

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
    params.RespectCanCollide = true
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
    -- Three bounded ground probes, rather than one midpoint, prevent unsafe
    -- retreat steps over short drops and exposed catwalk edges.
    for _, fraction in ipairs({ 0.25, 0.5, 0.75 }) do
        local sample = current + direction * fraction
        local surface = Workspace:Raycast(
            Vector3.new(sample.X, current.Y + 4, sample.Z),
            Vector3.new(0, -11, 0), params)
        if not surface or surface.Normal.Y < 0.68
            or math.abs(surface.Position.Y + 3.4 - current.Y) > 3.5 then
            return false
        end
    end
    return true
end

local function selectCover(bot, seenPosition, now)
    local current = bot.root.Position
    local flat = Vector3.new(seenPosition.X - current.X, 0, seenPosition.Z - current.Z)
    if flat.Magnitude < 5 then return nil end
    local toward = flat.Unit
    local sideways = Vector3.new(-toward.Z, 0, toward.X)
    local params = environmentParams(bot)

    -- Bounded six-lane retreat, checked once per 2.4 s. First prefer a
    -- physically reachable position where SOLID level geometry blocks fire.
    -- A lane that genuinely caused a stuck recovery is excluded for eight
    -- seconds; no repeated sprint into the same container corner.
    local best, bestScore = nil, -math.huge
    for i, offset in ipairs(BotCoverPlan.offsets(bot.strafeSign)) do
        local raw = current - toward * offset.back + sideways * offset.lateral
        local candidate = groundedGoal(bot, raw, params)
        if candidate
            and not BotCoverPlan.rejected(bot.failedCoverGoal
                and (candidate - bot.failedCoverGoal).Magnitude or math.huge,
                now, bot.failedCoverUntil or 0)
            and coverApproachClear(bot, candidate, params) then
            local sightFrom = seenPosition + Vector3.new(0, 1.0, 0)
            local sightTo = candidate + Vector3.new(0, 1.0, 0)
            local shield = Workspace:Raycast(sightFrom, sightTo - sightFrom, params) ~= nil
            local score = BotCoverPlan.score(shield,
                (candidate - current).Magnitude, (i % 2 == bot.slot % 2))
            if score > bestScore then
                best, bestScore = candidate, score
            end
        end
    end
    bot.coverGoal = best
    bot.coverGoalUntil = now + COVER_HOLD_SECONDS
    return best
end

local function clearDefensiveGoal(bot)
    bot.coverGoal = nil
    bot.coverGoalUntil = 0
end

function BotTactics.reset(bot)
    clearDefensiveGoal(bot)
    bot.failedCoverGoal = nil
    bot.failedCoverUntil = 0
    bot.engagementGoal = nil
    bot.engagementTarget = nil
    bot.engagementExpiresAt = 0
    bot.engagementSampledAt = -math.huge
end

-- Record an actual failed retreat before another tactical decision.
function BotTactics.rejectStuckCover(bot, failedGoal, now)
    if not failedGoal then return end
    bot.failedCoverGoal = failedGoal
    bot.failedCoverUntil = now + BotCoverPlan.FAILED_LANE_SECONDS
    clearDefensiveGoal(bot)
end

-- A short-lived anchor stops a visible opponent from forcing a new MoveTo
-- target every 0.2 seconds. Retreat and strafing targets are selected with
-- real ground/shoulder clearance, never from hidden live player coordinates.
function BotTactics.engagementGoal(bot, seenPosition, now)
    if not seenPosition then return nil end
    local current = bot.root.Position
    local flat = Vector3.new(seenPosition.X - current.X, 0, seenPosition.Z - current.Z)
    if flat.Magnitude < 0.5 then return current end

    local previous = bot.engagementTarget
    local changed = previous and (seenPosition - previous).Magnitude or math.huge
    if BotEngagementPlan.reuseGoal(now, bot.engagementExpiresAt or 0,
        changed, bot.engagementSampledAt or -math.huge) then
        return bot.engagementGoal -- nil is also a cached failed search.
    end

    local toward = flat.Unit
    local lateral = Vector3.new(-toward.Z, 0, toward.X)
    local params = environmentParams(bot)
    local chosen = nil
    -- Stop after the first reachable candidate. At most three destinations
    -- are sampled every 1.65s unless the last sighting moved substantially.
    for _, offset in ipairs(BotEngagementPlan.offsets(flat.Magnitude, bot.strafeSign)) do
        local proposed = current + toward * offset.forward + lateral * offset.lateral
        local grounded = groundedGoal(bot, proposed, params)
        if grounded and coverApproachClear(bot, grounded, params) then
            chosen = grounded
            break
        end
    end

    bot.engagementTarget = seenPosition
    bot.engagementGoal = chosen
    bot.engagementSampledAt = now
    bot.engagementExpiresAt = now + BotEngagementPlan.GOAL_LIFETIME
    return chosen
end

function BotTactics.defensiveGoal(bot, knownPosition, now)
    if not knownPosition then
        clearDefensiveGoal(bot)
        return nil
    end

    local healthRatio = bot.humanoid.Health / math.max(1, bot.humanoid.MaxHealth)
    local recentlyHit = now - (bot.lastDamageAt or -math.huge) < 4.5
    local needsCover = BotCombatResponse.shouldTakeCover(healthRatio,
        recentlyHit and now - bot.lastDamageAt or math.huge,
        bot.ammoRemaining <= 0 or bot.reloadUntil > now,
        now < (bot.suppressedUntil or 0))
    if not needsCover then
        clearDefensiveGoal(bot)
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

-- Three small acoustic search positions around a COARSE sound cell.
-- Physical geometry, floor, edges and height are validated by the server.
-- The asynchronous navigator can path around cover when the direct lane is
-- blocked; a failed leg advances after its bounded timeout.
function BotTactics.soundSearchGoal(bot, center, phase)
    if typeof(center) ~= "Vector3" then return nil end
    local current = bot.root.Position
    local flat = Vector3.new(center.X - current.X, 0, center.Z - current.Z)
    local forward
    if flat.Magnitude > 0.25 then
        forward = flat.Unit
    else
        local look = bot.root.CFrame.LookVector
        local planar = Vector3.new(look.X, 0, look.Z)
        forward = planar.Magnitude > 0.25 and planar.Unit or Vector3.new(0, 0, -1)
    end
    local sideways = Vector3.new(-forward.Z, 0, forward.X)
    local params = environmentParams(bot)
    local possible = nil
    for _, offset in ipairs(BotSoundSearchPlan.offsets(phase, bot.strafeSign)) do
        local raw = center + forward * offset.forward + sideways * offset.lateral
        local grounded = groundedGoal(bot, raw, params)
        if grounded then
            -- Prefer immediate walkability; when cover blocks the approach,
            -- let BotNavigation attempt a server-owned path instead.
            if coverApproachClear(bot, grounded, params) then return grounded end
            possible = possible or grounded
        end
    end
    return possible
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
