-- IRON YARD: bounded, deterministic spawn exposure scoring.
-- The caller supplies server-observed opponent distances and real cover LOS.
-- No client positions, remote data or Roblox services are used here.
local SpawnSafety = {}

SpawnSafety.EXPOSURE_RANGE = 165

function SpawnSafety.score(nearestDistance, visibleCount, closestVisibleDistance, tieBreaker)
    local separation = math.clamp(nearestDistance, 0, 220)
    -- A spawn inside a close fight is never preferable just because it has
    -- one wall. Once sufficiently separated, favor positions behind cover.
    local closePenalty = math.max(0, 85 - separation) * 2.5
    local exposed = math.clamp(visibleCount, 0, 6)
    local exposurePenalty = exposed * 15
    if exposed > 0 then
        exposurePenalty += math.max(0,
            SpawnSafety.EXPOSURE_RANGE - closestVisibleDistance) * 0.47
    end
    return separation - closePenalty - exposurePenalty
        + math.clamp(tieBreaker or 0, -6, 6)
end

return SpawnSafety
