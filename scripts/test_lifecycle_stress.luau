-- IRON YARD / deterministic lifecycle stress (LOT C1 of the V3 plan).
-- Twenty simulated rounds, four bots, three graphics presets, weapon swaps,
-- joins and departures, and saturated effects. Everything is counted, nothing
-- is timed: these are allocation and registration bounds, NEVER frame rates.
-- Passing this suite does not prove a server is fast, it proves that a round
-- releases what it acquires and that a pool stops at its cap instead of
-- instantiating without bound.
local LifecycleLedger = require("../src/shared/LifecycleLedger")
local BotPathBudget = require("../src/shared/BotPathBudget")
local TransientFxPool = require("../src/shared/TransientFxPool")
local ImpactMarkPool = require("../src/shared/ImpactMarkPool")
local MatchLobbyPolicy = require("../src/shared/MatchLobbyPolicy")

local ROUNDS = 20
local BOTS = 4
local HUMANS = 2
local PRESETS = { "ECO", "BALANCED", "QUALITY" }
local SWAPS_PER_ROUND = 10
local DEATHS_PER_ROUND = 5
local WEAPONS = { "Pistol", "Knife", "AssaultRifle", "Shotgun", "Sniper" }

local ledger = LifecycleLedger.new()
local equipped = {}
local fxSlots = {}
local markSlots = {}
local now = 0
local maxLive = 0

local function observe()
    local report = LifecycleLedger.report(ledger)
    if report.total > maxLive then maxLive = report.total end
    return report
end

-- One round: six combatants acquire a player entry, a weapon entry and a
-- listener; effects are claimed up to the preset's real cap; deaths acquire a
-- pose entry released on despawn; then the round ends and must release all.
for round = 1, ROUNDS do
    local preset = PRESETS[(round - 1) % #PRESETS + 1]
    local touch = round % 2 == 0
    local cap = TransientFxPool.cap(preset, touch)
    assert(cap >= 24 and cap <= TransientFxPool.MAX_PARTS, "preset cap out of bounds")
    -- A round reset drops transient effects, so a pool never carries the cap of
    -- the previous preset into a round played at a tighter one.
    fxSlots = {}
    markSlots = {}

    for index = 1, HUMANS + BOTS do
        assert(LifecycleLedger.acquire(ledger, "player", "combatant_" .. index),
            "a fresh round must accept each combatant once")
        equipped[index] = WEAPONS[(round + index) % #WEAPONS + 1]
        assert(LifecycleLedger.acquire(ledger, "weapon",
            "combatant_" .. index .. "/" .. equipped[index]), "weapon entry")
        assert(LifecycleLedger.acquire(ledger, "listener", "combatant_" .. index),
            "listener entry")
    end

    -- Effects: the claim policy recycles slots, so the table never grows past
    -- the cap even when far more effects are requested than the cap allows.
    for burst = 1, cap + 40 do
        local slot, index = TransientFxPool.claim(fxSlots, now, 0.2, cap, 3)
        assert(slot ~= nil and index ~= nil, "a claim inside the cap must succeed")
        assert(#fxSlots <= cap, "FX slots must never exceed the preset cap")
        now = now + 0.001
    end
    for _ = 1, 24 do
        local mark = ImpactMarkPool.claim(markSlots, now, 2, ImpactMarkPool.MAX_PARTS)
        assert(mark ~= nil, "impact claim must recycle, not refuse")
        assert(#markSlots <= ImpactMarkPool.MAX_PARTS, "impact slots must stay bounded")
    end

    -- Weapon swaps: a combatant equips the new model and frees the old one in
    -- that order, so a swap cycle can never accumulate weapon entries.
    for swap = 1, SWAPS_PER_ROUND do
        for index = 1, HUMANS + BOTS do
            local nextWeapon = WEAPONS[(swap + index) % #WEAPONS + 1]
            if nextWeapon ~= equipped[index] then
                LifecycleLedger.acquire(ledger, "weapon",
                    "combatant_" .. index .. "/" .. nextWeapon)
                LifecycleLedger.release(ledger, "weapon",
                    "combatant_" .. index .. "/" .. equipped[index])
                equipped[index] = nextWeapon
            end
        end
    end
    assert(LifecycleLedger.size(ledger, "weapon") == HUMANS + BOTS,
        "weapon swaps must hold exactly one entry per combatant")

    -- Deaths: a pose entry is held only while the corpse exists.
    for death = 1, DEATHS_PER_ROUND do
        LifecycleLedger.acquire(ledger, "pose", "death_" .. death)
        LifecycleLedger.release(ledger, "pose", "death_" .. death)
    end
    assert(LifecycleLedger.size(ledger, "pose") == 0,
        "a despawn must release its pose entry")

    LifecycleLedger.acquire(ledger, "fx", "round_" .. round)
    LifecycleLedger.release(ledger, "fx", "round_" .. round)

    -- Round reset: every round-scoped kind is dropped in one call.
    LifecycleLedger.releaseKind(ledger, "player")
    LifecycleLedger.releaseKind(ledger, "weapon")
    LifecycleLedger.releaseKind(ledger, "listener")
    LifecycleLedger.releaseKind(ledger, "fx")
    LifecycleLedger.releaseKind(ledger, "impact")

    local report = observe()
    assert(report.total == 0, string.format(
        "round %d leaked %d entries (first: %s)", round, report.total,
        report.leaks[1] and (report.leaks[1].kind .. "/" .. tostring(report.leaks[1].id))
            or "none"))
    -- One transient extra weapon entry is allowed during a swap (equip, then
    -- free the previous model), nothing more.
    assert(report.peak <= (HUMANS + BOTS) * 3 + 3,
        "peak live entries exceeded the per-round bound")
end
assert(LifecycleLedger.empty(ledger), "twenty rounds must end with an empty ledger")
assert(LifecycleLedger.report(ledger).duplicates == 0, "no double registration expected")

-- 2. A double listener is caught, not silently counted twice.
local double = LifecycleLedger.new()
assert(LifecycleLedger.acquire(double, "listener", "remote"), "first listener")
assert(not LifecycleLedger.acquire(double, "listener", "remote"),
    "a duplicate listener must be rejected")
assert(LifecycleLedger.report(double).duplicates == 1, "duplicate must be reported")
assert(LifecycleLedger.size(double, "listener") == 1, "one live listener, not two")

-- 3. Departures release only the departing player's entries.
local departure = LifecycleLedger.new()
LifecycleLedger.acquire(departure, "player", 1001)
LifecycleLedger.acquire(departure, "player", 1002)
assert(LifecycleLedger.release(departure, "player", 1001), "departing player released")
assert(LifecycleLedger.size(departure, "player") == 1, "the other player stays")
assert(MatchLobbyPolicy.shouldReset(0, "RESULTS", "DUEL", true),
    "an empty roster must reset the lobby after a departure")

-- 4. Four bots against the single server-wide path budget: at most two engine
-- calls in flight, spaced by the minimum gap, and a stale result is discarded
-- while its slot is still released separately.
local budget = BotPathBudget.new()
local clock = 0
local maxInFlight = 0
local completed = 0
local pending = {}
for tick = 1, 600 do
    clock = clock + 0.05
    local bot = (tick - 1) % BOTS + 1
    assert(bot >= 1 and bot <= BOTS)
    local token = BotPathBudget.claim(budget, clock)
    if token then
        table.insert(pending, { token = token, at = clock })
        local inFlight = BotPathBudget.inFlight(budget)
        if inFlight > maxInFlight then maxInFlight = inFlight end
        assert(inFlight <= BotPathBudget.MAX_IN_FLIGHT,
            "bot path budget exceeded its in-flight bound")
    end
    -- An engine call completes several ticks later, so slots genuinely overlap.
    while pending[1] ~= nil and clock - pending[1].at >= 0.4 do
        local entry = table.remove(pending, 1)
        assert(BotPathBudget.valid(budget, entry.token, clock),
            "a result inside the lease must stay usable")
        assert(BotPathBudget.release(budget, entry.token), "release must accept a live token")
        completed = completed + 1
    end
end
assert(maxInFlight >= 2, "the budget must actually be exercised")
assert(maxInFlight <= BotPathBudget.MAX_IN_FLIGHT, "in-flight bound respected")
assert(completed > 0 and #pending <= BotPathBudget.MAX_IN_FLIGHT,
    "pending engine calls must stay bounded")
-- Drain the calls still in flight when the simulation stops: the engine always
-- returns eventually, and the slot must be freed with it.
for _, entry in ipairs(pending) do
    assert(BotPathBudget.release(budget, entry.token), "drain must release every slot")
    completed = completed + 1
end
assert(BotPathBudget.inFlight(budget) == 0, "every slot must be released")
assert(not BotPathBudget.release(budget, 999), "an unknown token must not release")
-- A result older than the lease is discarded, while its slot was released
-- separately by the engine callback.
local lateToken = BotPathBudget.claim(budget, clock + BotPathBudget.MIN_START_GAP)
assert(lateToken, "the minimum gap must allow a later claim")
assert(not BotPathBudget.valid(budget, lateToken,
    clock + BotPathBudget.MIN_START_GAP + BotPathBudget.LEASE_SECONDS + 0.1),
    "a result past the lease must be discarded")
assert(BotPathBudget.release(budget, lateToken), "the slot is released on its own")
assert(BotPathBudget.inFlight(budget) == 0, "no slot left behind")

-- 5. Saturated effects recycle instead of allocating: the pool size is capped
-- even under a burst several times larger than the cap.
local saturated = {}
local cap = TransientFxPool.cap("QUALITY", false)
-- Effects last 0.5s and the burst is shorter than that, so every slot stays
-- alive: the pool must fill up to its cap and then recycle, never allocate a
-- 97th slot.
for _ = 1, cap * 5 do
    assert(TransientFxPool.claim(saturated, now, 0.5, cap, 2) ~= nil,
        "saturated claims must recycle a slot")
    now = now + 0.001
end
assert(#saturated == cap, "a saturated pool must hold exactly its cap")

-- 6. The ledger refuses to become a leak itself.
local bounded = LifecycleLedger.new()
for index = 1, LifecycleLedger.MAX_PER_KIND + 5 do
    LifecycleLedger.acquire(bounded, "fx", index)
end
assert(LifecycleLedger.size(bounded, "fx") == LifecycleLedger.MAX_PER_KIND,
    "a kind must stop at its own bound")
assert(LifecycleLedger.report(bounded).overflow == 5, "overflow must be reported")

-- 7. Invalid input fails loudly instead of quietly unbalancing the counts.
local function rejects(operation, label)
    assert(not pcall(operation), "ledger accepted an invalid input: " .. label)
end
local strict = LifecycleLedger.new()
rejects(function() LifecycleLedger.acquire(strict, "unknown", 1) end, "unknown kind")
rejects(function() LifecycleLedger.acquire(strict, "fx", "") end, "empty id")
rejects(function() LifecycleLedger.acquire(strict, "fx", nil) end, "missing id")
rejects(function() LifecycleLedger.acquire(nil, "fx", 1) end, "missing state")
rejects(function() LifecycleLedger.release(strict, "nope", 1) end, "unknown kind on release")
rejects(function() LifecycleLedger.size(strict, "nope") end, "unknown kind on size")
assert(LifecycleLedger.report(strict).total == 0, "rejected input must not register")

print(string.format(
    "IRON YARD lifecycle stress (%d rounds, %d bots, 3 presets, swaps, deaths, saturation): OK",
    ROUNDS, BOTS))
