-- IRON YARD / bounded, privacy-free, opt-in bot performance aggregates.
-- Pure Luau, with no engine dependencies and no player positions/names.
local Profile = {}
Profile.WINDOW_SECONDS = 5

local COUNTERS = {
    think = true, pose = true, targetRay = true, navRay = true,
    tacticsRay = true, muzzleRay = true, shotRay = true,
    pathStarted = true, pathDeferred = true, pathFinished = true,
    moveIssued = true, botShot = true,
}
local TIMINGS = { thinkMs = true, poseMs = true, pathMs = true }

function Profile.new(now)
    return { since = now, counters = {}, timings = {} }
end

local function finite(n)
    return type(n) == "number" and n == n
        and n < math.huge and n > -math.huge
end

function Profile.count(state, key, amount)
    if not COUNTERS[key] or not finite(amount or 1)
        or (amount or 1) <= 0 or (amount or 1) > 100000 then return false end
    state.counters[key] = (state.counters[key] or 0) + (amount or 1)
    return true
end

function Profile.timing(state, key, milliseconds)
    if not TIMINGS[key] or not finite(milliseconds)
        or milliseconds < 0 or milliseconds > 120000 then return false end
    local m = state.timings[key]
    if not m then
        m = { count = 0, sum = 0, peak = 0 }
        state.timings[key] = m
    end
    m.count += 1
    m.sum += milliseconds
    m.peak = math.max(m.peak, milliseconds)
    return true
end

local function oneDecimal(n)
    return math.floor(n * 10 + 0.5) / 10
end

function Profile.flush(state, now, livingBots)
    if not finite(now) or not finite(state.since)
        or now <= state.since then return nil end
    local elapsed = now - state.since
    local packet = {
        seconds = oneDecimal(elapsed),
        bots = math.clamp(math.floor(tonumber(livingBots) or 0), 0, 4),
        rates = {}, timings = {},
    }
    for name in pairs(COUNTERS) do
        packet.rates[name] = oneDecimal((state.counters[name] or 0) / elapsed)
    end
    for name in pairs(TIMINGS) do
        local m = state.timings[name]
        packet.timings[name] = {
            mean = m and m.count > 0 and oneDecimal(m.sum / m.count) or 0,
            peak = m and oneDecimal(m.peak) or 0,
            samples = m and m.count or 0,
        }
    end
    state.since = now
    table.clear(state.counters)
    table.clear(state.timings)
    return packet
end

return Profile
