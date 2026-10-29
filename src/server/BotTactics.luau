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
        if candidate then
            local offset = candidate - current
            local moveCast = Workspace:Raycast(current + Vector3.new(0, -1, 0),
                Vector3.new(offset.X, 0, offset.Z), params)
            local approachClear = moveCast == nil
            local start = seenPosition + Vector3.new(0, 1.0, 0)
            local finish = candidate + Vector3.new(0, 1.0, 0)
            local blockingCover = Workspace:Raycast(start, finish - start, params) ~= nil
            -- Cover beats raw distance. Favor low-cost reachable moves,
            -- stagger left/right by slot to avoid identical AI clustering.
            local sideBias = (i % 2 == (bot.slot % 2)) and 2 or 0
            local score = (blockingCover and 65 or 0)
                + (approachClear and 18 or -8)
                - offset.Magnitude * 0.28 + sideBias
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
    local needsCover = (healthRatio < 0.55 and recentlyHit)
        or bot.ammoRemaining <= 0 or bot.reloadUntil > now
    if not needsCover then
        BotTactics.reset(bot)
        return nil
    end

    if bot.coverGoal and now < (bot.coverGoalUntil or 0) then
        return bot.coverGoal
    end
    return selectCover(bot, knownPosition, now)
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
    if math.abs(destination.X) < EDGE_LIMIT and math.abs(destination.Z) < EDGE_LIMIT then
        return destination
    end
    return lastKnownPosition
end

return BotTactics
