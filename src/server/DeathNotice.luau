-- Presentation-only player defeat attribution, written after lethal server damage.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DeathNotice = {}

function DeathNotice.record(targetCharacter, attackerName, weaponId, headshot)
    if typeof(targetCharacter) ~= "Instance" or not targetCharacter:IsA("Model") then return end
    if not Players:GetPlayerFromCharacter(targetCharacter) then return end
    if typeof(attackerName) ~= "string" or typeof(weaponId) ~= "string" then return end

    targetCharacter:SetAttribute("IronYardDefeatAttacker", string.sub(attackerName, 1, 60))
    targetCharacter:SetAttribute("IronYardDefeatWeapon", string.sub(weaponId, 1, 40))
    targetCharacter:SetAttribute("IronYardDefeatHeadshot", headshot == true)
    targetCharacter:SetAttribute("IronYardDefeatAt", Workspace:GetServerTimeNow())
end

return DeathNotice
