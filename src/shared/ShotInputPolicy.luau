-- IRON YARD / no-allocation numeric validation of server shot input.
-- Game engine Vector3 normalization still happens only after validation.
local Policy = {}

local function validNumber(n)
    return type(n) == "number" and n == n and n >= -1000000
        and n <= 1000000
end

-- Same direction acceptance as WeaponService: reject nonfinite vectors,
-- coordinates beyond +/-1e6 and vectors too small to normalize safely.
-- Squared magnitude avoids a temporary table and a square root per shot.
function Policy.validDirection(x, y, z)
    return validNumber(x) and validNumber(y) and validNumber(z)
        and x * x + y * y + z * z >= 0.000001
end

-- Camera origin is an optional aiming hint, never the damage ray origin.
-- Beyond this offset (including under replication latency) the server
-- preserves the original head-origin shot rather than rejecting the fire.
Policy.MAX_CONVERGENCE_OFFSET = 4.5
function Policy.validCameraOffset(dx, dy, dz)
    return validNumber(dx) and validNumber(dy) and validNumber(dz)
        and dx * dx + dy * dy + dz * dz
            <= Policy.MAX_CONVERGENCE_OFFSET * Policy.MAX_CONVERGENCE_OFFSET
end

return Policy
