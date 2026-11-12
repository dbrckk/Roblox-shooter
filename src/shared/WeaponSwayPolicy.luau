-- IRON YARD / platform-independent cosmetic first-person inertia.
-- Mouse users retain the established sensitivity. Android touch and gamepad
-- use bounded camera rotation when Roblox reports no physical mouse delta.
-- Never changes the actual camera, aiming, recoil, or server-authoritative hit.
local Policy = {}
local MAX_X = 0.04
local MAX_Y = 0.035
local MAX_FRAME_ANGLE = 0.35
local REFERENCE_FRAME_SECONDS = 1 / 60
-- Limit denominators for extremely fast/zero-duration mobile frames.
-- Normal 30/60/120 Hz samples remain strictly time-normalized.
local MIN_FRAME_SECONDS = 1 / 240

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function Policy.target(mouseX, mouseY, indirectInput, pitch, yaw, deltaTime)
    mouseX = finite(mouseX) and mouseX or 0
    mouseY = finite(mouseY) and mouseY or 0
    -- Mouse remains authoritative on hybrid touch+mouse hardware.
    if indirectInput == true and math.abs(mouseX) + math.abs(mouseY) < 0.01
        and finite(deltaTime) and deltaTime > 0 and deltaTime <= 0.12
        and finite(pitch) and finite(yaw)
        and math.abs(pitch) < MAX_FRAME_ANGLE
        and math.abs(yaw) < MAX_FRAME_ANGLE then
        -- Roblox reports camera angle PER FRAME. Convert it to the amount
        -- of rotation of a reference 60 Hz frame, so an identical angular
        -- velocity produces identical cosmetic inertia at 30/60/120 FPS.
        -- No change to actual camera, aim ray, server spread or firing.
        local normalizedFrame = REFERENCE_FRAME_SECONDS
            / math.max(deltaTime, MIN_FRAME_SECONDS)
        return math.clamp(-yaw * normalizedFrame * 0.65, -MAX_X, MAX_X),
            math.clamp(-pitch * normalizedFrame * 0.65, -MAX_Y, MAX_Y)
    end
    return math.clamp(-mouseX * 0.002, -MAX_X, MAX_X),
        math.clamp(-mouseY * 0.002, -MAX_Y, MAX_Y)
end

return Policy
