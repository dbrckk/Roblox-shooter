-- IRON YARD: audio evidence for AI investigation, never for target acquisition.
-- Pure Luau: no engine, network or physics dependencies.
local Hearing = {}
Hearing.LIFETIME = 5.4
Hearing.MAX_EVENTS = 12
Hearing.MIN_INVESTIGATION_DISTANCE = 8
Hearing.GOAL_HOLD_SECONDS = 1.8

local RADII = {
    AssaultRifle = 110,
    Pistol = 65,
    Shotgun = 125,
    Sniper = 155,
    Knife = 24,
}
local function finite(n)
    return type(n) == "number" and n == n
        and n < math.huge and n > -math.huge
end

function Hearing.radius(weaponId)
    return RADII[weaponId]
end

function Hearing.choose(entries, now, afterId)
    if not finite(now) then return nil end
    local best, bestScore = nil, math.huge
    for _, sound in ipairs(entries) do
        local distance, age, radius = sound.distance, sound.age, sound.radius
        if sound.id ~= nil and sound.own ~= true
            and (afterId == nil or (type(sound.id) == "number"
                and sound.id > afterId))
            and finite(distance) and distance >= Hearing.MIN_INVESTIGATION_DISTANCE
            and finite(age) and age >= 0 and age <= Hearing.LIFETIME
            and finite(radius) and distance <= radius then
            -- Prefer a nearby recently heard event; never reveal a humanoid
            -- or enable firing, only select a coarse investigation area.
            local score = distance * 0.35 + age * 10
            if score < bestScore then
                best, bestScore = sound.id, score
            end
        end
    end
    return best
end

function Hearing.approximateAxis(value, slot, axis)
    if not finite(value) then return nil end
    local index = math.floor(tonumber(slot) or 1)
    local salt = axis == "Z" and index * 2 or index
    local offset = ((salt % 3) - 1) * 3
    return math.clamp(math.floor(value / 12 + 0.5) * 12 + offset, -153, 153)
end

return Hearing
