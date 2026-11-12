-- IRON YARD / pure audit ledger for anything that must be released (LOT C1).
-- The engine has no cheap answer to "did this round leave something behind?".
-- This module keeps an exact count of what is live, per kind, so a leak shows
-- up as a size that does not return to zero instead of as a slow frame drop
-- nobody can attribute.
-- It never touches Roblox: the server and client pass their own identifiers.
local LifecycleLedger = {}

LifecycleLedger.KINDS = { "player", "weapon", "listener", "fx", "impact", "pose" }
-- One kind cannot be allowed to grow without bound: past this the ledger
-- refuses the entry and says so, which is a bug signal, not a silent success.
LifecycleLedger.MAX_PER_KIND = 256

local VALID_KIND = {}
for _, kind in ipairs(LifecycleLedger.KINDS) do VALID_KIND[kind] = true end

local function kindOf(kind)
    assert(type(kind) == "string" and VALID_KIND[kind],
        "Unknown lifecycle kind: " .. tostring(kind))
    return kind
end

local function identifier(id)
    assert((type(id) == "string" and #id > 0) or type(id) == "number",
        "Invalid lifecycle identifier")
    return id
end

function LifecycleLedger.new()
    local state = { live = {}, counts = {}, total = 0, peak = 0,
        overflow = 0, duplicates = 0 }
    for _, kind in ipairs(LifecycleLedger.KINDS) do
        state.live[kind] = {}
        state.counts[kind] = 0
    end
    return state
end

-- Returns true when the resource is now tracked. A second acquire of the same
-- (kind, id) is a DOUBLE REGISTRATION: it returns false, increments
-- `duplicates`, and leaves the single entry in place, so two listeners cannot
-- masquerade as two live resources.
function LifecycleLedger.acquire(state, kind, id)
    assert(type(state) == "table", "Missing ledger state")
    local scope = kindOf(kind)
    local key = identifier(id)
    if state.live[scope][key] then
        state.duplicates = state.duplicates + 1
        return false
    end
    if state.counts[scope] >= LifecycleLedger.MAX_PER_KIND then
        state.overflow = state.overflow + 1
        return false
    end
    state.live[scope][key] = true
    state.counts[scope] = state.counts[scope] + 1
    state.total = state.total + 1
    if state.total > state.peak then state.peak = state.total end
    return true
end

function LifecycleLedger.release(state, kind, id)
    assert(type(state) == "table", "Missing ledger state")
    local scope = kindOf(kind)
    local key = identifier(id)
    if not state.live[scope][key] then return false end
    state.live[scope][key] = nil
    state.counts[scope] = state.counts[scope] - 1
    state.total = state.total - 1
    return true
end

-- Round reset, player departure and weapon unequip all release a whole kind.
-- Returns how many entries were actually dropped: zero means nothing was
-- holding that kind, which is itself useful to know.
function LifecycleLedger.releaseKind(state, kind)
    assert(type(state) == "table", "Missing ledger state")
    local scope = kindOf(kind)
    local dropped = state.counts[scope]
    state.live[scope] = {}
    state.counts[scope] = 0
    state.total = state.total - dropped
    return dropped
end

function LifecycleLedger.releaseAll(state)
    assert(type(state) == "table", "Missing ledger state")
    local dropped = 0
    for _, kind in ipairs(LifecycleLedger.KINDS) do
        dropped = dropped + LifecycleLedger.releaseKind(state, kind)
    end
    return dropped
end

function LifecycleLedger.size(state, kind)
    assert(type(state) == "table", "Missing ledger state")
    return state.counts[kindOf(kind)]
end

-- Everything still live, sorted so two runs of the same scenario print the
-- same report.
function LifecycleLedger.leaks(state)
    assert(type(state) == "table", "Missing ledger state")
    local rows = {}
    for _, kind in ipairs(LifecycleLedger.KINDS) do
        for id in pairs(state.live[kind]) do
            table.insert(rows, { kind = kind, id = id })
        end
    end
    table.sort(rows, function(a, b)
        if a.kind == b.kind then return tostring(a.id) < tostring(b.id) end
        return a.kind < b.kind
    end)
    return rows
end

function LifecycleLedger.empty(state)
    assert(type(state) == "table", "Missing ledger state")
    return state.total == 0
end

function LifecycleLedger.report(state)
    assert(type(state) == "table", "Missing ledger state")
    local perKind = {}
    for _, kind in ipairs(LifecycleLedger.KINDS) do
        perKind[kind] = state.counts[kind]
    end
    return {
        total = state.total,
        peak = state.peak,
        duplicates = state.duplicates,
        overflow = state.overflow,
        perKind = perKind,
        leaks = LifecycleLedger.leaks(state),
    }
end

return LifecycleLedger
