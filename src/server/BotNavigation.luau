-- IRON YARD / server-owned, bounded obstacle navigation for FFA opponents.
-- Uses capsule checks, asynchronous PathfindingService and safe ground detours.
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Planner = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotAvoidancePlan"))
local BotPerfService = require(script.Parent:WaitForChild("BotPerfService"))
local Budget = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotPathBudget"))

local BotNavigation = {}
local rnd = Random.new()
local pathBudget = Budget.new()
local WAYPOINT_REACH = 4.5
local GOAL_REPATH_DISTANCE = 20
local PATH_COMPUTE_TIMEOUT = 5.0
local PATH_REUSE_SECONDS = 6.0
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

-- Reissue a changed MoveTo target immediately, but do not reset Roblox
-- Humanoid movement on every 0.2-second bot thinking step when unchanged.
local function requestMove(bot, goal, now, force)
    local moved = bot.lastMoveGoal and (goal - bot.lastMoveGoal).Magnitude
        or math.huge
    local age = now - (bot.lastMoveIssuedAt or -math.huge)
    if force or Budget.shouldIssueMove(moved, age) then
        bot.humanoid:MoveTo(goal)
        BotPerfService.count("moveIssued")
        bot.lastMoveGoal = goal
        bot.lastMoveIssuedAt = now
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
    params.RespectCanCollide = true
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
        BotPerfService.count("navRay")
        if Workspace:Raycast(origin + offset, flat, params) then
            return false
        end
    end
    -- Capsule clearance does not imply the FLOOR exists. Especially from
    -- catwalks, an empty lane can lead straight off an exposed platform.
    -- Two near-future ground probes stop movement BEFORE the edge while
    -- keeping the raycast budget independent of total route distance.
    local direction = flat.Unit
    for _, lookahead in ipairs({ 7, 14, 22, 30 }) do
        local distance = math.min(lookahead, flat.Magnitude)
        local sample = origin + direction * distance
        local downFrom = Vector3.new(sample.X, origin.Y + 4.5, sample.Z)
        BotPerfService.count("navRay")
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
    BotPerfService.count("navRay")
    local hit = Workspace:Raycast(castFrom, Vector3.new(0, -12, 0), params)
    if not hit or hit.Normal.Y < 0.68 then return nil end
    local grounded = hit.Position + Vector3.new(0, 3.4, 0)
    if math.abs(grounded.Y - bot.root.Position.Y) > MAX_GROUND_DELTA then
        return nil
    end
    return grounded
end

local function chooseDetour(bot, goal, params)
    local origin = bot.root.Position
    local vector = Vector3.new(goal.X - origin.X, 0, goal.Z - origin.Z)
    if vector.Magnitude < 2 then return nil end
    local ahead = vector.Unit
    local right = Vector3.new(-ahead.Z, 0, ahead.X)
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

local function releaseActivePath(bot)
    if bot.pathBlockedConnection then
        bot.pathBlockedConnection:Disconnect()
        bot.pathBlockedConnection = nil
    end
    bot.activePath = nil
    bot.blockedWaypoint = nil
end

local function abandonWaypoints(bot)
    releaseActivePath(bot)
    bot.waypoints = nil
    bot.waypointIndex = 1
end

function BotNavigation.invalidate(bot)
    releaseActivePath(bot)
    bot.pathRevision = (bot.pathRevision or 0) + 1
    bot.pathing = false
    bot.pathStartedAt = nil
    bot.waypoints = nil
    bot.waypointIndex = 1
    bot.pathGoal = nil
    bot.pathAcceptedAt = nil
    bot.nextPathAt = 0
    bot.detourGoal = nil
    bot.detourUntil = 0
    bot.nextDetourAt = 0
    bot.navSteeringGoal = nil
    bot.lastMoveGoal = nil
    bot.lastMoveIssuedAt = nil
end

local function followWaypoints(bot, now)
    local waypoints = bot.waypoints
    if not waypoints or #waypoints == 0 then return false end
    local point = waypoints[bot.waypointIndex]
    while point and (bot.root.Position - point.Position).Magnitude <= WAYPOINT_REACH do
        bot.waypointIndex += 1
        point = waypoints[bot.waypointIndex]
    end
    if not point then
        abandonWaypoints(bot)
        return false
    end
    if Planner.blockedAhead(bot.blockedWaypoint, bot.waypointIndex) then
        -- Roblox detected a fresh obstacle across the remaining path. Abort
        -- the obsolete route instead of walking the NPC into its blocker.
        abandonWaypoints(bot)
        bot.pathFailures = (bot.pathFailures or 0) + 1
        bot.nextPathAt = math.max(bot.nextPathAt or 0,
            os.clock() + Planner.retryDelay(bot.pathFailures))
        return false
    end
    bot.navSteeringGoal = point.Position
    requestMove(bot, point.Position, now)
    if point.Action == Enum.PathWaypointAction.Jump then
        bot.humanoid.Jump = true
    end
    return true
end

local function followDetour(bot, goal, now, params)
    local detour = bot.detourGoal
    if detour then
        local expired = now >= (bot.detourUntil or 0)
        local arrived = (bot.root.Position - detour).Magnitude <= 3.5
        local goalMoved = bot.detourTarget
            and (goal - bot.detourTarget).Magnitude > GOAL_REPATH_DISTANCE
        if expired or arrived or goalMoved or not directRouteClear(bot, detour, params) then
            bot.detourGoal = nil
        else
            bot.navSteeringGoal = detour
            requestMove(bot, detour, now)
            setMode(bot, "AVOID")
            return true
        end
    end
    if now < (bot.nextDetourAt or 0) then return false end

    bot.nextDetourAt = now + DETOUR_RECHECK_SECONDS
    local candidate = chooseDetour(bot, goal, params)
    if not candidate then return false end
    bot.detourGoal = candidate
    bot.detourTarget = goal
    bot.detourUntil = now + DETOUR_HOLD_SECONDS
    bot.navSteeringGoal = candidate
    requestMove(bot, candidate, now)
    setMode(bot, "AVOID")
    return true
end

function BotNavigation.steer(bot, goal, isCurrent)
    if bot.humanoid.Health <= 0 or not bot.root.Parent then return end
    local now = os.clock()
    -- Shared environmental filter within this single steer decision:
    -- avoid allocating extra RaycastParams/character ignore arrays while
    -- evaluating detours against the same static collision geometry.
    local params = environmentParams(bot)
    if directRouteClear(bot, goal, params) then
        if bot.waypoints or bot.pathing then BotNavigation.invalidate(bot) end
        bot.detourGoal = nil
        bot.navSteeringGoal = goal
        requestMove(bot, goal, now)
        setMode(bot, "DIRECT")
        return
    end

    -- Retain a valid path while an asynchronous replacement is computing.
    local moving = followWaypoints(bot, now)
    if moving then
        setMode(bot, "PATH")
    elseif not followDetour(bot, goal, now, params) then
        -- Never charge directly into cover known to block the full capsule.
        -- The next verified path/detour, not an attempted collision, moves us.
        -- Keep the requested (blocked) goal available for stall monitoring.
        -- The MoveTo itself remains stopped until an actual route is found.
        bot.navSteeringGoal = goal
        requestMove(bot, bot.root.Position, now, bot.navMode ~= "WAIT")
        setMode(bot, "WAIT")
    end

    if bot.pathing and now - (bot.pathStartedAt or now) > PATH_COMPUTE_TIMEOUT then
        -- Abandon a hung ComputeAsync result without interrupting movement.
        -- Its old completion must never overwrite a newer route.
        bot.pathRevision = (bot.pathRevision or 0) + 1
        bot.pathing = false
        bot.pathGoal = nil
        abandonWaypoints(bot)
        bot.pathFailures = (bot.pathFailures or 0) + 1
        bot.nextPathAt = now + Planner.retryDelay(bot.pathFailures)
    end

    local goalChanged = bot.pathGoal
        and Planner.targetChanged((goal - bot.pathGoal).Magnitude, GOAL_REPATH_DISTANCE)
    if goalChanged then
        -- A path computed for a previous moving opponent is unsafe to reuse.
        -- Drop its waypoint queue and Blocked listener before searching anew.
        bot.pathRevision = (bot.pathRevision or 0) + 1
        bot.pathing = false
        bot.pathGoal = nil
        abandonWaypoints(bot)
        bot.nextPathAt = math.max(bot.nextPathAt or 0, now + 0.2)
    end
    -- The old implementation started a new ComputeAsync every ~1.25 s,
    -- even when a valid waypoint path was already being followed. With four
    -- bots this wastes navmesh CPU and can reset a nearly finished route.
    if Planner.reusePath(bot.waypoints ~= nil,
        bot.pathGoal and (goal - bot.pathGoal).Magnitude or math.huge,
        now - (bot.pathAcceptedAt or -math.huge),
        GOAL_REPATH_DISTANCE, PATH_REUSE_SECONDS) then
        return
    end
    if bot.pathing or now < (bot.nextPathAt or 0)
        or now - (bot.lastComputeAt or -math.huge) < 0.9 then
        return
    end

    -- Hard server-wide cap: only two concurrent ComputeAsync operations
    -- from the four bots, and never two path starts in the same burst.
    -- Denied bots keep verified detour/waypoint movement and retry at the
    -- normal bounded AI tick. No change to path safety or goal selection.
    local ticket = Budget.claim(pathBudget, now)
    if not ticket then
        BotPerfService.count("pathDeferred")
        return
    end
    BotPerfService.count("pathStarted")
    local pathSample = BotPerfService.begin()

    bot.pathing = true
    bot.pathStartedAt = now
    bot.lastComputeAt = now
    bot.pathRevision = (bot.pathRevision or 0) + 1
    local revision = bot.pathRevision
    bot.pathGoal = goal
    bot.nextPathAt = now + 1.25 + rnd:NextNumber(0, 0.5)

    local start = bot.root.Position
    task.spawn(function()
        local computedPath = nil
        local ok, waypoints = pcall(function()
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentJumpHeight = 8,
                WaypointSpacing = 6,
            })
            computedPath = path
            path:ComputeAsync(start, goal)
            if path.Status ~= Enum.PathStatus.Success then return nil end
            return path:GetWaypoints()
        end)
        BotPerfService.count("pathFinished")
        BotPerfService.measure("pathMs", pathSample)
        local leaseValid = Budget.valid(pathBudget, ticket, os.clock())
        Budget.release(pathBudget, ticket)
        if not leaseValid or not isCurrent()
            or bot.pathRevision ~= revision then return end
        bot.pathing = false
        bot.pathStartedAt = nil
        if ok and waypoints and #waypoints > 1
            and (bot.root.Position - start).Magnitude <= 24 then
            abandonWaypoints(bot)
            bot.waypoints = waypoints
            bot.pathAcceptedAt = os.clock()
            bot.waypointIndex = 2
            bot.activePath = computedPath
            bot.pathBlockedConnection = computedPath.Blocked:Connect(function(blockedIndex)
                -- Keep watching the current active route even while a
                -- replacement ComputeAsync is running in the background.
                if isCurrent() and bot.activePath == computedPath
                    and Planner.blockedAhead(blockedIndex, bot.waypointIndex) then
                    bot.blockedWaypoint = blockedIndex
                end
            end)
            bot.detourGoal = nil
            bot.pathFailures = 0
        else
            abandonWaypoints(bot)
            bot.pathFailures = (bot.pathFailures or 0) + 1
            bot.nextPathAt = math.max(bot.nextPathAt,
                os.clock() + Planner.retryDelay(bot.pathFailures))
        end
    end)
end

return BotNavigation
