-- IRON YARD / purely cosmetic B-8 shell-loading presentation.
-- Each server-confirmed whole-magazine reload has one visible insertion.
-- No inferred ammunition, networking, hitbox or physics.
local Visual = {}

function Visual.sample(progress, reloading, graphicsPreset)
    if reloading ~= true or graphicsPreset == "ECO"
        or type(progress) ~= "number" or progress ~= progress
        or progress < 0.27 or progress > 0.74 then return nil end
    -- The prop enters the receiver and is hidden once seated.
    local t = math.clamp((progress - 0.27) / 0.47, 0, 1)
    local seated = t * t * (3 - 2 * t)
    return {
        x = 0.23 * seated,
        y = 0.065 * math.sin(math.pi * t),
        z = -0.26 * seated,
        roll = -0.28 * seated,
    }
end

return Visual
