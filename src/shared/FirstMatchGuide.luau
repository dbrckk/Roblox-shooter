-- IRON YARD / deterministic first-match briefing; no persistent data or input locks.
local Guide = {}

local ACTION_LABELS = {
    FIRE = "FIRST ENGAGEMENT",
    RELOAD = "RELOAD FROM COVER",
    DUEL = "CHOOSE 1V1 OR 2V2",
}
local CONTROLS = {
    keyboard = { FIRE = "LEFT CLICK TO FIRE", RELOAD = "PRESS R", DUEL = "PRESS V FOR DUELS" },
    touch = { FIRE = "TAP FIRE TO SHOOT", RELOAD = "TAP RLD", DUEL = "TAP DUELS" },
    gamepad = { FIRE = "PRESS RT TO FIRE", RELOAD = "PRESS X", DUEL = "PRESS R3 FOR DUELS" },
}

function Guide.objective(limit)
    local n = type(limit) == "number" and limit == limit
        and math.floor(limit) or 15
    return string.format("FIRST TO %d ELIMINATIONS", math.clamp(n, 1, 100))
end

function Guide.nextAction(completed, shown)
    if not completed.FIRE then return not shown.FIRE and "FIRE" or nil end
    if not completed.RELOAD and not shown.RELOAD then return "RELOAD" end
    if not completed.DUEL and not shown.DUEL then return "DUEL" end
    return nil
end

function Guide.prompt(action, device)
    return ACTION_LABELS[action], CONTROLS[device][action]
end

return Guide
