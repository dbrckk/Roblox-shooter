-- IRON YARD / combat feedback only; never used to apply damage or score.
-- Both sender and local HUD use the same finite, bounded readout rules.
local Feedback = {}

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

function Feedback.actualDamage(before, after)
    if not finite(before) or not finite(after) or before <= 0 then
        return 0
    end
    local lost = math.max(0, before - math.max(0, after))
    if lost <= 0 then return 0 end
    -- Humanoid health can be fractional; never display zero for real damage.
    return math.clamp(math.max(1, math.floor(lost + 0.5)), 1, 9999)
end

function Feedback.readout(kind, damage, headshot)
    if kind == "Protected" then return "SPAWN SHIELD" end
    if kind ~= "Hit" or not finite(damage) or damage <= 0 then return nil end
    local rounded = math.clamp(math.max(1, math.floor(damage + 0.5)), 1, 9999)
    return (headshot and "HEADSHOT " or "") .. tostring(rounded) .. " DMG"
end

return Feedback
