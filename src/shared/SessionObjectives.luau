-- A bounded UTC-day snapshot. Weapon spread, scores and XP do not use it.
local Objectives = {}
Objectives.ELIMINATIONS = 5
Objectives.WEAPONS = 3
Objectives.FINISH_ID = 1001 -- Cosmetic ID above the highest career rank.
Objectives.ATTRIBUTE = "IronYardSessionObjectives"
Objectives.UNLOCKED_ATTRIBUTE = "IronYardObjectiveFinishUnlocked"
Objectives.SAVED_ATTRIBUTE = "IronYardSavedSessionObjectives"

local WEAPON_BITS = { AssaultRifle = 1, Pistol = 2, Shotgun = 4, Sniper = 8, Knife = 16 }

local function integer(value, max)
    return type(value) == "number" and value >= 0 and value <= max and value % 1 == 0
end

function Objectives.day(unixTime)
    return math.floor(unixTime / 86400)
end

function Objectives.weaponCount(mask)
    local count = 0
    for _, flag in pairs(WEAPON_BITS) do
        if bit32.band(mask, flag) ~= 0 then count += 1 end
    end
    return count
end

function Objectives.completed(state)
    return (state.ffa and 1 or 0) + (state.kills >= Objectives.ELIMINATIONS and 1 or 0)
        + (Objectives.weaponCount(state.weapons) >= Objectives.WEAPONS and 1 or 0)
end

local function snapshot(day, kills, weapons, ffa, unlocked)
    local state = { day = day, kills = kills, weapons = weapons, ffa = ffa, unlocked = unlocked }
    if Objectives.completed(state) == 3 then state.unlocked = true end
    return state
end

function Objectives.normalize(raw)
    if type(raw) ~= "table" or not integer(raw.day, 10000000)
        or not integer(raw.kills, Objectives.ELIMINATIONS) or not integer(raw.weapons, 31)
        or type(raw.ffa) ~= "boolean" or type(raw.unlocked) ~= "boolean" then return nil end
    return snapshot(raw.day, raw.kills, raw.weapons, raw.ffa, raw.unlocked)
end

function Objectives.forDay(state, day)
    if state and state.day >= day then return state end
    return snapshot(day, 0, 0, false, state and state.unlocked or false)
end

-- Each elimination enters once at the authoritative lethal transition.
-- A second elimination with the same weapon still counts as one weapon type.
function Objectives.eliminate(state, day, weaponId)
    state = Objectives.forDay(state, day)
    local flag = WEAPON_BITS[weaponId]
    if not flag or day < state.day then return state end
    local kills = math.min(Objectives.ELIMINATIONS, state.kills + 1)
    local weapons = bit32.bor(state.weapons, flag)
    if kills == state.kills and weapons == state.weapons then return state end
    return snapshot(state.day, kills, weapons, state.ffa, state.unlocked)
end

function Objectives.finishFfa(state, day)
    state = Objectives.forDay(state, day)
    if state.ffa or day < state.day then return state end
    return snapshot(state.day, state.kills, state.weapons, true, state.unlocked)
end

-- Only a fresh database acquisition combines pre-load earnings additively.
-- Repeated and out-of-order saves always merge their cumulative snapshots.
function Objectives.merge(a, b, beforeLoad)
    if not a then return b end
    if not b then return a end
    local unlocked = a.unlocked or b.unlocked
    if a.day ~= b.day then
        local latest = a.day > b.day and a or b
        return snapshot(latest.day, latest.kills, latest.weapons, latest.ffa, unlocked)
    end
    local kills = beforeLoad and math.min(Objectives.ELIMINATIONS, a.kills + b.kills)
        or math.max(a.kills, b.kills)
    return snapshot(a.day, kills, bit32.bor(a.weapons, b.weapons), a.ffa or b.ffa, unlocked)
end

function Objectives.encode(state)
    if not state then return nil end
    return string.format("%d:%d:%d:%d:%d", state.day, state.kills, state.weapons,
        state.ffa and 1 or 0, state.unlocked and 1 or 0)
end

function Objectives.decode(value)
    if type(value) ~= "string" then return nil end
    local day, kills, weapons, ffa, unlocked = value:match("^(%d+):(%d+):(%d+):([01]):([01])$")
    return Objectives.normalize({ day = tonumber(day), kills = tonumber(kills),
        weapons = tonumber(weapons), ffa = ffa == "1", unlocked = unlocked == "1" })
end

function Objectives.readout(state)
    if not state then return "FFA OBJECTIVES · LOADING" end
    return string.format("FFA %d/1   ·   ELIMS %d/%d   ·   ARMS %d/%d",
        state.ffa and 1 or 0, state.kills, Objectives.ELIMINATIONS,
        math.min(Objectives.WEAPONS, Objectives.weaponCount(state.weapons)), Objectives.WEAPONS)
end

return Objectives
