-- Server-side idempotency for round victory rewards.
-- Keep the guard in the per-player round state, never in client attributes.
local Policy = {}

function Policy.claim(state)
    if type(state) ~= "table" or state.victoryGranted == true then
        return false
    end
    state.victoryGranted = true
    return true
end

function Policy.reset(state)
    if type(state) ~= "table" then return end
    state.victoryGranted = false
end

return Policy
