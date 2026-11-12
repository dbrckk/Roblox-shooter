local Policy = require("../src/shared/WeaponSwayPolicy")

local function close(actual, wanted)
    assert(math.abs(actual - wanted) < 1e-6,
        "Unexpected cosmetic sway target: " .. tostring(actual)
            .. " vs " .. tostring(wanted))
end

-- Mouse movement remains the established primary source on PC or hybrids.
local x, y = Policy.target(12, -8, false, 0.07, 0.10, 1/60)
close(x, -0.024)
close(y, 0.016)
x, y = Policy.target(12, -8, true, 0.07, 0.10, 1/60)
close(x, -0.024)
close(y, 0.016)

-- Touch/gamepad without GetMouseDelta: camera angular displacement drives
-- small weapon inertia instead of an unnaturally rigid model.
x, y = Policy.target(0, 0, true, 0.02, -0.03, 1/60)
close(x, 0.0195)
close(y, -0.013)
x, y = Policy.target(0, 0, true, 0, 0, 1/60)
close(x, 0)
close(y, 0)
x, y = Policy.target(0, 0, false, 0.1, 0.1, 1/60)
close(x, 0)
close(y, 0)

-- Extreme input cannot block sight alignment; no infinite/NaN output.
x, y = Policy.target(100000, -100000, true, 0.01, 0.01, 1/60)
close(x, -0.04)
close(y, 0.035)
x, y = Policy.target(0, 0, true, -0.2, 0.2, 1/60)
close(x, -0.04)
close(y, 0.035)

-- Camera teleport, scene switch, pause/hitch or untrusted angle does not
-- create a violent one-frame kick.
for _, dt in ipairs({0, -1, 0.3, math.huge}) do
    x, y = Policy.target(0, 0, true, 0.12, -0.12, dt)
    close(x, 0)
    close(y, 0)
end
x, y = Policy.target(0, 0, true, 0.4, 0.4, 1/60)
close(x, 0)
close(y, 0)
x, y = Policy.target(0, 0, true, 0/0, 0/0, 1/60)
close(x, 0)
close(y, 0)
x, y = Policy.target(0/0, math.huge, false, 0, 0, 1/60)
close(x, 0)
close(y, 0)

print("IRON YARD touch/gamepad camera inertia and mouse priority: OK")

-- Same camera angular velocity must produce the exact same weapon sway
-- target at 30/60/120 Hz. Previously 30 Hz doubled and 120 Hz halved it.
local targetX, targetY = nil, nil
for _, hz in ipairs({30, 60, 120}) do
    local dt = 1 / hz
    local x30, y30 = Policy.target(0, 0, true, 0.48 * dt, -0.60 * dt, dt)
    close(x30, 0.60 * (1/60) * 0.65)
    close(y30, -0.48 * (1/60) * 0.65)
    if targetX ~= nil then
        close(targetX, x30)
        close(targetY, y30)
    end
    targetX, targetY = x30, y30

    -- The existing exponential blend must converge to the same visible
    -- final pose for one real second, not a frame-count-dependent position.
    local displayedX, displayedY = 0, 0
    local rate = 14
    for _ = 1, hz do
        local alpha = 1 - math.exp(-rate * dt)
        displayedX += (x30 - displayedX) * alpha
        displayedY += (y30 - displayedY) * alpha
    end
    close(displayedX, x30 * (1 - math.exp(-rate)))
    close(displayedY, y30 * (1 - math.exp(-rate)))
end

-- High-speed turns remain bounded on every device and during unusually
-- short 1ms frames. Mouse priority and camera-cut rejection stay intact.
for _, hz in ipairs({30, 60, 120, 1000}) do
    local dt = 1 / hz
    local x30, y30 = Policy.target(0, 0, true, 0.3, -0.3, dt)
    assert(x30 >= -0.04 and x30 <= 0.04)
    assert(y30 >= -0.035 and y30 <= 0.035)
    assert(x30 == x30 and y30 == y30)
end
local hx, hy = Policy.target(16, -5, true, 0.05, -0.06, 1/30)
close(hx, -0.032)
close(hy, 0.010)
print("IRON YARD: touch/gamepad sway has time-normalized 30/60/120Hz parity OK")
