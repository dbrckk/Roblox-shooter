-- IRON YARD / pure DataStore ledger state machine.
-- No Roblox services or yields: safe inside UpdateAsync's retryable callback
-- and executable in the standalone Luau interpreter for regression tests.
local Ledger = {}
Ledger.STATS = { "xp", "eliminations", "headshots", "victories" }
local MAX_SAFE_INT = 9007199254740991

local function safeInt(value)
    return type(value) == "number" and value == value and value >= 0
        and value < MAX_SAFE_INT and value % 1 == 0
end
Ledger.safeInt = safeInt

function Ledger.zero()
    return { xp = 0, eliminations = 0, headshots = 0, victories = 0 }
end

function Ledger.copyStats(value)
    assert(type(value) == "table", "Missing progression counters")
    local copy = {}
    for _, field in ipairs(Ledger.STATS) do
        local amount = value[field]
        assert(safeInt(amount), "Corrupt or missing progression counter: " .. field)
        copy[field] = amount
    end
    return copy
end

-- Apply a server-authored award as an atomic, validated session snapshot.
-- Validate ALL four fields (including overflow) before replacing the caller's
-- earned state. A bad later field must never partially grant XP or kills.
-- This pure function does not read DataStores or change saved records.
function Ledger.applyGrant(earned, deltas)
    local current = Ledger.copyStats(earned)
    assert(type(deltas) == "table", "Missing progression event")
    local nextEarned = {}
    for _, field in ipairs(Ledger.STATS) do
        local delta = deltas[field]
        if delta == nil then delta = 0 end
        assert(safeInt(delta) and delta <= 10000,
            "Invalid progression event: " .. field)
        local updated = current[field] + delta
        assert(safeInt(updated), "Progression session counter overflow: " .. field)
        nextEarned[field] = updated
    end
    return nextEarned
end

-- Invalid existing records must be rejected without overwriting earned XP.
function Ledger.normalize(raw)
    if raw == nil then
        return { schema = 1, xp = 0, eliminations = 0,
            headshots = 0, victories = 0, lock = nil, lastSession = nil }
    end
    assert(type(raw) == "table" and raw.schema == 1,
        "Unsupported progression version")
    local stats = Ledger.copyStats(raw)
    local data = { schema = 1, lock = nil, lastSession = nil }
    for _, field in ipairs(Ledger.STATS) do data[field] = stats[field] end

    if raw.lock ~= nil then
        local lock = raw.lock
        assert(type(lock) == "table" and type(lock.owner) == "string"
            and #lock.owner >= 8 and safeInt(lock.expiresAt),
            "Corrupt progression lock")
        local committed = Ledger.copyStats(lock.committed)
        -- The saved total must contain every acknowledged session counter.
        -- A corrupted lock must never convince the HUD or a release retry
        -- that unsaved XP already exists in durable storage.
        for _, field in ipairs(Ledger.STATS) do
            assert(committed[field] <= data[field],
                "Progression lock exceeds stored counter: " .. field)
        end
        data.lock = {
            owner = lock.owner,
            expiresAt = lock.expiresAt,
            committed = committed,
        }
    end
    if raw.lastSession ~= nil then
        local marker = raw.lastSession
        assert(type(marker) == "table" and type(marker.owner) == "string"
            and #marker.owner >= 8, "Corrupt progression release marker")
        local committed = Ledger.copyStats(marker.committed)
        -- lastSession may outlive the lock and coexist with a newer writer,
        -- but the saved totals must still cover its acknowledged counters.
        for _, field in ipairs(Ledger.STATS) do
            assert(committed[field] <= data[field],
                "Progression release exceeds stored counter: " .. field)
        end
        data.lastSession = {
            owner = marker.owner,
            committed = committed,
        }
    end
    return data
end

local function validateContext(token, timestamp, leaseSeconds)
    assert(type(token) == "string" and #token >= 8, "Invalid session token")
    assert(safeInt(timestamp), "Invalid DataStore lease timestamp")
    assert(safeInt(leaseSeconds) and leaseSeconds > 0,
        "Invalid DataStore lease duration")
end

function Ledger.acquire(previous, token, timestamp, leaseSeconds)
    validateContext(token, timestamp, leaseSeconds)
    local data = Ledger.normalize(previous)
    local lock = data.lock
    if lock and lock.owner ~= token and lock.expiresAt > timestamp then
        return nil -- Active second server: never replace another writer.
    end
    if lock and lock.owner == token then
        -- Repeated acquire from the same session MUST retain committed deltas.
        lock.expiresAt = timestamp + leaseSeconds
    else
        data.lock = {
            owner = token, expiresAt = timestamp + leaseSeconds,
            committed = Ledger.zero(),
        }
    end
    return data
end

function Ledger.commit(previous, token, earnedSnapshot, timestamp, leaseSeconds, release)
    validateContext(token, timestamp, leaseSeconds)
    local snapshot = Ledger.copyStats(earnedSnapshot)
    local data = Ledger.normalize(previous)
    if not data.lock or data.lock.owner ~= token then
        -- A release retry may arrive after a different server acquires the
        -- already-released key. Acknowledgement is safe only when lastSession
        -- proves every counter persisted, regardless of the NEW lock owner.
        -- Never overwrite or release the other server's active lease.
        if release and data.lastSession
            and data.lastSession.owner == token then
            for _, field in ipairs(Ledger.STATS) do
                if data.lastSession.committed[field] < snapshot[field] then
                    return nil
                end
            end
            return data
        end
        return nil
    end

    for _, field in ipairs(Ledger.STATS) do
        local committed = data.lock.committed[field]
        local increment = math.max(0, snapshot[field] - committed)
        local updated = data[field] + increment
        assert(safeInt(updated), "Progression total overflow")
        data[field] = updated
        data.lock.committed[field] = math.max(committed, snapshot[field])
    end
    if release then
        data.lastSession = {
            owner = token, committed = Ledger.copyStats(data.lock.committed),
        }
        data.lock = nil
    else
        data.lock.expiresAt = timestamp + leaseSeconds
    end
    return data
end

-- The stored total already includes this session's acknowledged writes.
-- Subtract its committed snapshot before adding local earned XP in the HUD.
-- This also recovers a lost acquire acknowledgement after an autosave.
function Ledger.sessionBase(data, token)
    local totals = Ledger.copyStats(data)
    if data.lock and data.lock.owner == token then
        local committed = Ledger.copyStats(data.lock.committed)
        for _, field in ipairs(Ledger.STATS) do
            assert(totals[field] >= committed[field],
                "Committed session counters exceed stored total: " .. field)
            totals[field] -= committed[field]
        end
    end
    return totals
end

function Ledger.levelForXP(xp)
    assert(safeInt(xp), "Invalid XP total")
    return math.clamp(1 + math.floor(math.sqrt(xp / 250)), 1, 1000)
end

return Ledger
