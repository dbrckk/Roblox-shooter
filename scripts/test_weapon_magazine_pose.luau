local Pose = require("../src/shared/WeaponMagazinePose")
for _, id in ipairs({"Pistol", "AssaultRifle"}) do
    local x,y,z,r = Pose.sample(id, 0, 1, true, true)
    assert(x == 0 and y == 0 and z == 0 and r == 0)
    x,y,z,r = Pose.sample(id, 1, 1.15, true, true)
    assert(x == 0 and y < -0.35 and z > 0 and r > 0)
    local a,b,c,d = Pose.sample(id, 1, 1.15, false, false)
    assert(x == a and y == b and z == c and r == d,
        "Original PBR and procedural detachable magazines share pose")
    local prev = 0
    for i=0,1000 do
        local u,v,w,angle = Pose.sample(id, i/1000, 1.15, true, true)
        assert(u == 0 and v <= 0 and w >= 0 and angle >= prev)
        assert(angle <= 0.13 and math.abs(angle-prev) < 0.001)
        prev = angle
    end
end
for _, id in ipairs({"Pistol", "AssaultRifle"}) do
    for _, invalid in ipairs({0/0, math.huge, -math.huge, "bad"}) do
        assert(select(2, Pose.sample(id, invalid, 1, false, true)) == 0)
        assert(select(2, Pose.sample(id, 1, invalid, false, true)) == 0)
    end
end
assert(select(2, Pose.sample("Pistol", 1, 1, true, false)) == 0,
    "Never animate the fixed magazine inside the legacy PBR pistol")
for _, id in ipairs({"Shotgun", "Sniper", "Knife", "Unknown"}) do
    assert(select(4, Pose.sample(id, 1, 1, false, false)) == 0)
end
assert(select(2, Pose.sample("Pistol", 1, 0, true, true)) == 0)
print("IRON YARD detachable PBR/Part magazine extraction, tilt and legacy safety OK")
