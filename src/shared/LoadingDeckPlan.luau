-- IRON YARD / physical geometry of the freight transfer deck.
local Plan = {
    DECK_NAME = "VAULT / raised loading deck",
    RAMP_NAME = "VAULT / transfer ramp",
    x = 13,
    z = 85,
    width = 17,
    height = 3,
    depth = 12,
    top = 8.5,
}

function Plan.support(side)
    local height = Plan.top - Plan.height
    return {
        x = Plan.x + side * 7.1,
        y = height / 2,
        z = Plan.z,
        width = 1.8,
        height = height,
        depth = 3.8,
    }
end

function Plan.ramp()
    local topZ = Plan.z + Plan.depth / 2 - 0.15
    local bottomZ = 116
    local run = bottomZ - topZ
    local pitch = math.atan(Plan.top / run)
    local thickness = 0.8
    -- Offset from the center of the walking surface along the local up axis.
    return {
        x = Plan.x + 3.5,
        y = (Plan.top - math.cos(pitch) * thickness) / 2,
        z = (topZ + bottomZ - math.sin(pitch) * thickness) / 2,
        width = 7.5,
        height = thickness,
        length = math.sqrt(run * run + Plan.top * Plan.top),
        pitch = pitch,
    }
end

return Plan
