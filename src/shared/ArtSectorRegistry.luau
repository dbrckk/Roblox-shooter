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
    -- A streamed Part strictly inside the current bounds cannot change
    -- whole-sector LOD. Preserve its mode instead of repainting every Part.
    local expanded = not group
        or position.X < bounds.minX or position.X > bounds.maxX
        or position.Y < bounds.minY or position.Y > bounds.maxY
        or position.Z < bounds.minZ or position.Z > bounds.maxZ
    if not ArtLOD.extendBounds(bounds, position) then return false end
    if not group then
        group = { parts = {}, bounds = bounds, lastMode = nil, count = 0 }
        state.byKey[key] = group
        state.groupCount += 1
    elseif expanded then
        group.lastMode = nil
    end
    group.parts[part] = true
    group.count += 1
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
        local before = group.bounds
        local p = record.position
        -- Only a removed extremum can shrink the six sector AABB faces.
        -- Interior stream-outs are O(1), preventing quadratic churn.
        local edge = p.X == before.minX or p.X == before.maxX
            or p.Y == before.minY or p.Y == before.maxY
            or p.Z == before.minZ or p.Z == before.maxZ
        if edge then
            local bounds = {}
            for other in pairs(group.parts) do
                ArtLOD.extendBounds(bounds, state.byPart[other].position)
            end
            group.bounds = bounds
            -- Another Part may share the removed extremum. Only invalidate
            -- the group's mode when its actual bounds change.
            if bounds.minX ~= before.minX or bounds.maxX ~= before.maxX
                or bounds.minY ~= before.minY or bounds.maxY ~= before.maxY
                or bounds.minZ ~= before.minZ or bounds.maxZ ~= before.maxZ then
                group.lastMode = nil
            end
        end
    end
    return true
end

-- On a whole arena/folder teardown all positions and groups are obsolete.
-- Drop both tables in O(1) rather than rebuilding sector bounds once per Part.
function Registry.clear(state)
    state.byKey = {}
    state.byPart = {}
    state.count = 0
    state.groupCount = 0
end

return Registry
