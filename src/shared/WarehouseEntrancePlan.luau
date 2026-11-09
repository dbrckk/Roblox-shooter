-- IRON YARD / warehouse entrance anchored to the three real gameplay walls.
-- Pure module used by server art and standalone Luau regression tests.
local Plan = {}

local function near(n, expected)
    return type(n) == "number" and n == n
        and n < math.huge and n > -math.huge
        and math.abs(n - expected) <= 0.01
end

local function matches(part, name, x, y, z, sx, sy, sz)
    return type(part) == "table" and part.name == name
        and near(part.x, x) and near(part.y, y) and near(part.z, z)
        and near(part.sx, sx) and near(part.sy, sy) and near(part.sz, sz)
        and near(part.pitch, 0) and near(part.yaw, 0)
        and near(part.roll, 0)
end

function Plan.layout(west, east, rear)
    if not matches(west, "WAREHOUSE / west wall", -30, 8, 11, 3, 16, 72)
        or not matches(east, "WAREHOUSE / east wall", 30, 8, 11, 3, 16, 72)
        or not matches(rear, "WAREHOUSE / north bulkhead", 0, 8, 61, 64, 16, 3) then
        return nil
    end
    local span = east.x - west.x
    local centerX = (east.x + west.x) * 0.5
    local frontZ = math.min(west.z - west.sz * 0.5, east.z - east.sz * 0.5)
    local eaveY = west.y + west.sy * 0.5 + 4
    local approachZ = frontZ - 12
    -- Three marked approach lanes, well away from the real side walls.
    local lanes = {
        { id = "WEST", x = centerX - span * 0.25 },
        { id = "CENTRAL", x = centerX },
        { id = "EAST", x = centerX + span * 0.25 },
    }
    return {
        centerX = centerX,
        westX = west.x,
        eastX = east.x,
        frontZ = frontZ,
        eaveY = eaveY,
        openingWidth = span,
        approachZ = approachZ,
        lanes = lanes,
    }
end

return Plan
