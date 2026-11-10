-- IRON YARD / presentation-only defeat messaging.
-- The server owns match phase, outcome and respawn. Never derive awards here.
local Policy = {}

local function countdown(value)
    if type(value) ~= "number" or value ~= value or value < 0
        or value >= math.huge then return 0 end
    return math.max(0, math.ceil(value))
end

function Policy.labels(mode, phase, boutSeconds, respawnSeconds, verdict)
    if mode == "DUEL" then
        local title = phase == "DUEL_BREAK"
            and (verdict == "ROUND LOST" and "ROUND LOST"
                or verdict == "ROUND DRAW" and "ROUND DRAW"
                or verdict == "ROUND WON" and "ROUND WON"
                or "ROUND FINISHED")
            or "ELIMINATED"
        local timer = phase == "DUEL_BREAK"
            and ("NEXT BOUT IN  " .. countdown(boutSeconds) .. "s")
            or "AWAITING ROUND RESULT"
        return title, timer, "DUEL  /  NO SECOND LIFE THIS BOUT"
    end
    local remaining = countdown(respawnSeconds)
    return "ELIMINATED",
        remaining > 0 and ("REDEPLOY IN  " .. remaining .. "s")
            or "REDEPLOYING...",
        "SPAWN SHIELD 2.5s  /  SHOOT TO CANCEL"
end

return Policy
