local Layout = require("../src/shared/TouchLayout")

local screens = {
    {320, 280}, {360, 300}, {400, 800}, {568, 320},
    {640, 360}, {740, 360}, {800, 400}, {915, 412},
    {1024, 768}, {1280, 720}, {1920, 1080},
}
for _, viewport in ipairs(screens) do
    local w, h = viewport[1], viewport[2]
    local layout = Layout.compute(w, h)
    local ok, reason = Layout.check(w, h, layout)
    assert(ok, tostring(w) .. "x" .. tostring(h) .. ": " .. tostring(reason))
    assert(layout.Fire.x > w / 2 or w < 500,
        "Fire action should be on the right side of a landscape screen")
    assert(layout.Fire.x > layout.Aim.x,
        "Fire must be right of ADS")
    assert(layout.Reload.y > layout.AssaultRifle.y,
        "Utility controls must be below weapon selection")
    assert(layout.Fire.y > layout.Reload.y,
        "Fire must be below utility controls")
    print("IRON YARD mobile controls " .. w .. "x" .. h .. ": OK")
end
local ok = pcall(function() Layout.compute(0, 0) end)
assert(not ok, "Invalid viewport should be rejected")
local fake = Layout.compute(568, 320)
fake.Slide = fake.Reload
local passed = Layout.check(568, 320, fake)
assert(not passed, "Control overlap detector must reject collisions")
print("IRON YARD adaptive Android touch control geometry: 11 layouts and overlap guard OK")
