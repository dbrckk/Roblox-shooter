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

-- A mobile 30 Hz client must finish cosmetic fades in the same real time
-- as a 60/120 Hz PC client; cancellation must never snap the PBR magazine.
local function fade(frames, rate, target)
    local value=0
    for _=1,frames do
        local alpha=P.blendAlpha(1/frames,rate)
        value += (target-value)*alpha
    end
    return value
end
local at30,at60,at120=fade(30,14,1),fade(60,14,1),fade(120,14,1)
assert(math.abs(at30-at60)<1e-9 and math.abs(at60-at120)<1e-9,
    "Hand, magazine and wrist fade must be consistent across frame rates")
assert(at30>0.999 and at30<1)
local canceled=1
for i=1,6 do
    canceled += (0-canceled)*P.blendAlpha(1/60,14)
    assert(canceled>=0 and canceled<1, "Cancel fades without snapping")
end
assert(canceled>0.1, "Visible canceled glove must not disappear instantly")
assert(P.blendAlpha(0,14)==0 and P.blendAlpha(-1,14)==0)
assert(P.blendAlpha(1/60,0)==0 and P.blendAlpha(math.huge,14)==0)
assert(P.blendAlpha(0/0,14)==0 and P.blendAlpha(1/60,0/0)==0)
assert(P.blendAlpha(1/60,math.huge)==0)
assert(P.blendAlpha(1/60,14)>0 and P.blendAlpha(1/60,14)<1)
