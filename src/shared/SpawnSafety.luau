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

-- A second line of *physically validated* pads is used only when all twelve
-- curated FFA pads and the central Roblox SpawnLocation are obstructed.
-- Fixed 7x7 interior search (49 overlap checks maximum) remains within
-- the authoritative 356x356 terminal floor. No random off-map teleports.
-- The server supplies the real overlap check and cover/exposure score.
-- nil means NO clear pad: never claim that a shield solves solid geometry.
function SpawnSafety.chooseEmergencyPad(isClear, scoreAt)
    if type(isClear) ~= "function" or type(scoreAt) ~= "function" then
        return nil
    end
    local bestX, bestZ, bestScore = nil, nil, -math.huge
    for gx = -3, 3 do
        for gz = -3, 3 do
            local x, z = gx * 42, gz * 42
            if isClear(x, z) then
                local score = scoreAt(x, z)
                if type(score) == "number" and score == score
                    and score < math.huge and score > -math.huge
                    and score > bestScore then
                    bestX, bestZ, bestScore = x, z, score
                end
            end
        end
    end
    if bestX == nil then return nil end
    return bestX, bestZ
end

return SpawnSafety
