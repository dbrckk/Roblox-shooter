local Aim = require("../src/shared/TouchAimPolicy")
local function near(a, b)
    return math.abs(a - b) < 1e-9
end

local yaw, pitch = Aim.rotation(40, -20, 400, 2, 70, 70)
assert(yaw < 0 and pitch > 0, "Swipe must steer right and up")
local scaledYaw, scaledPitch = Aim.rotation(80, -40, 800, 2, 70, 70)
assert(near(yaw, scaledYaw) and near(pitch, scaledPitch))
local low = Aim.rotation(40, 0, 400, 1)
local high = Aim.rotation(40, 0, 400, 3)
assert(math.abs(low) < math.abs(yaw) and math.abs(high) > math.abs(yaw))
local optical = Aim.rotation(40, 0, 400, 2, 35, 70)
assert(near(optical, yaw * 0.5))
assert(Aim.rotation(1000, 0, 400, 2) == Aim.rotation(140, 0, 400, 2))
assert(Aim.rotation(40, 0, 0, 2) == 0 and Aim.rotation(0/0, 0, 400, 2) == 0)
assert(Aim.rotation(40, 0, 400, 0) == yaw)
print("Touch fire drag: viewport normalization, optical scale and bounds: OK")
