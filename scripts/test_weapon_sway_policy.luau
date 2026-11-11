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
