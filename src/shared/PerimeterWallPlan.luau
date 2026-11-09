-- IRON YARD / four existing arena boundary walls, pure placement policy.
-- No Roblox services: mismatch rejects unknown collision geometry.
local Plan = {}

local function near(n, expected)
    return type(n) == "number" and n == n and n < math.huge
        and n > -math.huge and math.abs(n - expected) <= 0.01
end

function Plan.layout(name, sizeX, sizeY, sizeZ)
    local axis, side, label
    for _, candidate in ipairs({ -1, 1 }) do
        if name == "BOUNDARY / east-west " .. tostring(candidate) then
            axis, side = "X", candidate
            label = candidate < 0 and "WEST" or "EAST"
            break
        elseif name == "BOUNDARY / north-south " .. tostring(candidate) then
            axis, side = "Z", candidate
            label = candidate < 0 and "NORTH" or "SOUTH"
            break
        end
    end
    if not axis or not near(sizeY, 38) then return nil end
    if axis == "X" then
        if not near(sizeX, 4) or not near(sizeZ, 356) then return nil end
    elseif not near(sizeX, 356) or not near(sizeZ, 4) then
        return nil
    end
    local panels = {}
    for i = 1, 7 do
        local along = (i - 4) * 50
        -- 46-stud modules remain inside the authoritative 356-stud wall.
        table.insert(panels, {
            index = i,
            along = along,
            width = 46,
            signal = i == 2 or i == 4 or i == 6,
            detail = i % 2 == 0,
        })
    end
    return { axis = axis, side = side, label = label, panels = panels }
end

return Plan
