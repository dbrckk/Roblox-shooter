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
print("IRON YARD 4 client-only gantry rigs: bounded motion and graphics budget OK")
