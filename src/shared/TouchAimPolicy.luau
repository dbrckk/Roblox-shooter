-- Pixel drag to radians. Normalize to the short viewport dimension so a
-- similar swipe has the same effect on compact phones and large tablets.
local Aim = {}
Aim.PRESETS = { 0.75, 1, 1.25 }
Aim.MAX_PITCH = math.rad(75)

local function finite(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

function Aim.rotation(dx, dy, shortSide, preset, opticalFov, baseFov)
    if not finite(dx) or not finite(dy) or not finite(shortSide) or shortSide <= 0 then
        return 0, 0
    end
    local fovScale = 1
    if finite(opticalFov) and finite(baseFov) and baseFov > 0 then
        fovScale = math.clamp(opticalFov / baseFov, 0.25, 1)
    end
    local scale = 2.4 * (Aim.PRESETS[preset] or Aim.PRESETS[2]) * fovScale / shortSide
    local limit = shortSide * 0.35
    return -math.clamp(dx, -limit, limit) * scale,
        -math.clamp(dy, -limit, limit) * scale
end

return Aim
