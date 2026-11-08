-- IRON YARD / authoritative forklift cosmetic variant and orientation plan.
-- Receives server collider dimensions and server-authored visual identity.
-- Does NOT create collision, cover or movement surfaces.
local Plan = {}

local FLEETS = {
    ["12"] = { kind = "FREIGHT_LIFTER", yaw = math.rad(10) },
    ["27"] = { kind = "YARD_HANDLER", yaw = math.rad(180) },
}

local function validNumber(value)
    return type(value) == "number" and value == value
        and value < math.huge and value > -math.huge
end

function Plan.forCollider(name, width, height, depth, fleet, yaw)
    if name ~= "INDUSTRIAL / forklift body"
        or not validNumber(width) or not validNumber(height)
        or not validNumber(depth) or not validNumber(yaw)
        or math.abs(width - 8) > 0.02
        or math.abs(height - 3.1) > 0.02
        or math.abs(depth - 11) > 0.02 then
        return nil
    end

    local config = FLEETS[fleet]
    if not config or math.abs(yaw - config.yaw) > 0.0001 then return nil end
    return {
        label = fleet,
        kind = config.kind,
        yaw = yaw,
    }
end

return Plan
