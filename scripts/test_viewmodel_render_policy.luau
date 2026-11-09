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
print("IRON YARD FPS viewmodel: equip/ADS-only visibility over 3600 frames: OK")
