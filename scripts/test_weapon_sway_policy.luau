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

-- A constant camera angular speed must create the same weapon sway across
-- mobile render rates, not a doubled response at 30 FPS / half at 120 FPS.
local targetX, targetY
for _, hz in ipairs({30, 60, 120}) do
    local dt = 1 / hz
    local sx, sy = Policy.target(0, 0, true, 0.48 * dt, -0.60 * dt, dt)
    close(sx, 0.60 * (1/60) * 0.65)
    close(sy, -0.48 * (1/60) * 0.65)
    if targetX then
        close(sx, targetX)
        close(sy, targetY)
    end
    targetX, targetY = sx, sy
    -- The existing 14Hz exponential viewmodel lerp must also converge to
    -- the same visible pose over one second, irrespective of frame count.
    local displayedX, displayedY = 0, 0
    for _ = 1, hz do
        local alpha = 1 - math.exp(-14 * dt)
        displayedX += (sx - displayedX) * alpha
        displayedY += (sy - displayedY) * alpha
    end
    close(displayedX, sx * (1 - math.exp(-14)))
    close(displayedY, sy * (1 - math.exp(-14)))
end

-- The 240 FPS denominator bound prevents a 1ms render interval from
-- amplifying tiny camera jitter. Large legitimate turns remain clamped.
local fastX, fastY = Policy.target(0, 0, true, 0.001, -0.001, 0.001)
close(fastX, 0.001 * 4 * 0.65)
close(fastY, -0.001 * 4 * 0.65)
for _, hz in ipairs({30, 60, 120, 240, 1000}) do
    local dt = 1 / hz
    local sx, sy = Policy.target(0, 0, true, 0.3, -0.3, dt)
    assert(sx >= -0.04 and sx <= 0.04)
    assert(sy >= -0.035 and sy <= 0.035)
    assert(sx == sx and sy == sy)
end

local hybridX, hybridY = Policy.target(16, -5, true, 0.05, -0.06, 1/30)
close(hybridX, -0.032)
close(hybridY, 0.010)

print("IRON YARD touch/gamepad camera inertia and mouse priority: OK")
print("IRON YARD mobile sway: 30/60/120Hz parity and bounded ultra-short frames OK")
