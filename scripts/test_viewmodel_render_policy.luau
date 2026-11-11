-- IRON YARD / no repeated Part transparency writes at 60 FPS.
local P = require("../src/shared/ViewmodelRenderPolicy")
for _, id in ipairs({"AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife"}) do
    assert(not P.hidden(id, false), "Hip fire must display equipped weapon")
    assert(P.hidden(id, true) == (id == "Sniper"),
        "Only sniper optical scope hides the 3D viewmodel")
end
assert(P.transparency(0.31, true) == 1)
assert(P.transparency(0.31, false) == 0.31)
assert(P.transparency(0, false) == 0)
assert(P.needsUpdate(nil, false))
assert(not P.needsUpdate(false, false))
assert(P.needsUpdate(false, true))
assert(P.needsUpdate(true, false))
assert(not P.needsUpdate(true, true))
local previous, transitions = nil, 0
for frame = 1, 3600 do
    local scoped = (frame >= 600 and frame < 1200)
        or (frame >= 2400 and frame < 3000)
    local hidden = P.hidden("Sniper", scoped)
    if P.needsUpdate(previous, hidden) then
        previous = hidden
        transitions += 1
    end
end
assert(transitions == 5, "3600 frames admit initial + four mode updates, not per-frame writes")
assert(P.needsUpdate(nil, P.hidden("AssaultRifle", true)))
assert(not P.hidden("AssaultRifle", true))
assert(P.hidden("Sniper", true))
for _, dt in ipairs({0, 1 / 120, 1 / 60, 1 / 30, 0.05}) do
    assert(math.abs(P.animationDelta(dt) - dt) < 1e-9,
        "Normal FPS delta must not be modified")
end
assert(P.animationDelta(0.2) == 0.05, "Android frame hitch is animation-capped")
assert(P.animationDelta(10) == 0.05, "Background-tab hitch is animation-capped")
assert(P.animationDelta(-1) == 0)
assert(P.animationDelta(0 / 0) == 0)
assert(P.animationDelta(math.huge) == 0)
assert(P.animationDelta(-math.huge) == 0)
assert(P.animationDelta("0.2") == 0)
print("IRON YARD FPS viewmodel: visibility and hitch-safe cosmetic animation: OK")
