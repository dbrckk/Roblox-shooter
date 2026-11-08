-- Pure, paired target/sighting selection. Only server-LOS-verified entries
-- may supply a fresh target position; no hidden enemy live coordinates.
local Selection = {}
Selection.MEMORY_SECONDS = 2.2
Selection.RECENT_ATTACKER_BONUS = 55
Selection.TARGET_COMMIT_SECONDS = 1.35
Selection.SWITCH_MARGIN = 15
Selection.EMERGENCY_SWITCH_MARGIN = 25

function Selection.choose(entries, previous, now, lastSeenAt, lastSwitchAt)
    local best, highest, verified, verifiedAim = nil, -math.huge, nil, nil
    local previousScore, previousPosition, previousAim, previousVisible = nil, nil, nil, false
    local previousThreat = false
    local bestThreat = false
    for _, entry in ipairs(entries) do
        -- Hidden opponents MUST be scored against a previous verified
        -- sighting, never their current root distance (even if supplied
        -- accidentally by a caller). A visible entry needs a paired sighting.
        local visible = entry.visible == true and entry.position ~= nil
        local distance = visible and entry.distance or entry.memoryDistance
        if entry.model ~= nil and type(distance) == "number"
            and distance == distance and distance >= 0 and distance < math.huge then
            local recent = entry.model == previous
                and type(now) == "number" and type(lastSeenAt) == "number"
                and now >= lastSeenAt and now - lastSeenAt < Selection.MEMORY_SECONDS
            if visible or recent then
                local value = (visible and 150 or 25) - distance * 0.58
                if entry.model == previous then value += 28 end
                -- A bot recently shot from behind may respond to a fighter
                -- visibly standing near the confirmed hit origin. No bonus
                -- may be granted to an occluded candidate.
                if visible and entry.threatMatch == true then
                    value += Selection.RECENT_ATTACKER_BONUS
                end
                if entry.model == previous then
                    previousScore = value
                    previousPosition = visible and entry.position or nil
                    previousAim = visible and entry.aimPoint or nil
                    previousVisible = visible
                    previousThreat = visible and entry.threatMatch == true
                end
                if value > highest then
                    best, highest = entry.model, value
                    verified = visible and entry.position or nil
                    verifiedAim = visible and entry.aimPoint or nil
                    bestThreat = visible and entry.threatMatch == true
                end
            end
        end
    end
    -- A brief target commitment prevents oscillating between two equally
    -- visible fighters every 0.2 seconds, which would restart reaction time
    -- and invalidate pathfinding repeatedly. New urgent visible threats can
    -- still interrupt the commitment. Hidden memories never lock targeting.
    if best ~= nil and best ~= previous and previousVisible and previousScore then
        local early = type(now) == "number" and type(lastSwitchAt) == "number"
            and now >= lastSwitchAt
            and now - lastSwitchAt < Selection.TARGET_COMMIT_SECONDS
        local advantage = early and Selection.EMERGENCY_SWITCH_MARGIN
            or Selection.SWITCH_MARGIN
        local urgentVisibleAttacker = bestThreat and not previousThreat
        if not urgentVisibleAttacker and highest < previousScore + advantage then
            return previous, previousPosition, previousAim
        end
    end
    return best, verified, verifiedAim
end
return Selection
