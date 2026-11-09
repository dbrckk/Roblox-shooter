local Motion = require("../src/shared/GantryMotion")
local function near(a,b,eps)
    assert(math.abs(a-b) <= (eps or 0.000001),
        tostring(a) .. " != " .. tostring(b))
end
for index = 1, 4 do
    for _, time in ipairs({0, 1.5, 12, 45, 300, 600}) do
        local dx, dy, alpha = Motion.pose(time, index, "BALANCED", 90)
        assert(math.abs(dx) <= 5.60001, "Gantry trolley leaves cosmetic travel")
        assert(math.abs(dy) <= 0.70001, "Gantry spreader leaves cable travel")
        assert(alpha >= 0.16 and alpha <= 0.73, "Beacon pulse out of bounds")
        local sameDx, sameDy, sameAlpha = Motion.pose(time, index, "BALANCED", 90)
        near(sameDx,dx);near(sameDy,dy);near(sameAlpha,alpha)
        local ecoX,ecoY,ecoB = Motion.pose(time,index,"ECO",50)
        near(ecoX,0);near(ecoY,0);near(ecoB,0)
        local farX,farY,farB = Motion.pose(time,index,"BALANCED",320)
        near(farX,0);near(farY,0);near(farB,0)
    end
end
local nearX = Motion.pose(100,1,"QUALITY",250)
local farX = Motion.pose(100,1,"BALANCED",250)
assert(farX == 0, "Balanced must cull more than high")
assert(nearX ~= 0, "High quality should animate a nearby giant gantry")
local invalid = Motion.pose(0/0,1,"QUALITY",0)
assert(invalid == 0, "Malformed timer must be rejected")
-- The four rigs keep full near-field animation while distant / ECO rigs
-- avoid costly PivotTo, trigonometry and PointLight allocations.
local expected = {
    { "BALANCED", true, 40, 1 / 15, true },
    { "BALANCED", true, 110, 1 / 9, true },
    { "BALANCED", true, 175, 1 / 5, true },
    { "BALANCED", true, 185, 1 / 5, true },
    { "BALANCED", true, 186, 1, false },
    { "QUALITY", true, 280, 1 / 5, true },
    { "QUALITY", true, 286, 1, false },
    { "BALANCED", false, 60, 1 / 24, true },
    { "BALANCED", false, 180, 1 / 12, true },
    { "QUALITY", false, 260, 1 / 8, true },
    { "ECO", true, 2, 1, false },
    { "ECO", false, 2, 1, false },
}
for _, sample in ipairs(expected) do
    local period, active = Motion.sampleInterval(
        sample[1], sample[2], sample[3] * sample[3])
    near(period, sample[4])
    assert(active == sample[5], "Wrong crane animation admission")
end
for _, bad in ipairs({ -1, 0 / 0, math.huge }) do
    local period, active = Motion.sampleInterval("QUALITY", true, bad)
    assert(period == 1 and active == false, "Invalid distances never animate")
end
-- Moving in from afar must retain the original visible, exact sine pose
-- when the client schedules the next sample.
for _, time in ipairs({ 0, 1, 3.8, 48, 100 }) do
    local x, y, b = Motion.pose(time, 2, "QUALITY", 100)
    local intervalNow, admitted = Motion.sampleInterval("QUALITY", true, 10000)
    assert(admitted and intervalNow > 0)
    local a, c, d = Motion.pose(time, 2, "QUALITY", 100)
    near(a, x); near(c, y); near(d, b)
end
print("IRON YARD 4 client-only gantries: adaptive 5-24Hz distance LOD: OK")
