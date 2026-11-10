-- IRON YARD / pure dense inventory for player-first-person visual parts.
-- A live first-person Character must not keep old streamed-out accessories,
-- tools or limb references in the per-frame transparency reconciliation.
-- Part identity is stable; remove uses swap-delete in O(1).
local Cache = {}

function Cache.new()
    return { list = {}, byPart = {}, count = 0 }
end

function Cache.add(state, part, transparency)
    if not state or part == nil or transparency == nil then return false end
    local existing = state.byPart[part]
    if existing then
        -- Reparenting a hand into an Accessory can change visibility even
        -- though its Part identity is unchanged.
        existing.entry.transparency = transparency
        return false
    end
    local index = #state.list + 1
    local entry = { part = part, transparency = transparency }
    state.list[index] = entry
    state.byPart[part] = { index = index, entry = entry }
    state.count += 1
    return true
end

function Cache.remove(state, part)
    if not state then return false end
    local record = state.byPart[part]
    if not record then return false end
    local lastIndex = #state.list
    local last = state.list[lastIndex]
    local index = record.index
    if index ~= lastIndex then
        state.list[index] = last
        state.byPart[last.part].index = index
    end
    state.list[lastIndex] = nil
    state.byPart[part] = nil
    state.count -= 1
    return true
end

function Cache.clear(state)
    state.list = {}
    state.byPart = {}
    state.count = 0
end

return Cache
