-- IRON YARD: server-only duel identity gate. No Roblox services needed.
local Gate = {}
local bout = nil
-- Local Roblox Studio testing uses negative UserIds; public IDs are positive.
local function validId(id)
    return type(id) == "number" and id == id and id ~= 0
        and math.abs(id) < math.huge and id % 1 == 0
end

function Gate.clear()
    bout = nil
end

function Gate.begin(a, b)
    Gate.clear()
    if a == nil or b == nil or a == b
        or not validId(a.UserId) or not validId(b.UserId)
        or a.UserId == b.UserId
        or not a.Character or not b.Character
        or a.Character == b.Character then return false end
    bout = {a = a, b = b, aChar = a.Character, bChar = b.Character}
    return true
end

function Gate.canFire(player, phase, mode, playerCount)
    if mode ~= "DUEL" then return true end
    if not bout or phase ~= "LIVE" or playerCount ~= 2
        or player == nil then return false end
    if player == bout.a then return player.Character == bout.aChar end
    if player == bout.b then return player.Character == bout.bChar end
    return false
end

function Gate.canDamage(attacker, target, model, phase, mode, playerCount)
    if not Gate.canFire(attacker, phase, mode, playerCount) then return false end
    if mode ~= "DUEL" then return true end
    return target ~= nil and model ~= nil and attacker ~= target
        and Gate.canFire(target, phase, mode, playerCount)
        and target.Character == model
end

return Gate
