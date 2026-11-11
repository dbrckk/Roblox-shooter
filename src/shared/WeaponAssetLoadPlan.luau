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
