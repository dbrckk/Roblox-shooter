-- IRON YARD / incremental spatial inventory for server-authored client cosmetics.
-- Pure registry: tracks original static authoring position, never collisions.
-- Sector bounds are rebuilt only for the affected sector on removals.
local ArtLOD = require("./ArtLODPolicy")
local Registry = {}

function Registry.new()
    return { byKey = {}, byPart = {}, count = 0, groupCount = 0 }
end

function Registry.add(state, part, position)
    if type(state) ~= "table" or part == nil or state.byPart[part] then
        return false
    end
    if not position then return false end
    local key = ArtLOD.cellKey(position.X, position.Z)
    if not key then return false end
    local group = state.byKey[key]
    local bounds = group and group.bounds or {}
    if not ArtLOD.extendBounds(bounds, position) then return false end
    if not group then
        group = { parts = {}, bounds = bounds, lastMode = nil, count = 0 }
        state.byKey[key] = group
        state.groupCount += 1
    end
    group.parts[part] = true
    group.count += 1
    group.lastMode = nil
    state.byPart[part] = { group = group, position = position }
    state.count += 1
    return true, group
end

function Registry.remove(state, part)
    if type(state) ~= "table" then return false end
    local record = state.byPart[part]
    if not record then return false end
    local group = record.group
    state.byPart[part] = nil
    group.parts[part] = nil
    group.count -= 1
    state.count -= 1
    if group.count == 0 then
        local key = ArtLOD.cellKey(record.position.X, record.position.Z)
        state.byKey[key] = nil
        state.groupCount -= 1
    else
        -- Recalculate only the affected 48-stud sector. Removed parts must
        -- not leave a huge stale bounding box after Roblox streams them out.
        local bounds = {}
        for other in pairs(group.parts) do
            ArtLOD.extendBounds(bounds, state.byPart[other].position)
        end
        group.bounds = bounds
        group.lastMode = nil
    end
    return true
end

return Registry
