-- IRON YARD / pure client camera FOV ownership policy.
-- The active weapon alone defines optical FOV; never used for damage or aim.
local Scope = {}

local function finitePositive(n)
    return type(n) == "number" and n == n and n > 0 and n < math.huge
end

function Scope.fieldOfView(baseFov, scoped, config)
    local fallback = finitePositive(baseFov) and math.clamp(baseFov, 40, 110) or 70
    if scoped ~= true or type(config) ~= "table" then return fallback end
    local zoom = config.zoomFieldOfView or config.aimFov
    if not finitePositive(zoom) then return fallback end
    return math.clamp(zoom, 15, fallback)
end

return Scope
