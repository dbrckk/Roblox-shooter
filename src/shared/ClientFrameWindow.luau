-- IRON YARD / fixed-memory rolling frame-time diagnostics.
-- Pure Luau, enabled only while the private PERF display is open.
local FrameWindow = {}
FrameWindow.CAPACITY = 240

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function FrameWindow.new()
    return { values = {}, count = 0, nextIndex = 1, sumMs = 0 }
end

function FrameWindow.clear(window)
    table.clear(window.values)
    window.count = 0
    window.nextIndex = 1
    window.sumMs = 0
end

function FrameWindow.push(window, seconds)
    -- Reject invalid clock data and app-suspension gaps above 10 seconds.
    if not finite(seconds) or seconds <= 0 or seconds > 10 then return false end
    local ms = seconds * 1000
    local index = window.nextIndex
    local displaced = window.values[index] or 0
    window.values[index] = ms
    window.sumMs += ms - displaced
    window.count = math.min(window.count + 1, FrameWindow.CAPACITY)
    window.nextIndex = index % FrameWindow.CAPACITY + 1
    return true
end

function FrameWindow.snapshot(window)
    local count = window.count
    if count == 0 then return nil end
    -- Sort only on the once-per-second update, never on RenderStepped.
    local sorted = table.create(count)
    local slow33, slow50 = 0, 0
    for i = 1, count do
        local ms = window.values[i]
        sorted[i] = ms
        if ms > 33.333 then slow33 += 1 end
        if ms > 50 then slow50 += 1 end
    end
    table.sort(sorted)
    local mean = window.sumMs / count
    return {
        count = count,
        fps = 1000 / mean,
        meanMs = mean,
        p95Ms = sorted[math.ceil(count * 0.95)],
        p99Ms = sorted[math.ceil(count * 0.99)],
        peakMs = sorted[count],
        slow33 = slow33,
        slow50 = slow50,
    }
end

return FrameWindow
