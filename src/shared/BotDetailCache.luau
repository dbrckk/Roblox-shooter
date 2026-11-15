-- IRON YARD / pure bot-detail cache and hysteresis policy.
-- Caches distance-managed Detail and Silhouette cosmetics, excluding Core.
-- Dynamic streaming or model replacement use observe/remove, not rescans.
local ArtLOD = require("./ArtLODPolicy")
local Cache = {}

function Cache.new()
    return { details = {}, silhouettes = {}, count = 0, hidden = nil, silhouetteHidden = nil }
end

-- True only if the eligible cosmetic set actually changed.
function Cache.observe(state, part, tier)
    local detail = tier == "Detail"
    local silhouette = tier == "Silhouette"
    local wasDetail = state.details[part] == true
    local wasSilhouette = state.silhouettes[part] == true
    if detail == wasDetail and silhouette == wasSilhouette then return false end
    state.details[part] = detail and true or nil
    state.silhouettes[part] = silhouette and true or nil
    if detail ~= wasDetail then state.count += detail and 1 or -1 end
    return true
end

function Cache.remove(state, part)
    function Cache.decideSilhouette(state, distanceSquared, hideBeyond, showBefore)
    local hidden = ArtLOD.hiddenSquared(
        distanceSquared, state.silhouetteHidden == true, hideBeyond, showBefore)
    local changed = hidden ~= state.silhouetteHidden
    state.silhouetteHidden = hidden
    return changed, hidden
end

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

function Cache.decideSilhouette(state, distanceSquared, hideBeyond, showBefore)
    local hidden = ArtLOD.hiddenSquared(
        distanceSquared, state.silhouetteHidden == true, hideBeyond, showBefore)
    local changed = hidden ~= state.silhouetteHidden
    state.silhouetteHidden = hidden
    return changed, hidden
end

return Cache
