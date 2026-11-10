-- IRON YARD / client character streaming and respawn cache retention.
local Cache = require("../src/shared/FirstPersonBodyCache")
local state = Cache.new()
local a, b, c = {}, {}, {}
assert(Cache.add(state, a, 1))
assert(not Cache.add(state, a, 1), "Duplicate DescendantAdded must not allocate")
assert(state.count == 1 and #state.list == 1)
assert(Cache.add(state, b, 0))
assert(Cache.add(state, c, 1))
assert(state.count == 3 and #state.list == 3)
assert(Cache.remove(state, b), "Middle slot can be removed")
assert(state.count == 2 and #state.list == 2)
assert(state.byPart[a].index == 1 and state.byPart[c].index == 2,
    "Swap-delete must fix the moved Part's index")
assert(not Cache.remove(state, b), "Duplicate event must not underflow")
assert(Cache.add(state, b, 0), "A streamed-in Part can be re-registered")
assert(not Cache.add(state, b, 1), "Reparenting updates cached opacity")
assert(state.byPart[b].entry.transparency == 1)
assert(Cache.remove(state, a))
assert(Cache.remove(state, b))
assert(Cache.remove(state, c))
assert(state.count == 0 and next(state.byPart) == nil and #state.list == 0)
local parts = {}
for i = 1, 4000 do
    local p = {}
    parts[i] = p
    assert(Cache.add(state, p, i % 2))
end
assert(state.count == 4000)
for i = 1, 4000, 2 do
    assert(Cache.remove(state, parts[i]))
end
assert(state.count == 2000 and #state.list == 2000,
    "Streamed-out Parts cannot remain in the per-frame list")
for i = 2, 4000, 2 do
    assert(Cache.remove(state, parts[i]))
end
assert(state.count == 0 and next(state.byPart) == nil)
for round = 1, 100 do
    for i = 1, 60 do assert(Cache.add(state, {}, i % 2)) end
    assert(state.count == 60)
    Cache.clear(state)
    assert(state.count == 0 and next(state.byPart) == nil
        and #state.list == 0, "Respawn must release prior character refs")
end
print("IRON YARD first-person: 4000 streamed Parts, O(1) removal, 100 respawns: OK")
