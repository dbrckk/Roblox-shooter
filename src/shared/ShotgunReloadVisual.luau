-- IRON YARD / allocation-free, purely cosmetic B-8 reload pose.
-- Real ammo and reload authority remain in WeaponService.
local Visual = {}

-- Returns four scalar offsets; NEVER creates a table every RenderStepped.
-- nil first return means the shell must be hidden (ECO / no reload / outside).
function Visual.sample(progress, reloading, graphicsPreset)
    if reloading ~= true or graphicsPreset == "ECO"
        or type(progress) ~= "number" or progress ~= progress
        or progress < 0.27 or progress > 0.74 then return nil end
    local t = math.clamp((progress - 0.27) / 0.47, 0, 1)
    local seated = t * t * (3 - 2 * t)
    return 0.23 * seated,
        0.065 * math.sin(math.pi * t),
        -0.26 * seated,
        -0.28 * seated
end

return Visual
