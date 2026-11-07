-- Pure, paired target/sighting selection. Only server-LOS-verified entries
-- may supply a fresh target position; no hidden enemy live coordinates.
local Selection = {}
Selection.MEMORY_SECONDS = 2.2
Selection.RECENT_ATTACKER_BONUS = 55

function Selection.choose(entries, previous, now, lastSeenAt)
    local best, highest, verified = nil, -math.huge, nil
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
                if value > highest then
                    best, highest = entry.model, value
                    verified = visible and entry.position or nil
                end
            end
        end
    end
    return best, verified
end
return Selection
