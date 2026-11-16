local Feedback = require("../src/shared/CombatFeedbackPolicy")
local Vfx = require("../src/shared/CombatVfxProfile")

local function eq(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual))
end

eq(Feedback.actualDamage(100, 76), 24, "Body-hit loss")
eq(Feedback.actualDamage(100, 0), 100, "Fatal loss capped to remaining HP")
eq(Feedback.actualDamage(9, 0), 9, "Overkill is not displayed as full weapon damage")
eq(Feedback.actualDamage(100, 100), 0, "No reduction, no damage")
eq(Feedback.actualDamage(90, 100), 0, "Healing never appears as damage")
eq(Feedback.actualDamage(1, 0.75), 1, "Fractional nonzero damage")
eq(Feedback.actualDamage(100, 97.6), 2, "Fractional health rounded")
eq(Feedback.actualDamage(math.huge, 0), 0, "Infinite values ignored")
eq(Feedback.actualDamage(0/0, 0), 0, "NaN values ignored")
eq(Feedback.actualDamage(100, -20), 100, "Negative health cannot inflate damage")
eq(Feedback.readout("Hit", 24, false), "24 DMG", "Body hit")
eq(Feedback.readout("Hit", 75.6, true), "HEADSHOT 76 DMG", "Headshot")
eq(Feedback.readout("Protected"), "SPAWN SHIELD", "Protected enemy")
eq(Feedback.readout("Miss", 24, true), nil, "No misleading miss readout")
eq(Feedback.readout("Hit", -3, false), nil, "No negative damage text")
eq(Feedback.readout("Hit", math.huge, false), nil, "No infinite text")
eq(Feedback.readout("Hit", 999999, false), "9999 DMG", "Bound UI numbers")

local body, head, elimination = Feedback.markerStyle(1), Feedback.markerStyle(2), Feedback.markerStyle(3)
for _, style in ipairs({ body, head, elimination }) do
    local innerEdge = style.offset - (style.length + style.thickness) / (2 * math.sqrt(2)) - 1
    assert(innerEdge >= 3.9, "Outlined strokes leave the center and ADS dot visible")
    assert(style.volume <= 0.22 and style.pitch > 0)
    eq(Feedback.soundVolume(style, 1), 0, "Mute only the confirmation sound")
    eq(Feedback.soundVolume(style, 2), style.volume * 0.5, "Low keeps the relative mix")
    eq(Feedback.soundVolume(style, 3), style.volume, "Standard retains the original mix")
end
assert(body.duration < head.duration and head.duration < elimination.duration)
assert(body.pitch ~= head.pitch and body.pitch ~= elimination.pitch and head.pitch ~= elimination.pitch)
assert(Vfx.shouldDisplayHit(10.05, 10, 1, 3, body.duration))
assert(not Vfx.shouldDisplayHit(10.15, 10, 3, 2, elimination.duration))
assert(Vfx.shouldDisplayHit(10.36, 10, 3, 1, elimination.duration))
assert(not Vfx.shouldDisplayHit(10.15, 10, 2, 1, head.duration))
assert(Vfx.shouldDisplayHit(10.15, 10, 2, 2, head.duration))
print("IRON YARD real-HP combat feedback, shield recognition and readouts: OK")

local Direction = require("../src/shared/DamageDirectionPolicy")
local function assertDirection(dx, dz, fx, fz, rx, rz, expectedX, expectedY)
    local x, y = Direction.project(dx, dz, fx, fz, rx, rz)
    assert(x ~= nil and math.abs(x - expectedX) < 1e-6 and math.abs(y - expectedY) < 1e-6,
        "Incoming damage must stay in the correct screen quadrant")
end

-- The same source moves from ahead, to the left, to behind as the player turns.
assertDirection(0, -20, 0, -1, 1, 0, 0, -1)
assertDirection(0, -20, 1, 0, 0, 1, -1, 0)
assertDirection(0, -20, 0, 1, -1, 0, 0, 1)
assertDirection(0, -20, -1, 0, 0, -1, 1, 0)
-- Steep pitch and camera roll do not change horizontal bearing.
local diagonal = math.sqrt(0.5)
assertDirection(20, -20, 0, -0.02, 0.6, 0.2, diagonal, -diagonal)
assertDirection(0, -20, 0, 0, 1, 0, 0, -1)
assert(Direction.project(0.1, 0.1, 0, -1, 1, 0) == nil)
assert(Direction.project(10, 5, 0, 0, 0, 0) == nil)
assert(Direction.project(0/0, 0, 0, -1, 1, 0) == nil)
assert(Direction.transparency(0.1, false) == 0)
assert(Direction.transparency(0.5, false) > 0 and Direction.transparency(0.5, false) < 1)
assert(Direction.transparency(Direction.DURATION, false) == 1)
assert(Direction.transparency(Direction.DURATION - 0.01, true) == 0)
print("IRON YARD incoming damage: four directions, camera rotation, steep aim and reduced motion passed")
