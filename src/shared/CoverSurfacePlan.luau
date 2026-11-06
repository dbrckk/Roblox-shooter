-- IRON YARD / original freight cover surface plan.
-- Pure Luau. This plans visuals only; it cannot affect movement collision.
local CoverSurfacePlan = {}

function CoverSurfacePlan.forCollider(name, x, y, z)
    if type(name) ~= "string" then return nil end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number"
        or x ~= x or y ~= y or z ~= z
        or x < 1 or y < 1 or z < 1 then return nil end
    local style
    if string.find(name, "COVER / concrete barrier ", 1, true) == 1 then
        style = "CAST_CONCRETE"
    elseif string.find(name, "COVER / movable roadblock ", 1, true) == 1 then
        style = "ARMED_ROADBLOCK"
    elseif string.find(name, "WAREHOUSE / cover ", 1, true) == 1 then
        style = "CARGO_BARRIER"
    elseif name == "VAULT / packing station" then
        style = "CARGO_BARRIER"
    else
        return nil
    end
    -- Avoid detailing a source part that is unexpectedly short, malformed
    -- or too narrow for a sensible bar/plate layout.
    if x < 4 or y < 2 or z < 2 then return nil end
    return {
        style = style,
        length = x,
        height = y,
        width = z,
        faceLength = math.max(1, x - 0.8),
        faceHeight = math.max(0.5, y - 0.65),
        stripeCount = math.clamp(math.floor(x / 4), 2, 5),
        surfaceOffset = z * 0.5 + 0.038,
    }
end

return CoverSurfacePlan
