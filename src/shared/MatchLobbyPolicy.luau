-- IRON YARD / pure empty-roster lifecycle gate.
-- A public FFA and a completed/active 1v1 must both reset to WAITING/FFA
-- when the LAST player leaves. Never preserve a stale duel scoreboard or
-- match mode for the next joining player.
local Policy = {}

function Policy.shouldReset(rosterCount, phase, mode, hasDuel)
    if type(rosterCount) ~= "number" or rosterCount ~= rosterCount
        or rosterCount < 0 or rosterCount == math.huge
        or rosterCount % 1 ~= 0 then return false end
    return rosterCount == 0 and
        (phase ~= "WAITING" or mode ~= "FFA" or hasDuel == true)
end

return Policy
