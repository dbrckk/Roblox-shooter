-- IRON YARD / pure server capacity policy (LOT 0b of the RIVALS gap plan).
-- The place declares no maximum player count today, so the roster limit is
-- stated here instead of being implied by whatever Roblox happens to allow.
-- Nothing here touches Roblox: the server passes the numbers in, which keeps
-- the policy testable offline and auditable in CI.
local ServerCapacity = {}

-- Decision of record: 10 combatants plus 2 spectator slots.
-- The duel gate needs exactly two ready players, so a populated server must
-- still leave room for that pair; BotConfig.MaxCombatants stays the ceiling
-- for bot spawning and is independent from this roster limit.
ServerCapacity.MAX_PLAYERS = 12
ServerCapacity.SPECTATOR_SLOTS = 2
ServerCapacity.COMBATANT_LIMIT = ServerCapacity.MAX_PLAYERS - ServerCapacity.SPECTATOR_SLOTS

local function count(value, label)
    assert(type(value) == "number" and value == value and value >= 0
        and value < math.huge and value % 1 == 0, "Invalid " .. label)
    return value
end

-- Where a joining player lands. `current` is the population BEFORE the join.
function ServerCapacity.classify(current)
    count(current, "current player count")
    if current < ServerCapacity.COMBATANT_LIMIT then return "COMBATANT" end
    if current < ServerCapacity.MAX_PLAYERS then return "SPECTATOR" end
    return "FULL"
end

-- Slot for a player who has just joined, from the roster size AFTER the join:
-- `PlayerAdded` fires once the newcomer is already in Players. The off-by-one
-- lives here, in the pure policy, instead of in the service that observes it.
function ServerCapacity.classifyJoin(rosterCount)
    count(rosterCount, "roster count")
    assert(rosterCount >= 1, "A joining player is always part of the roster")
    return ServerCapacity.classify(rosterCount - 1)
end

function ServerCapacity.admits(current)
    return ServerCapacity.classify(current) ~= "FULL"
end

-- BotService already fills up to BotConfig.MaxCombatants; mirroring its
-- formula here keeps a capacity change from silently distorting the budget.
function ServerCapacity.botBudget(humans, maxCombatants, maxBots)
    count(humans, "human count")
    count(maxCombatants, "combatant ceiling")
    count(maxBots, "bot ceiling")
    local room = maxCombatants - humans
    if room < 0 then room = 0 end
    if room > maxBots then room = maxBots end
    return room
end

-- Room left before the place is full, spectators included.
function ServerCapacity.freeSlots(current)
    count(current, "current player count")
    local free = ServerCapacity.MAX_PLAYERS - current
    if free < 0 then return 0 end
    return free
end

-- Audit of the place's configured Players.MaxPlayers value.
-- UNSET is the state this lot exists to remove: an unset maximum is not a
-- policy, it is whatever Roblox decides for the place.
function ServerCapacity.checkPlaceMaxPlayers(configured)
    if configured == nil then
        return { ok = false, reason = "UNSET" }
    end
    count(configured, "Players.MaxPlayers")
    if configured < ServerCapacity.MAX_PLAYERS then
        return { ok = false, reason = "TOO_SMALL" }
    end
    if configured > ServerCapacity.MAX_PLAYERS then
        return { ok = false, reason = "OVERFLOW" }
    end
    return { ok = true, reason = "EXACT" }
end

return ServerCapacity
