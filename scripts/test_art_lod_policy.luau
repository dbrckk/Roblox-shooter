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
for _, setting in ipairs({
    { "ECO", true, 48 }, { "ECO", false, 96 },
    { "BALANCED", true, 96 }, { "BALANCED", false, 192 },
    { "QUALITY", true, 128 }, { "QUALITY", false, 192 },
}) do
    assert(Policy.bootstrapBatch(setting[1], setting[2]) == setting[3],
        "Incorrect registration budget for " .. setting[1])
end
local inspected, mobileLimit = 0, Policy.bootstrapBatch("ECO", true)
for _ = 1, 5 do
    local step = math.min(mobileLimit, 217 - inspected)
    assert(step <= 48, "ECO registration must stay below its frame budget")
    inspected += step
end
assert(inspected == 217, "Initial inventory must eventually complete")
-- A fast camera movement can refresh art at 4Hz maximum; ordinary
-- camera motion or idle retains the previous 1Hz work budget.
local from = { X = 0, Y = 5, Z = 0 }
local farEye = { X = 20, Y = 5, Z = 0 }
local almost = { X = 19, Y = 5, Z = 0 }
assert(Policy.ArtPollSeconds == 1 and Policy.FastPollSeconds == 0.25)
assert(Policy.FastTravelStuds == 20)
assert(Policy.shouldPollArt(0, nil, from, nil, "ECO", nil))
assert(not Policy.shouldPollArt(0.1, 0, farEye, from, "ECO", "ECO"),
    "Fast motion cannot trigger unlimited sector sweeps")
assert(not Policy.shouldPollArt(0.25, 0, almost, from, "ECO", "ECO"),
    "Small camera movement should retain the 1Hz art budget")
assert(Policy.shouldPollArt(0.25, 0, farEye, from, "ECO", "ECO"),
    "20-stud camera displacement should trigger an early sector sweep")
assert(not Policy.shouldPollArt(0.26, 0.25,
    { X = 50, Y = 5, Z = 0 }, farEye, "ECO", "ECO"))
assert(not Policy.shouldPollArt(0.99, 0, from, from, "ECO", "ECO"))
assert(Policy.shouldPollArt(1, 0, from, from, "ECO", "ECO"))
assert(Policy.shouldPollArt(0.25, 0, from, from, "QUALITY", "ECO"),
    "Graphics transitions must not wait a full second")
assert(not Policy.shouldPollArt(0.1, 0, from, from, "QUALITY", "ECO"),
    "Preset changes also obey the fast 4Hz budget")
assert(Policy.shouldPollArt(0.25, 0, from, nil, "ECO", "ECO"),
    "A new camera after respawn forces an early update")
assert(not Policy.shouldPollArt(0.25, 0, nil, nil, "ECO", "ECO"))
assert(not Policy.shouldPollArt(0/0, 0, farEye, from, "ECO", "ECO"))
assert(Policy.shouldPollArt(2, 3, from, from, "ECO", "ECO"),
    "Reversed clocks must force a safe resynchronization")

-- A part arriving during a boost must be culled using the LIVE camera.
-- Stale positions from the previous second could make close detail pop.
local streamingPart = { X = 100, Y = 5, Z = 0 }
local nearNow = { X = 95, Y = 5, Z = 0 }
local farBefore = { X = 0, Y = 5, Z = 0 }
assert(Policy.streamedHidden(streamingPart, nil, farBefore, 70, 54),
    "Fallback to last eye only if the new camera is missing")
assert(not Policy.streamedHidden(streamingPart, nearNow, farBefore, 70, 54),
    "Fresh detail near the current camera must not start invisible")
assert(Policy.streamedHidden(streamingPart, farBefore, nearNow, 70, 54),
    "Fresh detail beyond the current camera must be hidden immediately")
assert(not Policy.streamedHidden(streamingPart, nil, nil, 70, 54),
    "No camera is a safe visible default")
assert(not Policy.streamedHidden(streamingPart,
    { X = 0/0, Y = 5, Z = 0 }, nil, 70, 54))

-- 60 seconds at 10 checks/second: hold steady at 1Hz, fast movement
-- at <=4Hz, with no catch-up burst after sudden camera movement.
local function countSweeps(speed)
    local count, lastAt, lastEye = 0, nil, nil
    for frame = 0, 600 do
        local now = frame / 10
        local eye = { X = now * speed, Y = 5, Z = 0 }
        if Policy.shouldPollArt(now, lastAt, eye, lastEye,
            "BALANCED", "BALANCED") then
            count += 1
            lastAt = now
            lastEye = eye
        end
    end
    return count
end
local stationarySweeps = countSweeps(0)
local fastSweeps = countSweeps(140)
assert(stationarySweeps >= 50 and stationarySweeps <= 61)
assert(fastSweeps > stationarySweeps and fastSweeps <= 241,
    "Fast motion refreshes more often, never above four polls/s")

print("IRON YARD spatial art LOD, safe motion and boot frame budgets: OK")
