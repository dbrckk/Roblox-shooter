-- IRON YARD / deterministic presentation for ACTUAL cargo pallet colliders.
-- This pure plan never creates or modifies movement/bullet geometry.
local Plan = {}

local STYLE_BY_INDEX = {
    "TIMBER_CRATE", "WRAPPED_FREIGHT", "STEEL_CAGE",
    "TIMBER_CRATE", "WRAPPED_FREIGHT",
}

local function validSize(value, expected)
    return type(value) == "number"
        and value == value
        and value < math.huge and value > -math.huge
        and math.abs(value - expected) <= 0.02
end

function Plan.forCollider(name, width, height, depth)
    if type(name) ~= "string"
        or not validSize(width, 9)
        or not validSize(height, 3.7)
        or not validSize(depth, 9) then
        return nil
    end
    local indexText = name:match("^INDUSTRIAL / pallet stack ([1-5])$")
    if not indexText then return nil end
    local index = tonumber(indexText)
    if not index then return nil end
    return {
        index = index,
        style = STYLE_BY_INDEX[index],
        label = string.format("IY-%02d", index),
    }
end

return Plan
