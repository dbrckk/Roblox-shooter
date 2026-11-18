-- IRON YARD / pure, acknowledged DataStore XP presentation for all client HUDs.
local Readout = {}
local MAX_SAFE_INT = 9007199254740991

local function xpForRank(rank)
    return 250 * (rank - 1) * (rank - 1)
end

function Readout.count(value)
    if type(value) ~= "number" or value ~= value
        or value < 0 or value >= MAX_SAFE_INT then
        return 0
    end
    return math.floor(value)
end

function Readout.rank(xp, level)
    local amount = Readout.count(xp)
    local rank = math.clamp(Readout.count(level), 1, 1000)
    if rank >= 1000 then
        return { rank = rank, maxed = true, toNext = 0, fraction = 1 }
    end
    local start = xpForRank(rank)
    local target = xpForRank(rank + 1)
    return {
        rank = rank,
        maxed = false,
        toNext = math.max(0, target - amount),
        fraction = math.clamp((amount - start) / (target - start), 0, 1),
    }
end

function Readout.finishGoal(status, xp, nextFinish)
    if status == nil or status == "LOADING" then return "FINISHES LOADING" end
    if not nextFinish then return "ALL FINISHES UNLOCKED" end
    local remaining = xpForRank(nextFinish.level) - Readout.count(xp)
    if remaining <= 0 then
        -- The XP and level attributes can arrive in different callbacks.
        return nextFinish.name .. " · RANK SYNCING"
    end
    return string.format("%s · %d XP LEFT", nextFinish.name, remaining)
end

-- ONLINE means a lease exists, not that new earned XP has reached DataStore.
-- Replication ordering can temporarily yield savedXP > xp; never mark it SAVED.
function Readout.save(status, xp, savedXP)
    local earned, acknowledged = Readout.count(xp), Readout.count(savedXP)
    if status == "ONLINE" then
        if acknowledged == earned then
            return { label = "CAREER / SAVED", compact = "SAVED",
                tone = "saved", pending = 0 }
        elseif acknowledged < earned then
            local pending = earned - acknowledged
            return {
                label = string.format("CAREER / %d XP SAVE PENDING", pending),
                compact = string.format("%d XP PENDING", pending),
                tone = "pending", pending = pending,
            }
        end
        return { label = "CAREER / SYNCING...", compact = "SAVE SYNCING",
            tone = "pending", pending = 0 }
    elseif status == "LOADING" then
        return { label = "CAREER / LOADING...", compact = "SAVE WAIT",
            tone = "pending", pending = 0 }
    elseif status == "STUDIO" then
        return { label = "STUDIO / SESSION ONLY", compact = "SESSION ONLY",
            tone = "warning", pending = 0 }
    elseif status == "LOCKED" then
        return { label = "SAVE BUSY / RETRYING", compact = "SAVE OFFLINE",
            tone = "warning", pending = 0 }
    end
    return { label = "SAVE NOT CONFIRMED / RETRYING", compact = "SAVE OFFLINE",
        tone = "warning", pending = 0 }
end

return Readout
