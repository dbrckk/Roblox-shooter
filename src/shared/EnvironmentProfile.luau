-- IRON YARD / pure, bounded environmental lighting budgets.
-- Client visual settings only; geometry and weapon hitboxes remain server-owned.
local EnvironmentProfile = {}

local PRESETS = {
    ECO = {
        density = 0.075, haze = 0.24, glare = 0,
        brightness = 0.035, contrast = 0.035, saturation = -0.035,
        exposure = 0.08, bloom = false, lamps = 0, lampRange = 0,
        exhausts = 0, exhaustRange = 0, exhaustInterval = 1.6,
    },
    MOBILE = {
        density = 0.095, haze = 0.36, glare = 0.01,
        brightness = 0.015, contrast = 0.055, saturation = -0.02,
        exposure = 0.06, bloom = false, lamps = 2, lampRange = 78,
        exhausts = 1, exhaustRange = 95, exhaustInterval = 1.35,
    },
    MOBILE_QUALITY = {
        density = 0.115, haze = 0.40, glare = 0.02,
        brightness = 0.01, contrast = 0.065, saturation = -0.018,
        exposure = 0.045, bloom = false, lamps = 4, lampRange = 95,
        exhausts = 2, exhaustRange = 128, exhaustInterval = 1.05,
    },
    DESKTOP = {
        density = 0.11, haze = 0.39, glare = 0.02,
        brightness = 0.008, contrast = 0.07, saturation = -0.02,
        exposure = 0.045, bloom = false, lamps = 4, lampRange = 105,
        exhausts = 2, exhaustRange = 147, exhaustInterval = 0.95,
    },
    DESKTOP_QUALITY = {
        density = 0.13, haze = 0.46, glare = 0.04,
        brightness = 0.005, contrast = 0.075, saturation = -0.02,
        exposure = 0.035, bloom = true, lamps = 8, lampRange = 135,
        exhausts = 4, exhaustRange = 180, exhaustInterval = 0.70,
    },
}

function EnvironmentProfile.get(preset, isTouch)
    if preset == "ECO" then return PRESETS.ECO end
    if preset == "QUALITY" then
        return isTouch and PRESETS.MOBILE_QUALITY or PRESETS.DESKTOP_QUALITY
    end
    return isTouch and PRESETS.MOBILE or PRESETS.DESKTOP
end

-- Fixture light temperature is specific to the real arena role, not a
-- global color filter. ECO remains unlit and mobile lamps stay inexpensive.
-- Returned values are pure, so they can be verified without Roblox Studio.
function EnvironmentProfile.fixtureStyle(role, preset, isTouch)
    local settings = EnvironmentProfile.get(preset, isTouch)
    if settings.lamps == 0 then return nil end
    if role == "CATWALK" then
        return {
            brightness = isTouch and 0.55 or 0.68,
            range = isTouch and 22 or 27,
            angle = 105,
            red = 222, green = 233, blue = 238,
        }
    end
    return {
        brightness = isTouch and 0.69 or 0.82,
        range = isTouch and 26 or 31,
        angle = 100,
        red = 255, green = 225, blue = 181,
    }
end

-- Both local lamps and rooftop exhaust vapor select only the nearest
-- visible sources. Stable ordering avoids frame-to-frame allocation spikes.
local function nearestIndices(distances, limit, range)
    local candidates = {}
    for index, distance in ipairs(distances) do
        if type(distance) == "number" and distance == distance
            and distance >= 0 and distance <= range and distance < math.huge then
            table.insert(candidates, { index = index, distance = distance })
        end
    end
    table.sort(candidates, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.index < b.index
    end)
    local chosen = {}
    for i = 1, math.min(#candidates, limit) do
        chosen[candidates[i].index] = true
    end
    return chosen
end

function EnvironmentProfile.activeFixtureIndices(distances, preset, isTouch)
    local settings = EnvironmentProfile.get(preset, isTouch)
    return nearestIndices(distances, settings.lamps, settings.lampRange)
end

function EnvironmentProfile.activeExhaustIndices(distances, preset, isTouch)
    local settings = EnvironmentProfile.get(preset, isTouch)
    return nearestIndices(distances, settings.exhausts, settings.exhaustRange)
end

return EnvironmentProfile
