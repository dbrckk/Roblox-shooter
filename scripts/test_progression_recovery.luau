-- IRON YARD / A2 deterministic DataStore ordering and departure scenarios.
-- Drives the REAL ledger (src/server/ProgressionLedger.luau) through an
-- in-memory store that reproduces DataStore UpdateAsync semantics:
--   * the callback always receives the CURRENT stored value, never a stale
--     caller copy, exactly like Roblox re-invoking a conflicting callback;
--   * returning nil aborts the write without touching the stored value;
--   * every accepted value is re-normalized, so no caller table is aliased.
-- It does NOT test the Roblox DataStore service, network retries, BindToClose
-- timing or Studio behaviour: those need a real published server.
local L = require("../src/server/ProgressionLedger")

local LEASE = 180

local Store = {}
Store.__index = Store

function Store.new(name)
    return setmetatable({ name = name, value = nil, writes = 0, aborts = 0 }, Store)
end

function Store:copy()
    return self.value and L.normalize(self.value) or nil
end

function Store:update(callback)
    local previous = self:copy()
    local result = callback(previous)
    if result == nil then
        self.aborts += 1
        return nil
    end
    -- A real UpdateAsync serialises the callback result into the key and
    -- hands the caller nothing that aliases the stored record.
    self.value = L.normalize(result)
    self.writes += 1
    return L.normalize(self.value)
end

local function stats(xp, eliminations, headshots, victories)
    return { xp = xp or 0, eliminations = eliminations or 0,
        headshots = headshots or 0, victories = victories or 0 }
end

local function session(name, at)
    return { token = name .. "-session-token", clock = at, earned = L.zero() }
end

local function acquire(store, s)
    store:update(function(previous)
        return L.acquire(previous, s.token, s.clock, LEASE)
    end)
    return store.value ~= nil and store.value.lock ~= nil
        and store.value.lock.owner == s.token
end

local function commit(store, s, snapshot, release)
    return store:update(function(previous)
        return L.commit(previous, s.token, snapshot, s.clock, LEASE,
            release == true)
    end)
end

-- Mirrors ProgressionService.publish(): lifetime XP and the SAVED counter
-- must never be conflated.
local function display(base, earned, committed)
    return {
        lifetime = base.xp + earned.xp,
        saved = base.xp + math.min(earned.xp, committed.xp),
    }
end

local cases = 0
local function case(label, run)
    run()
    cases += 1
    print("OK " .. label)
end

case("autosave then departure commits each gain exactly once", function()
    local store = Store.new("autosave-departure")
    local a = session("A", 1000)
    assert(acquire(store, a), "first session must own the lease")
    -- 130 XP earned, first autosave.
    assert(commit(store, a, stats(130, 1, 1), false), "autosave must commit")
    assert(store.value.xp == 130 and store.value.eliminations == 1)
    -- 210 more XP earned between the two saves: the snapshot is cumulative.
    assert(commit(store, a, stats(340, 3, 2, 1), true), "final release must commit")
    assert(store.value.xp == 340, "release must not double count the autosave")
    assert(store.value.eliminations == 3 and store.value.headshots == 2)
    assert(store.value.victories == 1)
    assert(store.value.lock == nil, "release must clear the lease")
    assert(store.value.lastSession.owner == a.token)
    assert(store.writes == 3 and store.aborts == 0,
        "three accepted writes, no abort")
end)

case("a delayed autosave cannot roll back or duplicate a release", function()
    local store = Store.new("delayed-autosave")
    local a = session("A", 1000)
    assert(acquire(store, a))
    commit(store, a, stats(130, 1, 1), false)
    commit(store, a, stats(340, 3, 2, 1), true)
    -- The older autosave request finally lands after the release.
    local stale = session("A", 1015)
    assert(commit(store, stale, stats(130, 1, 1), false) == nil,
        "post-release autosave must abort instead of writing")
    assert(store.value.xp == 340, "aborted write leaves durable XP untouched")
    assert(store.value.lock == nil, "aborted write cannot reopen the lease")
    assert(store.aborts == 1)
    -- Replayed release acknowledgement is safe and idempotent.
    assert(commit(store, a, stats(340, 3, 2, 1), true) ~= nil,
        "fully persisted late release must acknowledge")
    assert(store.value.xp == 340, "acknowledgement cannot duplicate XP")
    assert(store.value.lastSession.owner == a.token)
end)

case("acquisition finishing after departure still saves the final XP", function()
    local store = Store.new("late-acquire")
    local a = session("A", 1000)
    assert(acquire(store, a), "the late acquisition must still own the lease")
    -- The player left during UpdateAsync: the record was unlinked with 90 XP.
    assert(commit(store, a, stats(90, 1, 0), true),
        "detached release must commit the earned snapshot")
    assert(store.value.xp == 90, "no XP lost by leaving mid-acquire")
    assert(store.value.lock == nil)
    local nextPlayer = session("B", 1030)
    assert(acquire(store, nextPlayer))
    assert(L.sessionBase(store.value, nextPlayer.token).xp == 90,
        "the next session starts from the committed career")
end)

case("a second server is refused with an active lease, then takes over", function()
    local store = Store.new("two-servers")
    local a = session("A", 1000)
    local b = session("B", 1050)
    assert(acquire(store, a))
    commit(store, a, stats(150, 2), false)
    assert(commit(store, b, stats(500, 9), false) == nil,
        "foreign session cannot write")
    assert(store.value.xp == 150, "foreign write leaves data intact")
    assert(store.value.lock.owner == a.token)
    b.clock = 1190 -- exact lease expiry after A's last autosave
    assert(acquire(store, b), "expired lease transfers to the new server")
    assert(commit(store, a, stats(150, 2), true) == nil,
        "the stale owner cannot release the new lease")
    assert(store.value.lock.owner == b.token)
    assert(commit(store, b, stats(200, 3, 1, 1), true))
    assert(store.value.xp == 350,
        "new session adds its own 200 to the stored 150")
    local c = session("C", 1400)
    assert(acquire(store, c))
    assert(store.value.xp == 350 and store.value.victories == 1)
end)

case("an expired lease never evicts its own owner mid-round", function()
    local store = Store.new("self-expiry")
    local a = session("A", 1000)
    assert(acquire(store, a))
    -- A long round: the first autosave happens after the lease expiry.
    a.clock = 1300
    assert(commit(store, a, stats(210, 2, 1), false),
        "the owning session may renew its own expired lease")
    assert(store.value.xp == 210)
    assert(store.value.lock.expiresAt == 1480, "lease renewed from the save time")
    local b = session("B", 1400)
    assert(commit(store, b, stats(900, 9), false) == nil)
    assert(store.value.xp == 210, "a rival cannot profit from the expiry window")
end)

case("saved XP and session XP stay separated between autosaves", function()
    local store = Store.new("session-vs-saved")
    local a = session("A", 1000)
    assert(acquire(store, a))
    local base = L.sessionBase(store.value, a.token)
    local earned = L.zero()
    earned = L.applyGrant(earned, { xp = 130, eliminations = 1 })
    local before = display(base, earned, L.zero())
    assert(before.lifetime == 130 and before.saved == 0,
        "unsaved XP is visible but never claimed as saved")
    assert(before.saved <= store.value.xp, "saved counter cannot exceed storage")
    a.clock = 1010
    commit(store, a, earned, false)
    local committed = L.copyStats(earned)
    local after = display(L.sessionBase(store.value, a.token), earned, committed)
    assert(after.lifetime == 130 and after.saved == 130)
    assert(store.value.xp == 130)
    -- 210 more earned before the next autosave: lifetime grows, saved does not.
    earned = L.applyGrant(earned, { xp = 210, eliminations = 2, headshots = 1 })
    local pending = display(L.sessionBase(store.value, a.token), earned,
        L.copyStats(committed))
    assert(pending.lifetime == 340 and pending.saved == 130,
        "pending XP must not be reported as confirmed")
    assert(pending.saved <= store.value.xp)
    assert(pending.lifetime == pending.saved + 210)
end)

case("a rejected snapshot aborts without corrupting the store", function()
    local store = Store.new("corrupt-write")
    local a = session("A", 1000)
    assert(acquire(store, a))
    commit(store, a, stats(120, 1), false)
    local ok = pcall(function()
        commit(store, a, stats(-5, 1), false)
    end)
    assert(not ok, "negative XP must fail closed")
    assert(store.value.xp == 120, "rejected write cannot change stored XP")
    assert(store.value.lock.committed.xp == 120)
    -- Degraded mode is recoverable: the next valid autosave still lands.
    a.clock = 1020
    assert(commit(store, a, stats(300, 2, 1), true))
    assert(store.value.xp == 300)
end)

case("a replayed UpdateAsync callback is idempotent", function()
    local store = Store.new("replayed-callback")
    local a = session("A", 1000)
    assert(acquire(store, a))
    local function autosave(previous)
        return L.commit(previous, a.token, stats(260, 2, 1), 1010, LEASE, false)
    end
    store:update(autosave)
    local first = store.value.xp
    -- Roblox may re-invoke the same callback with the CURRENT value.
    store:update(autosave)
    assert(store.value.xp == first and first == 260,
        "a replayed callback must not add the same XP twice")
end)

case("no caller table is aliased into the durable record", function()
    local store = Store.new("detached-copy")
    local a = session("A", 1000)
    assert(acquire(store, a))
    local returned = store:update(function(previous)
        return L.acquire(previous, a.token, a.clock, LEASE)
    end)
    assert(returned ~= nil, "acquisition must return a detached read-back")
    returned.xp = 99999
    returned.lock.committed.headshots = 42
    returned.lock.owner = "attacker"
    local durable = store:copy()
    assert(durable.xp == 0, "stored XP cannot be mutated through a returned table")
    assert(durable.lock.committed.headshots == 0)
    assert(durable.lock.owner == a.token)
end)

print("IRON YARD A2 DataStore ordering and departure: " .. tostring(cases)
    .. " scenarios OK")
