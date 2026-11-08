local Policy = require("../src/shared/ArtLODPolicy")

local touchBalanced = Policy.limits("BALANCED", true)
assert(touchBalanced.botHide == 65 and touchBalanced.artHide == 110,
    "Existing balanced mobile LOD distances preserved")
local desktopBalanced = Policy.limits("BALANCED", false)
assert(desktopBalanced.botHide == 120 and desktopBalanced.artHide == 195,
    "Existing desktop LOD distances preserved")
assert(Policy.limits("ECO", true).artHide == 70)
assert(Policy.limits("QUALITY", true).artHide == 165)
assert(Policy.limits("QUALITY", false).artHide == 245)
assert(touchBalanced.botShow == touchBalanced.botHide - 12)
assert(touchBalanced.artShow == touchBalanced.artHide - 16)

assert(Policy.cellKey(0, 0) == "0:0")
assert(Policy.cellKey(-1, -48) == "-1:-1")
assert(Policy.cellKey(-48, 47.99) == "-1:0")
assert(Policy.cellKey(48, 96) == "1:2")
assert(Policy.cellKey(0/0, 3) == nil)
assert(Policy.cellKey(math.huge, 5) == nil)

local bounds = {}
assert(Policy.extendBounds(bounds, { X = 1, Y = 3, Z = -8 }))
assert(Policy.extendBounds(bounds, { X = 14, Y = 4, Z = 18 }))
assert(bounds.minX == 1 and bounds.maxX == 14
    and bounds.minY == 3 and bounds.maxY == 4
    and bounds.minZ == -8 and bounds.maxZ == 18)
assert(not Policy.extendBounds(bounds, { X = math.huge, Y = 4, Z = 3 }))
assert(bounds.minX == 1 and bounds.maxX == 14,
    "Invalid art origin cannot poison the spatial cache")

local eye = { X = 5, Y = 4, Z = 5 }
assert(Policy.classify(bounds, eye, 110, 94) == "SHOW",
    "Entire local sector can be kept visible without per-part checks")
assert(Policy.classify(bounds,
    { X = 270, Y = 4, Z = 5 }, 110, 94) == "HIDE",
    "Entire remote sector can be culled without individual distances")
assert(Policy.classify(bounds,
    { X = 110, Y = 4, Z = 5 }, 110, 94) == "MIXED",
    "Near LOD horizon needs precise per-part hysteresis")
assert(Policy.classify(bounds, eye, 0/0, 94) == "MIXED",
    "Invalid view configuration must not hide a whole sector")
assert(Policy.classify({}, eye, 110, 94) == "MIXED")
assert(Policy.classify(bounds,
    { X = 0/0, Y = 4, Z = 5 }, 110, 94) == "MIXED")
-- Expanded sector bounds conservatively protect moving original art.
local nearBorder = { X = bounds.maxX + 110 + 4, Y = 4, Z = 5 }
assert(Policy.classify(bounds, nearBorder, 110, 94) ~= "HIDE",
    "8-stud gantry motion margin must prevent premature far culling")

assert(Policy.hiddenSquared(111 * 111, false, 110, 94))
assert(not Policy.hiddenSquared(100 * 100, false, 110, 94))
assert(Policy.hiddenSquared(100 * 100, true, 110, 94))
assert(not Policy.hiddenSquared(93 * 93, true, 110, 94))
assert(Policy.hiddenSquared(0/0, true, 110, 94))
assert(not Policy.hiddenSquared(0/0, false, 110, 94))
print("IRON YARD spatial art LOD, safe motion padding and stable hysteresis: OK")
