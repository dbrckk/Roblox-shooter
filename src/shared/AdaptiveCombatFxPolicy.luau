-- IRON YARD / client-only adaptive transient FX budget for Android.
-- Keep premium PBR, hit confirmation and combat authority untouched.
-- Fixed-memory, no additional RenderStepped connection, no network traffic.
local TransientFxPool = require("./TransientFxPool")
local Policy = {}
local WINDOW_SECONDS = 1.0
local SLOW_FRAME_MS = 38
local FAST_FRAME_MS = 23

local function clearWindow(state)
    state.elapsed = 0
    state.frames = 0
end

local function reset(state)
    state.tier = 0
    state.slowStreak = 0
    state.fastStreak = 0
    clearWindow(state)
end

function Policy.new()
    return {tier = 0, preset = nil, touch = nil,
        elapsed = 0, frames = 0, slowStreak = 0, fastStreak = 0}
end

-- QUALITY mobile: 72 -> 48 -> 24; BALANCED: 48 -> 24.
-- ECO stays at 24; desktop never changes. The existing priority-aware
-- pool still admits confirmed hits and local muzzle flashes first.
function Policy.cap(state, preset, touch)
    local normal = TransientFxPool.cap(preset, touch)
    if touch ~= true or preset == "ECO" or type(state) ~= "table"
        or type(state.tier) ~= "number" or state.tier < 1 then
        return normal
    end
    if state.tier == 1 then
        return math.min(normal, preset == "QUALITY" and 48 or 24)
    end
    return math.min(normal, 24)
end

-- One O(1) sample on the EXISTING weapon render callback. A single hitch
-- or Android background/resume gap cannot trigger a graphics downgrade.
-- Require two consecutive slow 1s windows to reduce ONE tier, and four
-- consecutive fast windows to restore ONE tier. Midrange holds steady.
function Policy.sample(state, dt, preset, touch)
    local normal = TransientFxPool.cap(preset, touch)
    if type(state) ~= "table" then return normal end
    if state.preset ~= preset or state.touch ~= touch then
        state.preset = preset
        state.touch = touch
        reset(state)
    end
    if touch ~= true or preset == "ECO" then
        reset(state)
        return normal
    end
    if type(dt) ~= "number" or dt ~= dt or dt <= 0
        or dt == math.huge or dt > 0.25 then
        -- Clear inconclusive measurements, retain the existing cap.
        clearWindow(state)
        state.slowStreak = 0
        state.fastStreak = 0
        return Policy.cap(state, preset, touch)
    end
    state.elapsed += dt
    state.frames += 1
    if state.elapsed >= WINDOW_SECONDS then
        local meanMs = 1000 * state.elapsed / state.frames
        clearWindow(state)
        if meanMs > SLOW_FRAME_MS then
            state.slowStreak += 1
            state.fastStreak = 0
            if state.slowStreak >= 2 then
                local maxTier = preset == "QUALITY" and 2 or 1
                state.tier = math.min(maxTier, state.tier + 1)
                state.slowStreak = 0
            end
        elseif meanMs < FAST_FRAME_MS then
            state.fastStreak += 1
            state.slowStreak = 0
            if state.fastStreak >= 4 then
                state.tier = math.max(0, state.tier - 1)
                state.fastStreak = 0
            end
        else
            state.slowStreak = 0
            state.fastStreak = 0
        end
    end
    return Policy.cap(state, preset, touch)
end

return Policy
