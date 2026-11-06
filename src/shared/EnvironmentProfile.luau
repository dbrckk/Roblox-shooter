-- IRON YARD / pure, bounded environmental lighting budgets.
-- Client visual settings only; geometry and weapon hitboxes remain server-owned.
local EnvironmentProfile = {}

local PRESETS = {
    ECO = {
        density = 0.075, haze = 0.24, glare = 0,
        brightness = 0.035, contrast = 0.035, saturation = -0.035,
        exposure = 0.08, bloom = false, lamps = 0, lampRange = 0,
    },
    MOBILE = {
        density = 0.095, haze = 0.36, glare = 0.01,
        brightness = 0.015, contrast = 0.055, saturation = -0.02,
        exposure = 0.06, bloom = false, lamps = 2, lampRange = 78,
    },
    MOBILE_QUALITY = {
        density = 0.115, haze = 0.40, glare = 0.02,
        brightness = 0.01, contrast = 0.065, saturation = -0.018,
        exposure = 0.045, bloom = false, lamps = 4, lampRange = 95,
    },
    DESKTOP = {
        density = 0.11, haze = 0.39, glare = 0.02,
        brightness = 0.008, contrast = 0.07, saturation = -0.02,
        exposure = 0.045, bloom = false, lamps = 4, lampRange = 105,
    },
    DESKTOP_QUALITY = {
        density = 0.13, haze = 0.46, glare = 0.04,
        brightness = 0.005, contrast = 0.075, saturation = -0.02,
        exposure = 0.035, bloom = true, lamps = 8, lampRange = 135,
    },
}

function EnvironmentProfile.get(preset, isTouch)
    if preset == "ECO" then return PRESETS.ECO end
    if preset == "QUALITY" then
        return isTouch and PRESETS.MOBILE_QUALITY or PRESETS.DESKTOP_QUALITY
    end
    return isTouch and PRESETS.MOBILE or PRESETS.DESKTOP
end

-- Stable nearest-fixture selection, with no allocations beyond the tiny
-- number of actual overhead fixtures in the freight arena.
function EnvironmentProfile.activeFixtureIndices(distances, preset, isTouch)
    local settings = EnvironmentProfile.get(preset, isTouch)
    local candidates = {}
    for index, distance in ipairs(distances) do
        if type(distance) == "number" and distance == distance
            and distance >= 0 and distance <= settings.lampRange then
            table.insert(candidates, { index = index, distance = distance })
        end
    end
    table.sort(candidates, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.index < b.index
    end)
    local chosen = {}
    for i = 1, math.min(#candidates, settings.lamps) do
        chosen[candidates[i].index] = true
    end
    return chosen
end

return EnvironmentProfile
