-- IRON YARD / server-owned, bounded obstacle navigation for FFA opponents.
-- Uses capsule checks, asynchronous PathfindingService and safe ground detours.
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Planner = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotAvoidancePlan"))

local BotNavigation = {}
local rnd = Random.new()
local WAYPOINT_REACH = 4.5
local GOAL_REPATH_DISTANCE = 20
local PATH_COMPUTE_TIMEOUT = 5.0
local DETOUR_RECHECK_SECONDS = 1.35
local DETOUR_HOLD_SECONDS = 2.4
local MAX_GROUND_DELTA = 3.2
local EDGE_LIMIT = 162

local function setMode(bot, mode)
    if bot.navMode == mode then return end
    bot.navMode = mode
    bot.navModeSince = os.clock()
    if bot.model and bot.model.Parent then
        bot.model:SetAttribute("IronYardNavMode", mode)
    end
end

local function environmentParams(bot)
    local ignore = { bot.model }
    local bots = Workspace:FindFirstChild("NeonStrikeBots")
    if bots then table.insert(ignore, bots) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(ignore, player.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

local function directRouteClear(bot, goal, cachedParams)
    -- A centre-only ray slips past freight-container corners while a two-stud
    -- humanoid collides. Probe the approximate capsule at two elevations.
    if math.abs(goal.Y - bot.root.Position.Y) > 2.5 then return false end
    local origin = bot.root.Position
    local flat = Vector3.new(goal.X - origin.X, 0, goal.Z - origin.Z)
    if flat.Magnitude <= 2 then return true end
    local side = Vector3.new(-flat.Z, 0, flat.X).Unit * 1.3
    local params = cachedParams or environmentParams(bot)
    local low = Vector3.new(0, -1.2, 0)
    local high = Vector3.new(0, 1.1, 0)
    for _, offset in ipairs({ low, low + side, low - side, high + side, high - side }) do
        if Workspace:Raycast(origin + offset, flat, params) then
            return false
        end
    end
    -- Capsule clearance does not imply the FLOOR exists. Especially from
    -- catwalks, an empty lane can lead straight off an exposed platform.
    -- Two near-future ground probes stop movement BEFORE the edge while
    -- keeping the raycast budget independent of total route distance.
    local direction = flat.Unit
    for _, distance in ipairs({ math.min(7, flat.Magnitude), math.min(14, flat.Magnitude) }) do
        local sample = origin + direction * distance
        local downFrom = Vector3.new(sample.X, origin.Y + 4.5, sample.Z)
        local floor = Workspace:Raycast(downFrom, Vector3.new(0, -12, 0), params)
        if not floor or floor.Normal.Y < 0.68
            or math.abs(floor.Position.Y + 3.4 - origin.Y) > MAX_GROUND_DELTA then
            return false
        end
    end
    return true
end

local function walkableCandidate(bot, raw, params)
    if math.abs(raw.X) > EDGE_LIMIT or math.abs(raw.Z) > EDGE_LIMIT then
        return nil
    end
    -- Grounding rejects roof tops, drops, voids and different catwalk heights.
    local castFrom = Vector3.new(raw.X, bot.root.Position.Y + 4.5, raw.Z)
    local hit = Workspace:Raycast(castFrom, Vector3.new(0, -12, 0), params)
    if not hit or hit.Normal.Y < 0.68 then return nil end
    local grounded = hit.Position + Vector3.new(0, 3.4, 0)
    if math.abs(grounded.Y - bot.root.Position.Y) > MAX_GROUND_DELTA then
        return nil
    end
    return grounded
end

local function chooseDetour(bot, goal)
    local origin = bot.root.Position
    local vector = Vector3.new(goal.X - origin.X, 0, goal.Z - origin.Z)
    if vector.Magnitude < 2 then return nil end
    local ahead = vector.Unit
    local right = Vector3.new(-ahead.Z, 0, ahead.X)
    local params = environmentParams(bot)
    local attempt = bot.detourAttempts or 0
    bot.detourAttempts = attempt + 1
    -- At most six grounded candidates, each checked with the same five
    -- capsule rays. Checked no more than once per 1.35 s on each bot.
    for _, offset in ipairs(Planner.offsets(bot.strafeSign, attempt)) do
        local raw = origin + ahead * offset.forward + right * offset.lateral
        local grounded = walkableCandidate(bot, raw, params)
        if grounded and directRouteClear(bot, grounded, params) then
            return grounded
        end
    end
    return nil
end

function BotNavigation.invalidate(bot)
    bot.pathRevision = (bot.pathRevision or 0) + 1
    bot.pathing = false
    bot.pathStartedAt = nil
    bot.waypoints = nil
    bot.waypointIndex = 1
    bot.pathGoal = nil
    bot.nextPathAt = 0
    bot.detourGoal = nil
    bot.detourUntil = 0
    bot.nextDetourAt = 0
end

local function followWaypoints(bot)
    local waypoints = bot.waypoints
    if not waypoints or #waypoints == 0 then return false end
    local point = waypoints[bot.waypointIndex]
    while point and (bot.root.Position - point.Position).Magnitude <= WAYPOINT_REACH do
        bot.waypointIndex += 1
        point = waypoints[bot.waypointIndex]
    end
    if not point then
        bot.waypoints = nil
        return false
    end
    bot.humanoid:MoveTo(point.Position)
    if point.Action == Enum.PathWaypointAction.Jump then
        bot.humanoid.Jump = true
    end
    return true
end

local function followDetour(bot, goal, now)
    local detour = bot.detourGoal
    if detour then
        local expired = now >= (bot.detourUntil or 0)
        local arrived = (bot.root.Position - detour).Magnitude <= 3.5
        local goalMoved = bot.detourTarget
            and (goal - bot.detourTarget).Magnitude > GOAL_REPATH_DISTANCE
        if expired or arrived or goalMoved or not directRouteClear(bot, detour) then
            bot.detourGoal = nil
        else
            bot.humanoid:MoveTo(detour)
            setMode(bot, "AVOID")
            return true
        end
    end
    if now < (bot.nextDetourAt or 0) then return false end

    bot.nextDetourAt = now + DETOUR_RECHECK_SECONDS
    local candidate = chooseDetour(bot, goal)
    if not candidate then return false end
    bot.detourGoal = candidate
    bot.detourTarget = goal
    bot.detourUntil = now + DETOUR_HOLD_SECONDS
    bot.humanoid:MoveTo(candidate)
    setMode(bot, "AVOID")
    return true
end

function BotNavigation.steer(bot, goal, isCurrent)
    if bot.humanoid.Health <= 0 or not bot.root.Parent then return end
    local now = os.clock()
    if directRouteClear(bot, goal) then
        if bot.waypoints or bot.pathing then BotNavigation.invalidate(bot) end
        bot.detourGoal = nil
        bot.humanoid:MoveTo(goal)
        setMode(bot, "DIRECT")
        return
    end

    -- Retain a valid path while an asynchronous replacement is computing.
    local moving = followWaypoints(bot)
    if moving then
        setMode(bot, "PATH")
    elseif not followDetour(bot, goal, now) then
        -- Never charge directly into cover known to block the full capsule.
        -- The next verified path/detour, not an attempted collision, moves us.
        bot.humanoid:MoveTo(bot.root.Position)
        setMode(bot, "WAIT")
    end

    if bot.pathing and now - (bot.pathStartedAt or now) > PATH_COMPUTE_TIMEOUT then
        -- Abandon a hung ComputeAsync result without interrupting movement.
        -- Its old completion must never overwrite a newer route.
        bot.pathRevision = (bot.pathRevision or 0) + 1
        bot.pathing = false
        bot.pathGoal = nil
        bot.pathFailures = (bot.pathFailures or 0) + 1
        bot.nextPathAt = now + Planner.retryDelay(bot.pathFailures)
    end

    local goalChanged = bot.pathGoal and (goal - bot.pathGoal).Magnitude > GOAL_REPATH_DISTANCE
    if goalChanged then
        bot.pathRevision = (bot.pathRevision or 0) + 1
        bot.pathing = false
        bot.pathGoal = nil
        bot.nextPathAt = math.max(bot.nextPathAt or 0, now + 0.2)
    end
    if bot.pathing or now < (bot.nextPathAt or 0)
        or now - (bot.lastComputeAt or -math.huge) < 0.9 then
        return
    end

    bot.pathing = true
    bot.pathStartedAt = now
    bot.lastComputeAt = now
    bot.pathRevision = (bot.pathRevision or 0) + 1
    local revision = bot.pathRevision
    bot.pathGoal = goal
    bot.nextPathAt = now + 1.25 + rnd:NextNumber(0, 0.5)

    local start = bot.root.Position
    task.spawn(function()
        local ok, waypoints = pcall(function()
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentJumpHeight = 8,
                WaypointSpacing = 6,
            })
            path:ComputeAsync(start, goal)
            if path.Status ~= Enum.PathStatus.Success then return nil end
            return path:GetWaypoints()
        end)
        if not isCurrent() or bot.pathRevision ~= revision then return end
        bot.pathing = false
        bot.pathStartedAt = nil
        if ok and waypoints and #waypoints > 1
            and (bot.root.Position - start).Magnitude <= 24 then
            bot.waypoints = waypoints
            bot.waypointIndex = 2
            bot.detourGoal = nil
            bot.pathFailures = 0
        else
            bot.waypoints = nil
            bot.pathFailures = (bot.pathFailures or 0) + 1
            bot.nextPathAt = math.max(bot.nextPathAt,
                os.clock() + Planner.retryDelay(bot.pathFailures))
        end
    end)
end

return BotNavigation
