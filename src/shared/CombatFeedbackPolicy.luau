-- IRON YARD / combat feedback only; never used to apply damage or score.
-- Both sender and local HUD use the same finite, bounded readout rules.
local Feedback = {}

local MARKERS = {
    { offset = 9, length = 9, thickness = 2, tint = { 247, 244, 235 },
        duration = 0.16, pitch = 0.94, volume = 0.11 },
    { offset = 10, length = 11, thickness = 2, tint = { 255, 227, 154 },
        duration = 0.22, pitch = 1.27, volume = 0.16 },
    { offset = 11, length = 12, thickness = 3, tint = { 247, 189, 105 },
        duration = 0.35, pitch = 0.76, volume = 0.22 },
}

function Feedback.markerStyle(priority)
    return MARKERS[priority]
end

function Feedback.soundVolume(style, level)
    if level == 1 then return 0 end
    if level == 2 then return style.volume * 0.5 end
    return style.volume
end

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

function Feedback.readout(kind, damage, headshot, pelletsHit, pelletCount)
    if kind == "Protected" then return "SPAWN SHIELD" end
    if kind ~= "Hit" or not finite(damage) or damage <= 0 then return nil end
    local rounded = math.clamp(math.max(1, math.floor(damage + 0.5)), 1, 9999)
    local text = (headshot and "HEADSHOT " or "") .. tostring(rounded) .. " DMG"
    if finite(pelletsHit) and finite(pelletCount) and pelletsHit % 1 == 0
        and pelletCount % 1 == 0 and pelletsHit >= 1 and pelletsHit <= pelletCount and pelletCount <= 16 then
        return string.format("%s · %d/%d HITS", text, pelletsHit, pelletCount)
    end
    return text
end

return Feedback
