-- IRON YARD / purely deterministic invalidation for server terrain probes.
-- The filter contains server-owned Instance references, never positions.
local Policy = {}

function Policy.new()
    return { generation = 0 }
end

function Policy.invalidate(state)
    state.generation += 1
    return state.generation
end

-- Keep the same RaycastParams object until the observed Player/Character
-- roster, bot model, or bot folder changes. A changed folder must invalidate
-- immediately even when no Player event fired during an arena rebuild.
function Policy.stale(params, lastGeneration, generation,
    lastModel, model, lastFolder, folder)
    return params == nil or lastGeneration ~= generation
        or lastModel ~= model or lastFolder ~= folder
end

return Policy
