-- IRON YARD / live Luau regression tests for pure progression transactions.
-- Run: ./luau scripts/test_progression_ledger.luau
local L = require("../src/server/ProgressionLedger")

local A = "11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
local B = "22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
local C = "33333333-cccc-cccc-cccc-cccccccccccc"
local function eq(actual, expected, name)
    assert(actual == expected,
        (name or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
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
    local baseline = L.sessionBase(state, A)
    eq(baseline.xp, 0, "ack-loss retry does not double display XP")
    eq(baseline.eliminations, 0, "ack-loss retry does not double display kills")
    eq(baseline.xp + 100, state.xp, "local earned + base matches saved total")
    state = L.commit(state, A, earnings(100, 1), 1060, 180, true)
    eq(state.xp, 100, "ack-loss retry must not duplicate XP")
end)

case("recover partially committed session without double counting", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(140, 2, 1), 1010, 180, false)
    state = L.acquire(state, A, 1020, 180)
    local base = L.sessionBase(state, A)
    eq(base.xp, 0, "session XP base after first save")
    eq(base.eliminations, 0, "session elimination base after first save")
    eq(base.headshots, 0, "session headshot base after first save")
    eq(base.xp + 230, 230, "local XP reflects unsaved additions")
    state = L.commit(state, A, earnings(230, 3, 1), 1030, 180, false)
    eq(state.xp, 230, "second save commits only new XP")
    eq(state.eliminations, 3, "second save commits only new eliminations")
    local fresh = L.acquire(state, B, 1210, 180)
    eq(L.sessionBase(fresh, B).xp, 230, "new session sees full stored XP")
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

case("delayed release acknowledgement preserves a new server lease", function()
    local released = L.acquire(nil, A, 1000, 180)
    released = L.commit(released, A, earnings(180, 2, 1), 1010, 180, true)
    local nextSession = L.acquire(released, B, 1020, 180)
    local ack = L.commit(nextSession, A, earnings(180, 2, 1), 1025, 180, true)
    assert(ack ~= nil, "fully persisted late release must acknowledge")
    eq(ack.xp, 180, "no duplicated XP")
    eq(ack.lock.owner, B, "another server lease remains intact")
    eq(ack.lock.committed.xp, 0, "other server ledger remains untouched")
    eq(L.commit(nextSession, A, earnings(181, 2, 1), 1025, 180, true),
        nil, "late release must not grant unpersisted XP")
    eq(L.commit(nextSession, A, earnings(180, 2, 1), 1025, 180, false),
        nil, "old server cannot resume normal writes")
end)

case("delayed reacquire cannot shorten a newer server lease", function()
    local state = L.acquire(nil, A, 1000, 180)
    eq(state.lock.expiresAt, 1180, "initial lease")
    state = L.acquire(state, A, 1100, 180)
    eq(state.lock.expiresAt, 1280, "reacquired lease extension")
    -- An old UpdateAsync attempt was started at 1010 but finishes later.
    state = L.acquire(state, A, 1010, 180)
    eq(state.lock.expiresAt, 1280, "stale reacquire cannot shorten lease")
    eq(L.acquire(state, B, 1279, 180), nil,
        "another server cannot steal a shortened lease")
    state = L.acquire(state, A, 1099, 180)
    eq(state.lock.expiresAt, 1280,
        "repeated out-of-order reacquires are monotonic")
    local transferred = L.acquire(state, B, 1280, 180)
    assert(transferred and transferred.lock.owner == B,
        "other server may acquire only at original valid expiry")
end)

case("delayed autosave cannot shorten a newer committed lease", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(100, 1), 1200, 180, false)
    eq(state.lock.expiresAt, 1380, "newer autosave lease")
    eq(state.xp, 100, "first durable XP")
    -- Same owner, older clock in a retried transaction after the save above.
    state = L.commit(state, A, earnings(50, 1), 1030, 180, false)
    eq(state.lock.expiresAt, 1380, "old autosave cannot shorten lease")
    eq(state.xp, 100, "older snapshot must not remove persisted XP")
    eq(state.eliminations, 1, "no duplicate kill")
    state = L.commit(state, A, earnings(175, 2), 1190, 180, false)
    eq(state.lock.expiresAt, 1380,
        "out-of-order increment does not shorten the current lock")
    eq(state.xp, 175, "newly earned XP still commits once")
    eq(L.acquire(state, B, 1379, 180), nil,
        "new server denied while newest lease remains active")
    local transferred = L.acquire(state, B, 1380, 180)
    assert(transferred and transferred.lock.owner == B,
        "expired lease is transferable as before")
    local rejected = L.commit(transferred, A,
        earnings(300, 3), 1250, 180, false)
    eq(rejected, nil, "stale owner cannot write after lease transfer")
    eq(transferred.xp, 175, "no old-session bonus after transfer")
    eq(transferred.lock.expiresAt, 1560,
        "a stale foreign writer cannot alter new owner's lease")
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
    -- Build a genuinely persisted B release: the normalization invariant
    -- must reject forged saved totals, not a valid other-owner marker.
    state = L.acquire(nil, B, 1000, 180)
    state = L.commit(state, B, earnings(20, 1), 1010, 180, true)
    eq(state.xp, 20, "other owner's release is durably committed")
    eq(L.commit(state, A, earnings(20, 1), 1020, 180, true),
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

case("lock counters cannot acknowledge more than durable totals", function()
    for _, field in ipairs(L.STATS) do
        local state = L.acquire(nil, A, 1000, 180)
        local durable = L.normalize(state)
        state.lock.committed[field] = state[field] + 1
        fails(function() L.normalize(state) end,
            "oversized lock counter " .. field)
        fails(function() L.acquire(state, A, 1020, 180) end,
            "same-session reacquire cannot bless invalid " .. field)
        fails(function() L.acquire(state, B, 1200, 180) end,
            "new writer cannot adopt invalid " .. field)
        fails(function() L.commit(state, A, earnings(), 1050, 180, false) end,
            "autosave cannot acknowledge invalid " .. field)
        fails(function() L.commit(state, A, earnings(), 1050, 180, true) end,
            "release cannot acknowledge invalid " .. field)
        eq(durable[field], 0, "rejected transaction cannot mutate stored " .. field)
    end
end)

case("release marker counters cannot exceed physically saved totals", function()
    for _, field in ipairs(L.STATS) do
        local state = L.acquire(nil, A, 1000, 180)
        state = L.commit(state, A, earnings(150, 2, 1, 1),
            1020, 180, true)
        local durable = L.normalize(state)
        state.lastSession.committed[field] = state[field] + 1
        fails(function() L.normalize(state) end,
            "oversized release marker " .. field)
        fails(function() L.commit(state, A, earnings(150, 2, 1, 1),
            1030, 180, true) end,
            "late release must not claim unsaved " .. field)
        fails(function() L.acquire(state, B, 1040, 180) end,
            "future session cannot inherit invalid release marker " .. field)
        eq(durable[field], state[field],
            "previous valid total stays unchanged after failed release " .. field)
    end
end)

case("valid partial writes, release and reacquire preserve acknowledged totals", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(100, 1, 1, 0), 1010, 180, false)
    state = L.normalize(state)
    eq(state.lock.committed.xp, 100, "partial saved XP")
    eq(state.xp, 100, "partial committed total")
    state = L.commit(state, A, earnings(250, 2, 1, 1), 1020, 180, true)
    state = L.normalize(state)
    eq(state.lastSession.committed.victories, 1, "released victory")
    state = L.acquire(state, B, 1030, 180)
    state = L.commit(state, B, earnings(100, 1, 0, 0), 1040, 180, true)
    state = L.normalize(state)
    eq(state.xp, 350, "new session increments without duplicating old XP")
    eq(state.victories, 1, "new session does not change old victory")
end)

case("lease expiry cannot overflow the durable safe-integer range", function()
    local nearLimit = 9007199254740990
    local original = L.acquire(nil, A, 1000, 180)
    local unchanged = L.normalize(original)
    fails(function() L.acquire(nil, A, nearLimit, 180) end,
        "new lock expiry overflow")
    fails(function() L.acquire(original, A, nearLimit, 180) end,
        "same-session renewal expiry overflow")
    fails(function() L.commit(original, A, earnings(100), nearLimit, 180, false) end,
        "autosave renewal expiry overflow")
    fails(function() L.commit(original, A, earnings(100), nearLimit, 180, true) end,
        "release context expiry overflow")
    eq(original.xp, unchanged.xp, "invalid lease cannot alter XP")
    eq(original.lock.expiresAt, unchanged.lock.expiresAt,
        "invalid lease cannot mutate previous lock")
    local safe = L.acquire(nil, B, nearLimit - 180, 180)
    eq(safe.lock.expiresAt, nearLimit, "largest valid expiry accepted")
    eq(L.normalize(safe).lock.expiresAt, nearLimit,
        "largest valid expiry remains readable")
end)

case("award increments are atomic across all counters", function()
    local earned = L.zero()
    local first = L.applyGrant(earned, {xp=250, victories=1})
    eq(first.xp, 250, "first award XP")
    eq(first.victories, 1, "first award victory")
    eq(earned.xp, 0, "caller snapshot must stay unchanged")
    local second = L.applyGrant(first, {xp=100, eliminations=1, headshots=1})
    eq(second.xp, 350, "XP adds")
    eq(second.eliminations, 1, "kill adds")
    eq(second.headshots, 1, "headshot adds")
    eq(second.victories, 1, "absent fields leave earlier awards intact")
    eq(first.xp, 250, "prior snapshot stays stable for in-flight UpdateAsync")
    eq(first.eliminations, 0, "prior snapshot stays independent")

    -- In particular, a bad LAST field must not award a valid first field.
    for _, field in ipairs(L.STATS) do
        for _, invalid in ipairs({-1, 1.5, 10001, math.huge, "1"}) do
            local bad = {xp=5, eliminations=1, headshots=1, victories=1}
            bad[field] = invalid
            fails(function() L.applyGrant(first, bad) end,
                "reject invalid " .. field .. "=" .. tostring(invalid))
            eq(first.xp, 250, "invalid award cannot mutate XP")
            eq(first.victories, 1, "invalid award cannot mutate wins")
        end
        local badNan = {xp=5, eliminations=1, headshots=1, victories=1}
        badNan[field] = 0/0
        fails(function() L.applyGrant(first, badNan) end, "NaN " .. field)
    end
    fails(function() L.applyGrant(first, nil) end, "nil grant")
    fails(function() L.applyGrant(first, 20) end, "numeric grant")
    eq(first.xp, 250, "failed grants do not mutate original totals")
end)

case("one overflowing award field never partially increments another", function()
    -- Largest representable INTEGER strictly below the ledger's safe limit.
    local limit = 9007199254740990
    local earned = L.zero()
    earned.victories = limit
    fails(function()
        L.applyGrant(earned, {xp=1000, eliminations=1, victories=1})
    end, "later field overflow cannot partially grant XP")
    eq(earned.xp, 0, "no XP was granted on overflow")
    eq(earned.eliminations, 0, "no elimination was granted on overflow")
    eq(earned.victories, limit, "no overflow was written")
    local good = L.applyGrant(earned, {xp=1000, eliminations=1})
    eq(good.xp, 1000, "valid event still succeeds")
    eq(good.victories, limit, "zero delta at the limit remains valid")
end)

case("finish selection persists with newly earned XP and survives reconnection", function()
    local state = L.acquire(nil, A, 1000, 180)
    eq(state.finishPreference, nil, "Old records have no preference")
    fails(function()
        L.commit(state, A, earnings(999), 1001, 180, false, 3)
    end, "Selection cannot outrun final persisted rank")
    eq(state.xp, 0, "Rejected write leaves the original counters intact")
    state = L.commit(state, A, earnings(1000), 1002, 180, false, 3)
    eq(state.finishPreference, 3, "Selection uses rank from the same transaction")
    state = L.commit(state, A, earnings(1000), 1003, 180, true)
    local joined = L.acquire(state, B, 1004, 180)
    eq(joined.finishPreference, 3, "Rejoin restores the existing preference")
    eq(L.sessionBase(joined, B).xp, 1000, "Rejoin restores XP exactly once")
end)

case("automatic selection and late release preserve the newest preference", function()
    local state = L.acquire(nil, A, 1000, 180)
    state = L.commit(state, A, earnings(1000), 1001, 180, true, 3)
    state = L.acquire(state, B, 1002, 180)
    state = L.commit(state, B, earnings(0), 1003, 180, false, 0)
    state = L.commit(state, A, earnings(1000), 1004, 180, true, 3)
    eq(state.finishPreference, 0, "Late release cannot restore a previous selection")
    eq(state.lock.owner, B, "Late release retains the new writer")
    eq(state.xp, 1000, "Late release does not duplicate XP")
end)

case("malformed cosmetic preference falls back while XP is loaded", function()
    local state = L.normalize(nil)
    state.xp = 1000
    state.finishPreference = "invalid"
    local loaded = L.acquire(state, A, 1000, 180)
    eq(loaded.finishPreference, nil, "Invalid cosmetic preference ignored")
    eq(loaded.xp, 1000, "Malformed cosmetic preference never resets XP")
end)

local Objectives = require("../src/shared/SessionObjectives")
local Finishes = require("../src/shared/OperatorFinishes")
local function fromWeapons(day, ...)
    local state = Objectives.forDay(nil, day)
    for _, weapon in ipairs({...}) do state = Objectives.eliminate(state, day, weapon) end
    return state
end

case("daily objectives merge confirmed kills, distinct weapons and FFA completion", function()
    local day = 20801
    local older = fromWeapons(day, "AssaultRifle", "AssaultRifle")
    local pending = fromWeapons(day, "AssaultRifle", "Knife", "Pistol")
    local merged = Objectives.merge(older, pending, true)
    eq(merged.kills, 5, "Pre-load and saved kills count once")
    eq(Objectives.weaponCount(merged.weapons), 3)
    eq(merged.unlocked, false)
    merged = Objectives.finishFfa(merged, day)
    eq(merged.unlocked, true)
    eq(Objectives.completed(merged), 3)
    eq(Objectives.finishFfa(merged, day), merged, "Repeated FFA callback is idempotent")
    eq(Objectives.encode(Objectives.decode(Objectives.encode(merged))), Objectives.encode(merged))
    eq(Objectives.decode("20801:9999:1:2:1"), nil)
    eq(Finishes.canSelect(Objectives.FINISH_ID, 1000, false), false)
    eq(Finishes.equipped(1, Objectives.FINISH_ID, true).name, "SHIFT LEAD")
end)

case("objective reward and preference survive release, late writes and UTC rollover", function()
    local day = 20801
    local token = A
    local previous = L.acquire(nil, token, 1000, 180)
    local incomplete = fromWeapons(day, "AssaultRifle", "Pistol", "Shotgun")
    fails(function()
        L.commit(previous, token, earnings(500), 1001, 180, false, Objectives.FINISH_ID, incomplete)
    end, "An unearned finish must be rejected")
    previous = L.commit(previous, token, earnings(500), 1001, 180, false, nil, incomplete)
    local complete = Objectives.finishFfa(Objectives.eliminate(
        Objectives.eliminate(incomplete, day, "Knife"), day, "Sniper"), day)
    previous = L.commit(previous, token, earnings(660), 1002, 180, false, Objectives.FINISH_ID, complete)
    local stale = L.commit(previous, token, earnings(500), 1001, 180, false, nil, incomplete)
    eq(stale.objectives.kills, 5)
    eq(stale.finishPreference, Objectives.FINISH_ID)
    eq(stale.xp, 660)
    previous = L.commit(stale, token, earnings(660), 1003, 180, true, Objectives.FINISH_ID, complete)
    previous = L.acquire(previous, B, 1004, 180)
    local rollover = Objectives.forDay(previous.objectives, day + 1)
    previous = L.commit(previous, B, earnings(), 1005, 180, false, Objectives.FINISH_ID, rollover)
    eq(previous.objectives.kills, 0)
    eq(previous.objectives.ffa, false)
    eq(previous.objectives.unlocked, true)
    local retry = L.commit(previous, token, earnings(660), 1006, 180, true, Objectives.FINISH_ID, complete)
    eq(retry.objectives.day, day + 1)
    eq(retry.finishPreference, Objectives.FINISH_ID)
    eq(retry.xp, 660)
end)

case("lost acquisition acknowledgement and repeated release do not double count", function()
    local day = 20801
    local start = L.acquire(nil, A, 1000, 180)
    start = L.commit(start, A, earnings(), 1001, 180, true, nil, fromWeapons(day, "Pistol", "Pistol"))
    local held = L.acquire(start, B, 1002, 180)
    local localDelta = fromWeapons(day, "Shotgun")
    held = L.commit(held, B, earnings(100), 1003, 180, true, nil, localDelta, true)
    eq(held.objectives.kills, 3)
    held = L.commit(held, B, earnings(100), 1004, 180, true, nil, localDelta, true)
    eq(held.objectives.kills, 3)
    eq(held.xp, 100)
end)

print("IRON YARD pure Luau progression transactions: " .. tostring(cases) .. " suites OK")
