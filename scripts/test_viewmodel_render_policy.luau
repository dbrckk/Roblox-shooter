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

-- ADS, reload, sway and locomotion now converge equally in one real
-- second at 30/60/120 FPS (without per-frame Tween or scheduling).
for _, rate in ipairs({9, 13, 14}) do
    local function pose(frames)
        local value = 0
        for _ = 1, frames do
            value += (1 - value) * P.blendAlpha(1 / frames, rate)
        end
        return value
    end
    local at30, at60, at120 = pose(30), pose(60), pose(120)
    assert(math.abs(at30-at60) < 1e-9 and math.abs(at60-at120) < 1e-9)
end

-- A sniper hidden by the optical HUD has no visible viewmodel geometry.
-- Pending muzzle flash/casing cannot be skipped: their socket positions
-- must be updated after the native camera on this same render frame.
assert(P.skipHiddenSniper("Sniper", true, true, false, nil, nil))
assert(not P.skipHiddenSniper("Sniper", true, true, false, 0, nil))
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, {at=0.43}))
assert(not P.skipHiddenSniper("Sniper", true, true, true, nil, nil))
assert(not P.skipHiddenSniper("Sniper", true, false, false, nil, nil))
assert(not P.skipHiddenSniper("Sniper", false, true, false, nil, nil))
assert(not P.skipHiddenSniper("Sniper", true, true, nil, nil, nil))
assert(not P.skipHiddenSniper("Pistol", true, true, false, nil, nil))
assert(not P.skipHiddenSniper("AssaultRifle", true, true, false, nil, nil))
assert(not P.skipHiddenSniper("Sniper", true, true, false, false, nil))
for frame = 1, 3600 do
    local scoped = frame < 3000
    local pending = frame == 1200 and {at=0.43} or nil
    local skip = P.skipHiddenSniper("Sniper", scoped, scoped, false, nil, pending)
    assert(skip == (scoped and pending == nil),
        "Only completely invisible, effect-free sniper frames are skipped")
end
print("IRON YARD: idle optical sniper skips hidden PBR transforms but keeps FX/camera safety OK")

-- Delayed sniper shell need not animate hidden PBR parts until its actual
-- emission frame. On the deadline (or invalid timestamps) never skip: the
-- casing MUST use the current-frame camera and ejection-port transform.
local delayed = {at = 12.43}
assert(P.skipHiddenSniper("Sniper", true, true, false, nil, delayed, 12.0))
assert(P.skipHiddenSniper("Sniper", true, true, false, nil, delayed, 12.429))
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, delayed, 12.43))
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, delayed, 12.5))
assert(not P.skipHiddenSniper("Sniper", true, true, false, 12, delayed, 12))
assert(not P.skipHiddenSniper("Sniper", true, true, true, nil, delayed, 12))
assert(not P.skipHiddenSniper("Sniper", false, true, false, nil, delayed, 12))
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, delayed))
for _, invalidAt in ipairs({0/0, math.huge, -math.huge, -1, "soon", false}) do
    assert(not P.skipHiddenSniper(
        "Sniper", true, true, false, nil, {at = invalidAt}, 12))
end
for _, invalidNow in ipairs({0/0, math.huge, -math.huge, -1, "12", false}) do
    assert(not P.skipHiddenSniper(
        "Sniper", true, true, false, nil, delayed, invalidNow))
end
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, false, 12))
assert(not P.skipHiddenSniper("Sniper", true, true, false, nil, {}, 12))
print("IRON YARD: scoped sniper defers hidden frames but never misses due casing FX: OK")
