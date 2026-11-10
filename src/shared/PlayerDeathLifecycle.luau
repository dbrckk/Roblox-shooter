-- IRON YARD / authoritative death counting across asynchronous respawns.
-- Pure Luau: timestamps, engine events and score mutation stay server owned.
local Lifecycle = {}

function Lifecycle.new()
    return { generation = 0, character = nil, humanoid = nil, recorded = false }
end

function Lifecycle.bind(state, character)
    if type(state) ~= "table" or character == nil then return nil end
    state.generation += 1
    state.character = character
    state.humanoid = nil
    state.recorded = false
    return state.generation
end

function Lifecycle.retire(state, character)
    if type(state) ~= "table" or state.character ~= character then return false end
    state.generation += 1
    state.character = nil
    state.humanoid = nil
    state.recorded = false
    return true
end

function Lifecycle.bindHumanoid(state, token, character, humanoid, currentCharacter)
    if type(state) ~= "table" or token ~= state.generation
        or character == nil or humanoid == nil or state.character ~= character
        or currentCharacter ~= character then return false end
    state.humanoid = humanoid
    return true
end

-- A client can never send these arguments. This is called only from the
-- server's Humanoid.Died signal, after checking the live match phase.
function Lifecycle.recordDeath(state, token, character, humanoid, currentCharacter, live)
    if type(state) ~= "table" or state.recorded
        or token ~= state.generation or state.character ~= character
        or state.humanoid ~= humanoid or currentCharacter ~= character
        or live ~= true then return false end
    state.recorded = true
    return true
end

return Lifecycle
