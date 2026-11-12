-- IRON YARD / private client-only first-person CPU instrumentation.
-- CPU callback duration is not GPU render time and is never interpreted
-- as absolute game performance. No game services, remotes, or per-frame tables.
-- Called only when owner/Studio explicitly opens the PERF panel.
local Diagnostics = {}
local WINDOW_SECONDS = 1

local function valid(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function Diagnostics.new()
    return {elapsed = 0, frames = 0, sumMs = 0, peakMs = 0}
end

function Diagnostics.clear(state)
    state.elapsed = 0
    state.frames = 0
    state.sumMs = 0
    state.peakMs = 0
end

-- An Android backgrounding gap cannot contaminate the next second.
-- Return a snapshot once per measured second, nil on all other frames.
function Diagnostics.record(state, dt, cpuSeconds)
    if type(state) ~= "table" then return nil end
    if not valid(dt) or dt <= 0 or dt > 0.25
        or not valid(cpuSeconds) or cpuSeconds > 0.25 then
        Diagnostics.clear(state)
        return nil
    end
    local ms = cpuSeconds * 1000
    state.elapsed += dt
    state.frames += 1
    state.sumMs += ms
    state.peakMs = math.max(state.peakMs, ms)
    if state.elapsed < WINDOW_SECONDS then return nil end

    local result = {
        count = state.frames,
        meanMs = state.sumMs / state.frames,
        peakMs = state.peakMs,
    }
    Diagnostics.clear(state)
    return result
end

return Diagnostics
