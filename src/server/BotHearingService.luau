-- IRON YARD: bounded server-owned gunshot evidence for nearby NPCs.
-- Audio events are NOT targets, cannot authorize shots and are never client-authored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hearing = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotHearingPlan"))
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

function Service.investigationGoal(bot, now)
    if not bot or not bot.model or not bot.root or not bot.model.Parent
        or workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        return nil
    end
    local root = bot.root.Position
    if bot.soundGoal and now < (bot.soundHoldUntil or 0)
        and (bot.soundGoal - root).Magnitude > Hearing.MIN_INVESTIGATION_DISTANCE then
        return bot.soundGoal
    end
    local candidates = {}
    for _, event in ipairs(events) do
        local distance = (event.position - root).Magnitude
        table.insert(candidates, {
            id = event.id,
            age = now - event.time,
            radius = event.radius,
            distance = distance,
            own = event.shooter == bot.model,
        })
    end
    local chosen = Hearing.choose(candidates, now)
    if not chosen then
        bot.soundGoal = nil
        return nil
    end
    for _, event in ipairs(events) do
        if event.id == chosen then
            local x = Hearing.approximateAxis(event.position.X, bot.slot, "X")
            local z = Hearing.approximateAxis(event.position.Z, bot.slot, "Z")
            if not x or not z then return nil end
            local area = Vector3.new(x, root.Y, z)
            if (area - root).Magnitude <= Hearing.MIN_INVESTIGATION_DISTANCE then
                bot.soundGoal = nil
                return nil
            end
            bot.soundGoal = area
            bot.soundHoldUntil = now + Hearing.GOAL_HOLD_SECONDS
            return area
        end
    end
    return nil
end

function Service.resetBot(bot)
    bot.soundGoal = nil
    bot.soundHoldUntil = 0
    bot.soundGoalActive = false
end

function Service.resetRound()
    table.clear(events)
end

return Service
