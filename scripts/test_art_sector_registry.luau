-- IRON YARD / incremental arena cosmetic inventory with streaming.
local Registry = require("../src/shared/ArtSectorRegistry")
local LOD = require("../src/shared/ArtLODPolicy")
local data = Registry.new()
local function pos(x,y,z)
    return { X=x, Y=y, Z=z }
end

local a, b, c, core = {}, {}, {}, {}
local ok, group = Registry.add(data, a, pos(1,2,3))
assert(ok and group.count == 1 and data.count == 1 and data.groupCount == 1)
assert(not Registry.add(data, a, pos(1,2,3)), "Duplicate stream notification must be a no-op")
group.lastMode = "HIDE"
local yes, same = Registry.add(data, b, pos(42,3,47))
assert(yes and same == group, "Nearby parts share a 48-stud sector")
assert(group.lastMode == nil, "New parts invalidate stale group visibility")
assert(group.bounds.maxX == 42 and group.bounds.maxZ == 47)
assert(Registry.add(data, c, pos(49,4,2)), "Neighbor sector must appear")
assert(data.count == 3 and data.groupCount == 2)
assert(not Registry.add(data, core, pos(0/0,4,6)), "Reject NaN coordinate")
assert(not Registry.add(data, core, pos(0,math.huge,6)), "Reject inf coordinate")
assert(not Registry.add(data, core, pos(0,4,math.huge)), "Reject inf sector key")
assert(data.count == 3 and data.groupCount == 2)
assert(not Registry.remove(data, core), "Non-detail pieces not tracked")
assert(Registry.remove(data, b), "Stream-out removes affected part")
assert(group.bounds.maxX == 1 and group.bounds.maxZ == 3,
    "Removed edge must refresh sector bounds, not keep old expansion")
assert(group.count == 1 and data.count == 2)
assert(not Registry.remove(data, b), "Repeated stream-out is idempotent")
assert(Registry.add(data, b, pos(5,2,6)), "Stream-in restores detail")
assert(data.byPart[b].group == group)
assert(Registry.remove(data, a) and Registry.remove(data, b))
assert(data.groupCount == 1, "Empty sector removed from cache")
assert(Registry.remove(data, c))
assert(data.count == 0 and data.groupCount == 0 and next(data.byKey) == nil
    and next(data.byPart) == nil, "All folder references must be releasable")

-- Compare the exact LOD classification to a freshly rebuilt spatial
-- inventory after thousands of streaming additions/removals.
local huge = Registry.new()
local chunks = {}
for i = 1, 2000 do
    local part = {}
    chunks[i] = part
    assert(Registry.add(huge, part, pos((i % 240)-120, i%20, (i%360)-180)))
end
assert(huge.count == 2000, "2000 pieces registered exactly once")
for i = 2, 2000, 2 do
    assert(Registry.remove(huge, chunks[i]))
end
assert(huge.count == 1000)
for _, sector in pairs(huge.byKey) do
    local rebuilt = {}
    local counted = 0
    for part in pairs(sector.parts) do
        assert(huge.byPart[part] and huge.byPart[part].group == sector)
        assert(LOD.extendBounds(rebuilt, huge.byPart[part].position))
        counted += 1
    end
    assert(counted == sector.count and counted > 0)
    for _, field in ipairs({"minX","maxX","minY","maxY","minZ","maxZ"}) do
        assert(rebuilt[field] == sector.bounds[field],
            "Incremental sector must match full rebuild for " .. field)
    end
    assert(LOD.classify(sector.bounds, pos(500,5,0), 110,94)
        == LOD.classify(rebuilt, pos(500,5,0),110,94))
end
for i = 1, 2000, 2 do assert(Registry.remove(huge, chunks[i])) end
assert(huge.count == 0 and huge.groupCount == 0
    and next(huge.byKey) == nil and next(huge.byPart) == nil,
    "Repeated streaming churn cannot accumulate stale Part refs")
-- Arena replacement must not recompute 2000 individual sector bounds.
local replaced = Registry.new()
for i = 1, 2000 do
    assert(Registry.add(replaced, {}, pos(i%200, i%30, i%300)))
end
assert(replaced.count == 2000)
Registry.clear(replaced)
assert(replaced.count == 0 and replaced.groupCount == 0
    and next(replaced.byPart) == nil and next(replaced.byKey) == nil,
    "Whole arena replacement must discard the cached inventory atomically")
assert(Registry.add(replaced, {}, pos(1,2,3))
    and replaced.count == 1, "Replaced arena can initialize cleanly")
print("IRON YARD 48-stud incremental art sectors, streaming and fast cleanup: OK")
