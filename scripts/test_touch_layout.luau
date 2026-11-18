local Layout = require("../src/shared/TouchLayout")

local function checkNativeJump(w, h, preset)
    local small = math.min(w, h) <= 500
    local size = small and 70 or 120
    local jump = { x = w - (size * 1.5 - 10), y = h - (small and size + 20 or size * 1.75),
        w = size, h = size }
    local controls = Layout.compute(w, h, preset, jump)
    local ok, reason = Layout.check(w, h, controls)
    assert(ok, string.format("%dx%d %s with native jump: %s", w, h, preset, tostring(reason)))
    for _, name in ipairs(Layout.NAMES) do
        local rect = controls[name]
        assert(rect.x + rect.w <= jump.x or jump.x + jump.w <= rect.x
            or rect.y + rect.h <= jump.y or jump.y + jump.h <= rect.y,
            string.format("%dx%d %s: %s overlaps native jump", w, h, preset, name))
    end
end

local screens = {
    {260, 210}, {280, 225}, {300, 240}, {300, 260}, {320, 280}, {360, 300}, {400, 800}, {568, 320},
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
        checkNativeJump(w, h, preset)
        sizes[preset] = layout.Fire.w
    end
    assert(sizes.COMPACT <= sizes.STANDARD and sizes.STANDARD <= sizes.LARGE,
        "Sizes must remain ordered even when a small viewport caps the presets")
    if h >= 260 and w >= 300 then
        assert(sizes.COMPACT < sizes.LARGE, "Presets should change size where space allows")
    end
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
blocked.Knife = Layout.MENU_BUTTONS.Settings
assert(not Layout.check(320, 280, blocked),
    "Settings access must never overlap the mobile weapon strip")
blocked.Knife = Layout.MENU_BUTTONS.Duel
assert(not Layout.check(320, 280, blocked), "Duel button must stay clear of weapon selection")
for w = Layout.MIN_WIDTH, 1200, 13 do
    for h = Layout.MIN_HEIGHT, 700, 11 do
        for _, preset in ipairs(Layout.PRESETS) do
            local valid, reason = Layout.check(w, h, Layout.compute(w, h, preset))
            assert(valid, string.format("%dx%d %s: %s", w, h, preset, tostring(reason)))
            checkNativeJump(w, h, preset)
        end
    end
end
print("IRON YARD touch controls: safe bounds, menus and native jump clearance OK")
