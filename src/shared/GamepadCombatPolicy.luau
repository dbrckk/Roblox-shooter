-- IRON YARD / console and Android Bluetooth controller combat bindings.
-- Pure policy: the server still decides every shot, reload and movement action.
-- Roblox's native controller manages locomotion and right-stick camera aim.
local Policy = {}

local bindings = {
    ButtonR2 = "FIRE",
    ButtonL2 = "AIM",
    ButtonX = "RELOAD",
    ButtonY = "NEXT_WEAPON",
    ButtonL1 = "PREVIOUS_WEAPON",
    DPadRight = "NEXT_WEAPON",
    DPadLeft = "PREVIOUS_WEAPON",
    DPadUp = "RIFLE",
    DPadDown = "KNIFE",
    ButtonR1 = "THROW_KNIFE",
    ButtonB = "SLIDE",
    ButtonL3 = "SPRINT",
    ButtonA = "JUMP",
    ButtonStart = "SETTINGS",
}

function Policy.action(keyName)
    return type(keyName) == "string" and bindings[keyName] or nil
end

function Policy.isGamepad(inputTypeName)
    return type(inputTypeName) == "string"
        and string.match(inputTypeName, "^Gamepad[1-8]$") ~= nil
end

-- WeaponConfig.Order is the single authoritative slot order. No
-- duplicated client-side list that can go stale as an arsenal evolves.
function Policy.cycle(order, current, direction)
    if type(order) ~= "table" or #order == 0
        or (direction ~= 1 and direction ~= -1) then
        return nil
    end
    for i, weaponId in ipairs(order) do
        if weaponId == current then
            return order[(i - 1 + direction + #order) % #order + 1]
        end
    end
    return order[1]
end

return Policy
