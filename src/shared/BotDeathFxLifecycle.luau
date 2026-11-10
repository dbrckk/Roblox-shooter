-- IRON YARD / pure, bounded bot visual death-event lifecycle.
-- A streamed-out model or a reset round invalidates its pending callback.
-- No timers, engine connections or Roblox Instance allocation here.
local Lifecycle = {}

function Lifecycle.new()
    return { byModel = {} }
end

function Lifecycle.track(state, model, container)
    if type(state) ~= "table" or type(state.byModel) ~= "table"
        or model == nil or container == nil or model.Parent ~= container
        or state.byModel[model] ~= nil then return nil end
    local entry = { active = true, deathQueued = false, connection = nil }
    state.byModel[model] = entry
    return entry
end

function Lifecycle.active(state, model, entry, container)
    return type(state) == "table" and type(state.byModel) == "table"
        and entry ~= nil and entry.active == true
        and state.byModel[model] == entry
        and model ~= nil and model.Parent == container
end

function Lifecycle.retire(state, model)
    if type(state) ~= "table" or type(state.byModel) ~= "table"
        then return nil end
    local entry = state.byModel[model]
    if entry then
        entry.active = false
        state.byModel[model] = nil
    end
    return entry
end

return Lifecycle
