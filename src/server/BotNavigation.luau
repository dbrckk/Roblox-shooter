-- IRON YARD / server-owned navigation for reactive FFA opponents.
-- Pathfinding work runs asynchronously and never freezes movement when computing.
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local BotNavigation = {}
local rnd = Random.new()
local WAYPOINT_REACH = 4.5
local GOAL_REPATH_DISTANCE = 20

local function raycastEnvironment(bot, origin, destination)
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
    return Workspace:Raycast(origin, destination - origin, params)
end

local function directRouteClear(bot, goal)
    -- A single centre ray can slip past the corner of a freight container
    -- while the two-stud humanoid collides. Approximate the full walking
    -- capsule with side probes at leg and shoulder height.
    if math.abs(goal.Y - bot.root.Position.Y) > 2.5 then return false end
    local origin = bot.root.Position
    local flat = Vector3.new(goal.X - origin.X, 0, goal.Z - origin.Z)
    if flat.Magnitude <= 2 then return true end
    local side = Vector3.new(-flat.Z, 0, flat.X).Unit * 1.3
    local low = Vector3.new(0, -1.2, 0)
    local high = Vector3.new(0, 1.1, 0)
    for _, offset in ipairs({ low, low + side, low - side, high + side, high - side }) do
        local start = origin + offset
        if raycastEnvironment(bot, start, start + flat) then
            return false
        end
    end
    return true
end

function BotNavigation.invalidate(bot)
    bot.pathRevision = (bot.pathRevision or 0) + 1
    bot.pathing = false
    bot.waypoints = nil
    bot.waypointIndex = 1
    bot.pathGoal = nil
    bot.nextPathAt = 0
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

function BotNavigation.steer(bot, goal, isCurrent)
    if bot.humanoid.Health <= 0 or not bot.root.Parent then return end
    local now = os.clock()

    -- Use unobstructed movement without a pathfinding job: responsive and cheap.
    local direct = directRouteClear(bot, goal)
    if direct then
        if bot.waypoints or bot.pathing then BotNavigation.invalidate(bot) end
        bot.humanoid:MoveTo(goal)
        return
    end

    -- Existing waypoints continue to drive movement while ComputeAsync yields.
    -- This prevents the previous AI from standing still every navigation refresh.
    local moving = followWaypoints(bot)
    if not moving then
        -- Pending path: request motion toward the destination as a fallback.
        -- The next resolved route will replace it with traversable waypoints.
        bot.humanoid:MoveTo(goal)
    end

    local goalChanged = bot.pathGoal and (goal - bot.pathGoal).Magnitude > GOAL_REPATH_DISTANCE
    if goalChanged then
        -- A running ComputeAsync may finish long after the target has moved.
        -- Its revision is invalidated, while old waypoints remain usable.
        bot.pathRevision = (bot.pathRevision or 0) + 1
        bot.pathing = false
        -- Respect a short minimum interval even for rapidly switching targets.
        bot.nextPathAt = math.max(0, now - 0.05)
    end
    if bot.pathing or now < (bot.nextPathAt or 0)
        or now - (bot.lastComputeAt or -math.huge) < 0.9 then return end

    bot.pathing = true
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
            if path.Status ~= Enum.PathStatus.Success then
                return nil
            end
            return path:GetWaypoints()
        end)
        -- Old asynchronous path results must never override new target decisions,
        -- respawned models, or a stuck-recovery invalidation.
        if not isCurrent() or bot.pathRevision ~= revision then return end
        bot.pathing = false
        if ok and waypoints and #waypoints > 1 then
            bot.waypoints = waypoints
            bot.waypointIndex = 2
        else
            bot.waypoints = nil
            -- Retry later rather than repeatedly recalculating a blocked goal.
            bot.nextPathAt = math.max(bot.nextPathAt, os.clock() + 1.5)
        end
    end)
end

return BotNavigation
