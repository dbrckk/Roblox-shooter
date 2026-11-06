-- IRON YARD / pure validation for untrusted client movement directions.
-- Convert numeric results to Roblox Vector3 only after validation.
local SafePlanarInput = {}
local MAX_COMPONENT = 1000000
local MIN_PLANAR_LENGTH = 0.05

function SafePlanarInput.normalize(x, y, z)
    for _, coordinate in ipairs({ x, y, z }) do
        if type(coordinate) ~= "number" or coordinate ~= coordinate
            or math.abs(coordinate) > MAX_COMPONENT then
            return nil
        end
    end
    local magnitude = math.sqrt(x * x + z * z)
    if magnitude <= MIN_PLANAR_LENGTH then return nil end
    return { x = x / magnitude, z = z / magnitude }
end

return SafePlanarInput
