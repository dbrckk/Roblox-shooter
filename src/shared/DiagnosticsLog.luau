-- IRON YARD / bounded post-publication error log (LOT 0b of the RIVALS plan).
-- The server already warns about failures; those warns disappear into the
-- Studio output and are invisible on a published place. This module keeps a
-- small, deduplicated, bounded summary so the real state of a version can be
-- read later instead of guessed.
-- Pure: no remote, no DataStore, no HTTP. The caller decides where a snapshot
-- is published, if anywhere.
local DiagnosticsLog = {}

DiagnosticsLog.DEFAULT_CAPACITY = 64
DiagnosticsLog.MAX_CAPACITY = 256
DiagnosticsLog.MAX_CATEGORY = 24
DiagnosticsLog.MAX_MESSAGE = 200
DiagnosticsLog.SEPARATOR = "\31"

local function truncated(value, limit)
    assert(type(value) == "string" and #value > 0, "Invalid log text")
    if #value > limit then return string.sub(value, 1, limit) end
    return value
end

-- capacity defaults to 64 entries; larger capacities are clamped so one
-- caller cannot turn an error log into a memory leak.
function DiagnosticsLog.new(capacity)
    local size = DiagnosticsLog.DEFAULT_CAPACITY
    if capacity ~= nil then
        assert(type(capacity) == "number" and capacity == capacity
            and capacity >= 1 and capacity < math.huge and capacity % 1 == 0,
            "Invalid log capacity")
        size = math.min(capacity, DiagnosticsLog.MAX_CAPACITY)
    end
    return {
        capacity = size,
        entries = {},
        index = {},
        size = 0,
        total = 0,
        evicted = 0,
    }
end

-- Category heuristics for warnings the server already emits and that are not
-- going to be rewritten: an explicit `[Match]` prefix wins, otherwise the first
-- keyword found decides, otherwise "server". A loose keyword match ("robot"
-- contains "bot") is acceptable here: a bucket is a filter, not a contract.
DiagnosticsLog.KEYWORDS = {
    { "datastore", "progression" },
    { "progression", "progression" },
    { "weapon", "weapon" },
    { "duel", "match" },
    { "round", "match" },
    { "match", "match" },
    { "spawn", "spawn" },
    { "movement", "movement" },
    { "bot", "bot" },
}
function DiagnosticsLog.categorize(message)
    local text = truncated(message, DiagnosticsLog.MAX_MESSAGE)
    local bracketed = string.match(text, "^%[([^%]]+)%]")
    if bracketed ~= nil and #bracketed > 0 then
        return truncated(string.lower(bracketed), DiagnosticsLog.MAX_CATEGORY)
    end
    local lower = string.lower(text)
    for _, row in ipairs(DiagnosticsLog.KEYWORDS) do
        if string.find(lower, row[1], 1, true) ~= nil then return row[2] end
    end
    return "server"
end

-- Records one warning. An identical (category, message) pair is coalesced into
-- a counter instead of filling the log; the oldest entry is evicted when full.
-- Returns how many times this exact warning has been seen.
function DiagnosticsLog.record(state, category, message, now)
    assert(type(state) == "table", "Missing log state")
    local scope = truncated(category, DiagnosticsLog.MAX_CATEGORY)
    local text = truncated(message, DiagnosticsLog.MAX_MESSAGE)
    assert(type(now) == "number" and now == now and now >= 0
        and now < math.huge, "Invalid log timestamp")
    local key = scope .. DiagnosticsLog.SEPARATOR .. text
    local existing = state.index[key]
    if existing ~= nil then
        existing.count = existing.count + 1
        existing.lastSeen = now
        return existing.count
    end
    if state.size >= state.capacity then
        local oldest = table.remove(state.entries, 1)
        state.index[oldest.category .. DiagnosticsLog.SEPARATOR .. oldest.message] = nil
        state.size = state.size - 1
        state.evicted = state.evicted + 1
    end
    local entry = {
        category = scope,
        message = text,
        count = 1,
        firstSeen = now,
        lastSeen = now,
    }
    table.insert(state.entries, entry)
    state.index[key] = entry
    state.size = state.size + 1
    state.total = state.total + 1
    return 1
end

-- Most frequent first, then oldest first, so a repeated failure dominates.
function DiagnosticsLog.snapshot(state)
    assert(type(state) == "table", "Missing log state")
    local rows = {}
    for _, entry in ipairs(state.entries) do
        table.insert(rows, {
            category = entry.category,
            message = entry.message,
            count = entry.count,
            firstSeen = entry.firstSeen,
            lastSeen = entry.lastSeen,
        })
    end
    table.sort(rows, function(a, b)
        if a.count == b.count then return a.firstSeen < b.firstSeen end
        return a.count > b.count
    end)
    return {
        capacity = state.capacity,
        size = state.size,
        distinct = state.total,
        evicted = state.evicted,
        entries = rows,
    }
end

-- True when the log had to drop history to stay bounded: the dashboard must
-- say so rather than pretending the summary is complete.
function DiagnosticsLog.saturated(state)
    assert(type(state) == "table", "Missing log state")
    return state.evicted > 0
end

return DiagnosticsLog
