-- IRON YARD / strictly client-local, opt-in microprofiler for weapon swaps.
-- No networking, persistence, Instances, or per-frame measurement work.
-- Shared ModuleScript has separate require caches on server/each client.
-- A disabled profiler does not collect or retain any measurements.
local Metrics = {}

Metrics.WINDOW = 48
local enabled = false
local cachedParts = nil

local function group()
    return {count = 0, totalMs = 0, peakMs = 0, lastMs = 0,
        samples = {}, nextSlot = 1}
end

local function reset()
    return {
        reuse = group(),
        build = group(),
        lod = group(),
        initial = group(),
    }
end

local data = reset()

local function finite(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function Metrics.enable(value)
    enabled = value == true
    data = reset()
    cachedParts = nil
end

function Metrics.isEnabled()
    return enabled
end

function Metrics.noteCache(parts)
    if not enabled then return end
    if finite(parts) and parts == math.floor(parts) then
        cachedParts = parts
    end
end

-- Kind is decided AFTER the real equip and asset selection have finished.
-- Sample only when owner/Studio explicitly opens the private PERF panel.
function Metrics.record(kind, durationSeconds, visibleParts, retainedParts)
    if not enabled or not data[kind] or not finite(durationSeconds)
        or not finite(visibleParts) or visibleParts ~= math.floor(visibleParts) then
        return false
    end
    local item = data[kind]
    local milliseconds = durationSeconds * 1000
    if milliseconds == math.huge then return false end
    item.count += 1
    item.totalMs += milliseconds
    item.peakMs = math.max(item.peakMs, milliseconds)
    item.lastMs = milliseconds
    item.samples[item.nextSlot] = milliseconds
    item.nextSlot = item.nextSlot % Metrics.WINDOW + 1
    Metrics.noteCache(retainedParts)
    return true
end

local function summarize(item)
    local recent = {}
    for i = 1, #item.samples do
        recent[i] = item.samples[i]
    end
    local windowTotal = 0
    for _, value in ipairs(recent) do
        windowTotal += value
    end
    local windowMean = #recent > 0 and windowTotal / #recent or 0
    table.sort(recent)
    local p95 = #recent > 0
        and recent[math.ceil(#recent * 0.95)] or 0
    return {
        count = item.count,
        meanMs = item.count > 0 and item.totalMs / item.count or 0,
        windowMeanMs = windowMean,
        p95Ms = p95,
        peakMs = item.peakMs,
        lastMs = item.lastMs,
        windowCount = #recent,
    }
end

-- Snapshot sorting is limited to 48 samples/type and runs only when PERF UI
-- refreshes, not in the weapon's camera-aligned RenderStepped callback.
function Metrics.snapshot()
    if not enabled then return nil end
    return {
        reuse = summarize(data.reuse),
        build = summarize(data.build),
        lod = summarize(data.lod),
        initial = summarize(data.initial),
        cachedParts = cachedParts,
    }
end

return Metrics
