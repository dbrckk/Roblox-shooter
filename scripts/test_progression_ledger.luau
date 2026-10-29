-- IRON YARD / live Luau regression tests for pure progression transactions.
-- Run: ./luau scripts/test_progression_ledger.luau
local L = require("../src/server/ProgressionLedger")

local A = "11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
local B = "22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
local C = "33333333-cccc-cccc-cccc-cccccccccccc"
local function eq(actual, expected, name)
    assert(actual == expected,
        name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function fails(fn, name)
    local ok = pcall(fn)
    assert(not ok, "Expected data corruption to fail closed: " .. name)
end
local function earnings(xp, kills, headshots, wins)
    return { xp = xp or 0, eliminations = kills or 0,
        headshots = headshots or 0, victories = wins or 0 }
end
local cases = 0
local function case(label, run)
    run()
    cases += 1
    print("OK " .. label)
end

case("create and parse schema v1", function()
    local x = L.normalize(nil)
    eq(x.schema, 1, "version")
    eq(x.xp, 0, "fresh XP")
    eq(x.lock, nil, "initial lock")
    eq(L.levelForXP(0), 1, "zero XP rank")
    eq(L.levelForXP(999), 2, "rank threshold")
    eq(L.levelForXP(1000), 3, "rank transition")
end)

case("one save, duplicate callback, greater snapshot", function()
    local state = L.acquire(nil, A, 1000, 180)
    local oldSnapshot = L.normalize(state)
    state = L.commit(state, A, earnings(135, 1, 1), 1030, 180, false)
    eq(state.xp, 135, "first XP")
    eq(state.headshots, 1, "first headshot")
    eq(oldSnapshot.xp, 0, "UpdateAsync must not mutate prior state")
    state = L.commit(state, A, earnings(135, 1, 1), 1031, 180, false)
    eq(state.xp, 135, "retry must not duplicate XP")
    state = L.commit(state, A, earnings(260, 2, 1), 1032, 180, false)
    eq(state.xp, 260, "incremental XP")
    eq(state.eliminations, 2, "incremental kill")
    state = L.commit(state, A, earnings(260, 2, 1), 1033, 180, true)
    eq(state.lock, nil, "released lock")
    eq(state.lastSession.owner, A, "released session ID")
    state = L.commit(state, A, earnings(260, 2, 1), 1034, 180, true)
    eq(state.xp, 260, "repeated release cannot double count")
    eq(L.commit(state, A, earnings(300, 3, 1), 1034, 180, true),
        nil, "post-release extra earned XP cannot be committed")
end)

case("acquire retry retains previous committed ledger", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(100, 1), 1005, 180, false)
    state = L.acquire(state, A, 1050, 180)
    eq(state.lock.committed.xp, 100, "ack-loss retry keeps snapshot")
    state = L.commit(state, A, earnings(100, 1), 1060, 180, true)
    eq(state.xp, 100, "ack-loss retry must not duplicate XP")
end)

case("reject concurrent live server and stale session", function()
    local state = L.acquire(nil, A, 1000, 180)
    eq(L.acquire(state, B, 1050, 180), nil, "second server refused")
    eq(L.commit(state, B, earnings(200, 2), 1060, 180, false),
        nil, "foreign save refused")
    local expired = L.acquire(state, B, 1180, 180)
    eq(expired.lock.owner, B, "expired lock transferred to other server")
    eq(L.commit(expired, A, earnings(200, 2), 1181, 180, false),
        nil, "stale session refused after lease expiry")
    expired = L.commit(expired, B, earnings(250, 0, 0, 1), 1182, 180, true)
    eq(expired.victories, 1, "winning session committed")
    eq(expired.xp, 250, "victory XP persisted")
    local nextSession = L.acquire(expired, C, 1190, 180)
    eq(nextSession.xp, 250, "new server sees stored career")
end)

case("zero-delta heartbeat renews lease without inflating totals", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(), 1050, 180, false)
    eq(state.lock.expiresAt, 1230, "heartbeat lease refresh")
    eq(state.xp, 0, "heartbeat no earned XP")
end)

case("reject corrupt or downgraded records", function()
    fails(function() L.normalize({schema = 2, xp = 200}) end, "schema")
    fails(function() L.normalize({schema = 1, xp = 250}) end, "missing fields")
    fails(function() L.normalize({schema = 1, xp = -5, eliminations = 0,
        headshots = 0, victories = 0}) end, "negative XP")
    fails(function() L.normalize({schema = 1, xp = 1.5, eliminations = 0,
        headshots = 0, victories = 0}) end, "fractional XP")
    fails(function() L.commit(nil, A, earnings(-1), 1000, 180, true) end,
        "negative reward")
    fails(function() L.acquire(nil, "", 1000, 180) end, "empty owner")
end)

case("corrupt locks and release markers reject writes", function()
    local state = L.acquire(nil, A, 1000, 180)
    state.lock.committed.headshots = -1
    fails(function() L.commit(state, A, earnings(), 1010, 180, false) end,
        "corrupt committed headshots")
    state.lock = nil
    state.lastSession = {owner = B, committed = earnings(20, 1)}
    eq(L.commit(state, A, earnings(20, 1), 1010, 180, true),
        nil, "other owner's completed save cannot acknowledge ours")
end)

case("saves only positive difference even if snapshots arrive out of order", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(300, 4, 2, 1), 1010, 180, false)
    state = L.commit(state, A, earnings(100, 1, 1, 0), 1011, 180, false)
    eq(state.xp, 300, "old snapshot no rollback")
    eq(state.victories, 1, "old snapshot no victory rollback")
    eq(state.lock.committed.eliminations, 4, "monotonic ledger")
end)

print("IRON YARD pure Luau progression transactions: " .. tostring(cases) .. " suites OK")
