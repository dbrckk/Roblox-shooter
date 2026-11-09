-- IRON YARD / bot visual LOD: zero repeated cosmetic rescans and safe streaming.
local Cache = require("../src/shared/BotDetailCache")
local limits = require("../src/shared/ArtLODPolicy").limits("BALANCED", true)
local state = Cache.new()

local base = {}
assert(not Cache.observe(state, base, "Core"), "Core silhouette never cached")
assert(not Cache.observe(state, base, nil), "Gameplay rig never cached")
local parts = {}
for i = 1, 65 do
    local part = { id = i }
    parts[i] = part
    assert(Cache.observe(state, part, "Detail"), "New detail arrives")
    assert(not Cache.observe(state, part, "Detail"), "Duplicate event is a no-op")
end
assert(state.count == 65, "Only true cosmetics counted")
local changed, hidden = Cache.decide(state, 0, limits.botHide, limits.botShow)
assert(changed and not hidden and state.hidden == false, "Initial near visibility")
changed = Cache.decide(state, 0, limits.botHide, limits.botShow)
assert(not changed, "Stationary camera must not rewrite 65 properties")
changed, hidden = Cache.decide(state,
    (limits.botHide + 1)^2, limits.botHide, limits.botShow)
assert(changed and hidden, "Distant armor details hidden")
changed, hidden = Cache.decide(state,
    (limits.botHide - 6)^2, limits.botHide, limits.botShow)
assert(not changed and hidden, "Hysteresis prevents threshold flickering")
changed, hidden = Cache.decide(state,
    (limits.botShow - 1)^2, limits.botHide, limits.botShow)
assert(changed and not hidden, "Nearby bot regains details")
assert(not Cache.decide(state,
    (limits.botShow - 1)^2, limits.botHide, limits.botShow),
    "No repeated writes when visibility unchanged")

-- Streamed-in details acquire the current model mode without scanning
-- its original 65 parts; later attribute replication converts pending -> detail.
Cache.decide(state, (limits.botHide + 2)^2, limits.botHide, limits.botShow)
local delayed = {}
assert(not Cache.observe(state, delayed, nil), "Unreplicated tier is pending")
assert(Cache.observe(state, delayed, "Detail"), "Late attribute creates detail")
assert(state.hidden and state.details[delayed] and state.count == 66,
    "New detail inherits hidden state immediately")
assert(Cache.observe(state, delayed, "Core"), "Tier change removes detail")
assert(not state.details[delayed] and state.count == 65,
    "Changed tier cannot remain invisible")
assert(Cache.remove(state, parts[1]) and state.count == 64,
    "Streaming removal drops one detail")
assert(not Cache.remove(state, parts[1]) and state.count == 64,
    "Repeated removal cannot underflow")
assert(Cache.observe(state, parts[1], "Detail") and state.count == 65,
    "Streamed replacement detail is registered again")

-- A preset change uses the same cached model, no scans or new instances.
local eco = require("../src/shared/ArtLODPolicy").limits("ECO", true)
changed, hidden = Cache.decide(state, 50^2, eco.botHide, eco.botShow)
assert(not changed and hidden, "ECO hides distant cosmetics")
local quality = require("../src/shared/ArtLODPolicy").limits("QUALITY", true)
changed, hidden = Cache.decide(state, 50^2, quality.botHide, quality.botShow)
assert(changed and not hidden, "Changing quality restores cosmetics")

local replacements = 0
for _ = 1, 100 do
    local fresh = Cache.new()
    for i = 1, 65 do
        assert(Cache.observe(fresh, parts[i], "Detail"))
    end
    assert(fresh.count == 65)
    for i = 1, 65 do
        assert(Cache.remove(fresh, parts[i]))
    end
    assert(fresh.count == 0 and next(fresh.details) == nil,
        "Destroyed model cannot retain cosmetic references")
    replacements += 1
end
assert(replacements == 100)
print("IRON YARD bot LOD cache: streaming, hysteresis, quality and respawn: OK")
