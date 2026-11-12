-- IRON YARD / pure bounded shutdown accounting for in-flight DataStore work.
-- No Roblox services, timers or instances. A count rather than a bool keeps
-- simultaneous PlayerRemoving, autosave, acquire and late release distinct.
local Tracker = {}

function Tracker.new()
    return {count = 0}
end

function Tracker.begin(state)
    assert(type(state) == "table" and type(state.count) == "number"
        and state.count >= 0 and state.count == math.floor(state.count),
        "Invalid progression shutdown tracker")
    state.count += 1
end

function Tracker.finish(state)
    assert(type(state) == "table" and type(state.count) == "number"
        and state.count > 0 and state.count == math.floor(state.count),
        "Unbalanced progression shutdown operation")
    state.count -= 1
end

function Tracker.hasPending(state)
    return type(state) == "table" and type(state.count) == "number"
        and state.count > 0
end

return Tracker
