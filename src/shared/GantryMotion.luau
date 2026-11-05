-- IRON YARD / finite, deterministic client cosmetic rig motion.
-- Does not touch map colliders, raycasts, server physics or humanoid AI.
local GantryMotion = {}
local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < 1e8
end

function GantryMotion.pose(seconds, index, preset, distance)
    if not finite(seconds) or not finite(index) or not finite(distance)
        or index < 1 or index > 4 or distance < 0 then
        return 0, 0, 0
    end
    local cutoff = preset == "QUALITY" and 285 or 185
    if preset == "ECO" or distance > cutoff then
        return 0, 0, 0
    end
    local phase = index * 1.75
    local travel = math.sin(seconds * 0.27 + phase) * 5.6
    local lift = math.sin(seconds * 0.43 + phase + 0.9) * 0.70
    local beacon = 0.17 + math.pow((1 + math.sin(seconds * 3.6 + phase)) * 0.5, 3) * 0.55
    return travel, lift, beacon
end

return GantryMotion
