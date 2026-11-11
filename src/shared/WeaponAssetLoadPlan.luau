-- IRON YARD / bounded server-side PBR model loading and health status.
-- Roblox AssetService requests yield. Never flood the owner model API;
-- never let a rejected model stall a playable procedural viewmodel.
local Plan = {}
Plan.MAX_WORKERS = 2
Plan.TOTAL_WEAPONS = 5

function Plan.workers(pending)
    if type(pending) ~= "number" or pending ~= pending or pending <= 0 then
        return 0
    end
    return math.min(math.floor(pending), Plan.MAX_WORKERS)
end

-- Queue only complete authorized LOD pairs not already installed.
-- Incomplete legacy/manual templates must be replaceable after verifying a
-- full owner-owned replacement pair, never simply skipped by name.
function Plan.queue(weapons, pairFor, isComplete)
    local queue = {}
    if type(weapons) ~= "table" or type(pairFor) ~= "function"
        or type(isComplete) ~= "function" then return queue end
    for _, weaponId in ipairs(weapons) do
        local pair = pairFor(weaponId)
        if pair ~= nil and isComplete(weaponId) ~= true then
            table.insert(queue, { weaponId = weaponId, ids = pair })
        end
    end
    return queue
end

function Plan.status(ready, pending, authorized)
    if type(ready) ~= "number" or type(pending) ~= "number"
        or ready ~= ready or pending ~= pending then return "FALLBACK" end
    ready = math.clamp(math.floor(ready), 0, Plan.TOTAL_WEAPONS)
    pending = math.max(math.floor(pending), 0)
    if ready == Plan.TOTAL_WEAPONS then return "READY" end
    if pending > 0 then return "LOADING" end
    if ready > 0 then
        return authorized == true and "PARTIAL" or "MANUAL"
    end
    return authorized == true and "FALLBACK" or "DISABLED"
end

return Plan
