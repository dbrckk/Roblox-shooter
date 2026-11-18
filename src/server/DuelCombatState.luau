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

function Gate.begin(a, b, aPartner, bPartner)
    Gate.clear()
    if (aPartner == nil) ~= (bPartner == nil) then return false end
    local players = {a, b, aPartner, bPartner}
    local count = aPartner and 4 or 2
    local members, ids, characters = {}, {}, {}
    for index = 1, count do
        local player = players[index]
        local id = player and player.UserId
        local character = player and player.Character
        if not validId(id) or ids[id] or not character or characters[character] then return false end
        ids[id] = true
        characters[character] = true
        members[player] = { character = character, side = index % 2 }
    end
    bout = {members = members, count = count}
    return true
end

function Gate.canFire(player, phase, mode, playerCount)
    if mode ~= "DUEL" then return true end
    if not bout or phase ~= "LIVE" or playerCount ~= bout.count then return false end
    local entry = bout.members[player]
    return entry ~= nil and player.Character == entry.character
end

function Gate.canDamage(attacker, target, model, phase, mode, playerCount)
    if not Gate.canFire(attacker, phase, mode, playerCount) then return false end
    if mode ~= "DUEL" then return true end
    return model ~= nil and Gate.canFire(target, phase, mode, playerCount)
        and target.Character == model and bout.members[attacker].side ~= bout.members[target].side
end

return Gate
