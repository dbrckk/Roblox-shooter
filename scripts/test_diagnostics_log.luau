-- IRON YARD / executable bounded error log (LOT 0b).
-- Verifies deduplication, eviction and saturation reporting. It does not prove
-- that a published server produces these warnings: it proves the summary that
-- would be read from one is bounded and truthful about what it dropped.
local DiagnosticsLog = require("../src/shared/DiagnosticsLog")

local log = DiagnosticsLog.new()
assert(log.capacity == DiagnosticsLog.DEFAULT_CAPACITY, "Default capacity drifted")
assert(log.size == 0 and log.total == 0 and log.evicted == 0, "A fresh log is empty")
assert(DiagnosticsLog.saturated(log) == false, "A fresh log is not saturated")

-- 1. Identical warnings coalesce into a counter instead of filling the log.
assert(DiagnosticsLog.record(log, "match", "spawn failed", 1) == 1, "first warning")
assert(DiagnosticsLog.record(log, "match", "spawn failed", 2) == 2, "repeat warning")
assert(DiagnosticsLog.record(log, "match", "spawn failed", 3) == 3, "third warning")
assert(log.size == 1, "A repeated warning must stay one entry")
assert(log.total == 1, "Repeats must not count as new distinct messages")
local row = DiagnosticsLog.snapshot(log).entries[1]
assert(row.count == 3, "Repeat count lost")
assert(row.firstSeen == 1 and row.lastSeen == 3, "Seen timestamps must advance")

-- 2. A different category is a different entry, even with the same text.
DiagnosticsLog.record(log, "progression", "spawn failed", 4)
assert(log.size == 2, "Category must be part of the identity")

-- 3. The log stays bounded: the oldest entry is evicted, and says so.
local small = DiagnosticsLog.new(3)
DiagnosticsLog.record(small, "a", "one", 1)
DiagnosticsLog.record(small, "a", "two", 2)
DiagnosticsLog.record(small, "a", "three", 3)
assert(small.size == 3 and DiagnosticsLog.saturated(small) == false,
    "Three entries must fit a capacity of three")
DiagnosticsLog.record(small, "a", "four", 4)
assert(small.size == 3, "Capacity must be enforced")
assert(DiagnosticsLog.saturated(small) == true, "Eviction must be reported")
local messages = {}
for _, entry in ipairs(DiagnosticsLog.snapshot(small).entries) do
    messages[entry.message] = true
end
assert(messages.one == nil, "The oldest warning must be evicted first")
assert(messages.four == true, "The newest warning must be kept")

-- 4. A re-seen evicted warning is a new entry, not a resurrected one.
DiagnosticsLog.record(small, "a", "one", 5)
local revived = DiagnosticsLog.snapshot(small)
local found = nil
for _, entry in ipairs(revived.entries) do
    if entry.message == "one" then found = entry end
end
assert(found and found.count == 1, "An evicted warning restarts at one")
assert(small.size == 3, "Re-adding an evicted warning keeps the bound")

-- 5. Capacity is clamped so one caller cannot make the log a memory leak.
local huge = DiagnosticsLog.new(10000)
assert(huge.capacity == DiagnosticsLog.MAX_CAPACITY, "Capacity must be clamped")

-- 6. Long text is truncated, and truncation is part of the identity: two
-- messages sharing a prefix become one counter instead of unbounded rows.
local wide = DiagnosticsLog.new()
local prefix = string.rep("x", DiagnosticsLog.MAX_MESSAGE)
DiagnosticsLog.record(wide, string.rep("c", DiagnosticsLog.MAX_CATEGORY + 10),
    prefix .. "first", 1)
DiagnosticsLog.record(wide, string.rep("c", DiagnosticsLog.MAX_CATEGORY + 10),
    prefix .. "second", 2)
assert(wide.size == 1, "Truncated duplicates must coalesce")
local wideRow = wide.entries[1]
assert(#wideRow.message == DiagnosticsLog.MAX_MESSAGE, "Message must be truncated")
assert(#wideRow.category == DiagnosticsLog.MAX_CATEGORY, "Category must be truncated")
assert(wideRow.count == 2, "Coalesced truncated warnings must keep their count")

-- 7. The snapshot is ordered by volume, then by age.
local ordered = DiagnosticsLog.new()
DiagnosticsLog.record(ordered, "a", "rare", 1)
DiagnosticsLog.record(ordered, "a", "loud", 2)
DiagnosticsLog.record(ordered, "a", "loud", 3)
DiagnosticsLog.record(ordered, "a", "loud", 4)
local rows = DiagnosticsLog.snapshot(ordered).entries
assert(rows[1].message == "loud" and rows[2].message == "rare",
    "The loudest warning must come first")

-- 7 bis. Warnings already emitted elsewhere are bucketed, never rewritten:
-- an explicit prefix wins, then the first keyword, then a generic bucket.
local categorized = {
    { "[Match] spawn failed", "match" },
    { "[PROGRESSION] commit failed", "progression" },
    { "DataStore write failed", "progression" },
    { "weapon reload rejected", "weapon" },
    { "duel bout expired", "match" },
    { "round reset requested", "match" },
    { "spawn blocked by obstacle", "spawn" },
    { "movement remote rejected", "movement" },
    { "bot navigation budget exhausted", "bot" },
    { "something unexpected happened", "server" },
}
for _, case in ipairs(categorized) do
    local got = DiagnosticsLog.categorize(case[1])
    assert(got == case[2], string.format("%q: expected %s, got %s", case[1],
        case[2], got))
end
-- A prefix wins over any keyword inside the text, and is lowercased.
assert(DiagnosticsLog.categorize("[Weapon] round timer stale") == "weapon",
    "A bracketed category must win over keywords")
-- The category is bounded like every other stored field.
local longPrefix = "[" .. string.rep("c", DiagnosticsLog.MAX_CATEGORY + 20) .. "] x"
assert(#DiagnosticsLog.categorize(longPrefix) == DiagnosticsLog.MAX_CATEGORY,
    "A bracketed category must be truncated")
-- Invalid text still fails loudly instead of landing in a silent bucket.
assert(not pcall(function() DiagnosticsLog.categorize("") end),
    "An empty warning must be rejected")
assert(not pcall(function() DiagnosticsLog.categorize(nil) end),
    "A missing warning must be rejected")

-- 8. The snapshot is a detached copy.
rows[1].count = 999
rows[1].message = "rewritten"
local after = DiagnosticsLog.snapshot(ordered)
assert(after.entries[1].count == 3 and after.entries[1].message == "loud",
    "A snapshot must not alias the live log")

-- 9. Invalid input fails loudly instead of corrupting the summary.
local function rejects(operation, label)
    assert(not pcall(operation), "Log accepted an invalid input: " .. label)
end
rejects(function() DiagnosticsLog.record(log, "", "text", 1) end, "empty category")
rejects(function() DiagnosticsLog.record(log, 7, "text", 1) end, "non-string category")
rejects(function() DiagnosticsLog.record(log, "a", "", 1) end, "empty message")
rejects(function() DiagnosticsLog.record(log, "a", nil, 1) end, "missing message")
rejects(function() DiagnosticsLog.record(log, "a", "text", -1) end, "negative time")
rejects(function() DiagnosticsLog.record(log, "a", "text", 0 / 0) end, "NaN time")
rejects(function() DiagnosticsLog.record(nil, "a", "text", 1) end, "missing state")
rejects(function() DiagnosticsLog.new(0) end, "zero capacity")
rejects(function() DiagnosticsLog.new(1.5) end, "fractional capacity")
rejects(function() DiagnosticsLog.snapshot(nil) end, "missing state")
assert(log.size == 2, "Rejected warnings must not be stored")

print("IRON YARD bounded diagnostics log (dedupe, eviction, clamp, copies): OK")
