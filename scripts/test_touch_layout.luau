local Layout = require("../src/shared/TouchLayout")

local screens = {
    {300, 260}, {320, 280}, {360, 300}, {400, 800}, {568, 320},
    {640, 360}, {740, 360}, {800, 400}, {915, 412},
    {1024, 768}, {1280, 720}, {1920, 1080},
}
for _, viewport in ipairs(screens) do
    local w, h = viewport[1], viewport[2]
    local sizes = {}
    for _, preset in ipairs(Layout.PRESETS) do
        local layout = Layout.compute(w, h, preset)
        local ok, reason = Layout.check(w, h, layout)
        assert(ok, tostring(w) .. "x" .. tostring(h)
            .. " " .. preset .. ": " .. tostring(reason))
        assert(layout.Fire.x > w / 2 or w < 500,
            "Fire action should be on the right side of a landscape screen")
        assert(layout.Fire.x > layout.Aim.x, "Fire must be right of ADS")
        assert(layout.Reload.y > layout.AssaultRifle.y,
            "Utility controls must be below weapon selection")
        assert(layout.Fire.y > layout.Reload.y,
            "Fire must be below utility controls")
        sizes[preset] = layout.Fire.w
    end
    assert(sizes.COMPACT < sizes.STANDARD and sizes.STANDARD < sizes.LARGE,
        "Touch sizes must change materially on every tested viewport")
    local default = Layout.compute(w, h)
    assert(default.Fire.w == sizes.STANDARD, "Default preset is standard")
    print("IRON YARD mobile " .. w .. "x" .. h
        .. ": compact/standard/large within bounds")
end
local ok = pcall(function() Layout.compute(0, 0) end)
assert(not ok, "Invalid viewport should be rejected")
assert(not pcall(function() Layout.compute(568, 320, "INVALID") end),
    "Unknown touch presets are rejected")
local fake = Layout.compute(568, 320)
fake.Slide = fake.Reload
local passed = Layout.check(568, 320, fake)
assert(not passed, "Control overlap detector must reject collisions")
local blocked = Layout.compute(320, 280, "LARGE")
blocked.Knife = Layout.SETTINGS_BUTTON
assert(not Layout.check(320, 280, blocked),
    "Settings access must never overlap the mobile weapon strip")
print("IRON YARD Android touch controls: 36 presets, safe settings and no overlaps OK")
