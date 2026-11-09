-- IRON YARD / pure bot-detail cache and hysteresis policy.
-- Caches ONLY Tier="Detail" cosmetics; never the hitbox skeleton or Core.
-- Dynamic streaming or model replacement use observe/remove, not rescans.
local ArtLOD = require("./ArtLODPolicy")
local Cache = {}

function Cache.new()
    return { details = {}, count = 0, hidden = nil }
end

-- True only if the eligible cosmetic set actually changed.
function Cache.observe(state, part, tier)
    local previous = state.details[part] == true
    local eligible = tier == "Detail"
    if previous == eligible then return false end
    if eligible then
        state.details[part] = true
        state.count += 1
    else
        state.details[part] = nil
        state.count -= 1
    end
    return true
end

function Cache.remove(state, part)
    return Cache.observe(state, part, nil)
end

-- Correct original hysteresis: far enough to hide, much closer to show.
-- First observation always applies the mode; later polls are O(1) until
-- the camera crosses the threshold.
function Cache.decide(state, distanceSquared, hideBeyond, showBefore)
    local hidden = ArtLOD.hiddenSquared(
        distanceSquared, state.hidden == true, hideBeyond, showBefore)
    local changed = hidden ~= state.hidden
    state.hidden = hidden
    return changed, hidden
end

return Cache
