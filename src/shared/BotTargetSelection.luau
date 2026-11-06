-- Pure, paired target/sighting selection. Only server-LOS-verified entries
-- may supply a fresh target position; no hidden enemy live coordinates.
local Selection = {}
Selection.MEMORY_SECONDS = 2.2

function Selection.choose(entries, previous, now, lastSeenAt)
    local best, highest, verified = nil, -math.huge, nil
    for _, entry in ipairs(entries) do
        local distance = entry.distance
        if entry.model ~= nil and type(distance) == "number"
            and distance == distance and distance >= 0 and distance < math.huge then
            local visible = entry.visible == true
            local recent = entry.model == previous
                and type(now) == "number" and type(lastSeenAt) == "number"
                and now >= lastSeenAt and now - lastSeenAt < Selection.MEMORY_SECONDS
            if visible or recent then
                local value = (visible and 150 or 25) - distance * 0.58
                if entry.model == previous then value += 28 end
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
