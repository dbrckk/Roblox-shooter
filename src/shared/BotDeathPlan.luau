-- IRON YARD / deterministic, bounded non-physics R6 defeat choreography.
-- This only sets cosmetic Motor6D poses. It never changes hitboxes/damage.
local Plan = {}

local function direction(value)
    if type(value) ~= "number" or value ~= value
        or math.abs(value) == math.huge then return 0 end
    return math.clamp(value, -1, 1)
end

function Plan.sequence(hitSide, hitFront, slot)
    local side = direction(hitSide)
    local front = direction(hitFront)
    -- Unattributed environmental defeats vary slightly by slot rather
    -- than making four bots fall in an identical robotic direction.
    if math.abs(side) < 0.08 then
        side = (type(slot) == "number" and slot % 2 == 0) and 0.18 or -0.18
    end
    return {
        {
            duration = 0.16, drop = -0.16,
            pitch = -0.27 - front * 0.10, roll = side * 0.24,
            leftArm = 0.46, rightArm = 0.36,
            leftHip = -0.11, rightHip = 0.10, neck = 0.14,
        },
        {
            duration = 0.48, drop = -0.65,
            pitch = -0.83 - front * 0.13, roll = side * 0.34,
            leftArm = 1.06, rightArm = 0.86,
            leftHip = 0.46, rightHip = 0.59, neck = 0.24,
        },
        {
            duration = 0.27, drop = -0.86,
            pitch = -1.07 - front * 0.06, roll = side * 0.25,
            leftArm = 1.23, rightArm = 1.01,
            leftHip = 0.74, rightHip = 0.84, neck = 0.18,
        },
    }
end

function Plan.duration(stages)
    local total = 0
    if type(stages) ~= "table" then return total end
    for _, stage in ipairs(stages) do
        if type(stage.duration) ~= "number" or stage.duration ~= stage.duration
            or stage.duration <= 0 or stage.duration == math.huge then
            return 0
        end
        total += stage.duration
    end
    return total
end

-- No networked dust: only a single client-side floor probe per death, with
-- transient FX allocated inside the selected mobile/desktop graphics budget.
function Plan.dustBudget(preset, touch, distance)
    if type(distance) ~= "number" or distance ~= distance
        or distance < 0 or distance == math.huge then return nil end
    local maximum = preset == "ECO" and 58
        or (preset == "QUALITY" and (touch and 135 or 175))
        or (touch and 95 or 145)
    if distance > maximum then return nil end
    return {
        fragments = preset == "ECO" and 1
            or (touch and (preset == "QUALITY" and 3 or 2)
                or (preset == "QUALITY" and 4 or 3)),
        duration = 0.36,
    }
end

return Plan
