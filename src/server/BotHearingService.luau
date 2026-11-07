-- IRON YARD: bounded server-owned gunshot evidence for nearby NPCs.
-- Audio events are NOT targets, cannot authorize shots and are never client-authored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hearing = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotHearingPlan"))
local Search = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotSoundSearchPlan"))
local BotTactics = require(script.Parent:WaitForChild("BotTactics"))
local Service = {}
local events = {}
local sequence = 0

local function validPosition(position)
    return typeof(position) == "Vector3"
        and position.X == position.X and position.Y == position.Y
        and position.Z == position.Z
        and math.abs(position.X) < 10000
        and math.abs(position.Y) < 10000
        and math.abs(position.Z) < 10000
end

function Service.record(shooter, weaponId, position)
    if not shooter or not shooter.Parent or not validPosition(position) then return end
    local radius = Hearing.radius(weaponId)
    if not radius then return end
    local now = os.clock()
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    for i = #events, 1, -1 do
        local event = events[i]
        if now - event.time > Hearing.LIFETIME then
            table.remove(events, i)
        elseif event.shooter == shooter and now - event.time <= 0.45 then
            -- Coalesce automatic fire: only one record per active shooter.
            -- A fresh event ID still reflects the new, accepted discharge.
            sequence += 1
            event.id = sequence
            event.time = now
            event.position = position
            event.radius = radius
            return
        end
    end
    sequence += 1
    table.insert(events, {
        id = sequence,
        shooter = shooter,
        position = position,
        radius = radius,
        time = now,
    })
    if #events > Hearing.MAX_EVENTS then
        table.remove(events, 1)
    end
end

local function stopSearch(bot)
    bot.soundGoal = nil
    bot.soundCenter = nil
    bot.soundSearchPhase = nil
    bot.soundSearchStartedAt = 0
    bot.soundPhaseStartedAt = 0
    bot.soundGoalActive = false
end

local function assignLeg(bot, now)
    if not bot.soundCenter then return nil end
    -- No unbounded retry or navmesh spam: at most three grounding searches
    -- whenever a phase begins (never every 0.2-second bot think step).
    for phase = bot.soundSearchPhase, Search.PHASE_COUNT do
        local goal = BotTactics.soundSearchGoal(bot, bot.soundCenter, phase)
        if goal then
            bot.soundSearchPhase = phase
            bot.soundPhaseStartedAt = now
            bot.soundGoal = goal
            return goal
        end
    end
    stopSearch(bot)
    return nil
end

function Service.stopSearch(bot)
    stopSearch(bot)
end

function Service.reportBotStuck(bot)
    if not bot.soundSearchPhase then return end
    -- The same waypoint monitor used for medical and cover goals moves a
    -- blocked hearing search on to its next sweep instead of wall-walking.
    bot.soundSearchPhase += 1
    bot.soundGoal = nil
    if bot.soundSearchPhase > Search.PHASE_COUNT then stopSearch(bot) end
end

function Service.investigationGoal(bot, now)
    if not bot or not bot.model or not bot.root or not bot.model.Parent
        or workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return nil end
    local root = bot.root.Position

    if bot.soundSearchPhase then
        if bot.soundGoal then
            local phase, changed, finished = Search.advance(bot.soundSearchPhase,
                bot.soundSearchStartedAt, bot.soundPhaseStartedAt,
                now, (bot.soundGoal - root).Magnitude)
            if finished then
                stopSearch(bot)
            elseif changed then
                bot.soundSearchPhase = phase
                bot.soundGoal = nil
                return assignLeg(bot, now)
            else
                return bot.soundGoal
            end
        else
            if now - (bot.soundSearchStartedAt or now) >= Search.MAX_SECONDS then
                stopSearch(bot)
            else
                return assignLeg(bot, now)
            end
        end
        -- A completed search cannot restart from the same event. Later
        -- confirmed shots may still open a new finite search.
        return nil
    end

    local candidates = {}
    for _, event in ipairs(events) do
        table.insert(candidates, {
            id = event.id,
            age = now - event.time,
            radius = event.radius,
            distance = (event.position - root).Magnitude,
            own = event.shooter == bot.model,
        })
    end
    local chosen = Hearing.choose(candidates, now, bot.soundLastHandledId or 0)
    if not chosen then return nil end
    for _, event in ipairs(events) do
        if event.id == chosen then
            -- Convert to a rough acoustic cell, never retain the exact
            -- shooter position in a bot's state or targeting system.
            local x = Hearing.approximateAxis(event.position.X, bot.slot, "X")
            local z = Hearing.approximateAxis(event.position.Z, bot.slot, "Z")
            if not x or not z then return nil end
            bot.soundLastHandledId = chosen
            bot.soundCenter = Vector3.new(x, root.Y, z)
            bot.soundSearchPhase = 1
            bot.soundSearchStartedAt = now
            bot.soundPhaseStartedAt = now
            return assignLeg(bot, now)
        end
    end
    return nil
end

function Service.resetBot(bot)
    stopSearch(bot)
    bot.soundLastHandledId = 0
end

function Service.resetRound()
    table.clear(events)
end

return Service
