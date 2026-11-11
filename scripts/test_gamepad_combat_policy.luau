local P = require("../src/shared/GamepadCombatPolicy")
local expected = {
    ButtonR2="FIRE", ButtonL2="AIM", ButtonX="RELOAD",
    ButtonY="NEXT_WEAPON", ButtonL1="PREVIOUS_WEAPON",
    DPadRight="NEXT_WEAPON", DPadLeft="PREVIOUS_WEAPON",
    DPadUp="RIFLE", DPadDown="KNIFE",
    ButtonR1="THROW_KNIFE", ButtonB="SLIDE",
    ButtonL3="SPRINT", ButtonA="JUMP",
    ButtonStart="SETTINGS",
}
for button, action in pairs(expected) do
    assert(P.action(button) == action, "Gamepad mapping: "..button)
end
for _, invalid in ipairs({"ButtonR3", "Thumbstick1", "MouseButton1", "", "W"}) do
    assert(P.action(invalid) == nil)
end
assert(P.action(nil) == nil and P.action(1) == nil)
for i = 1, 8 do
    assert(P.isGamepad("Gamepad"..i), "Roblox controller #"..i)
end
for _, name in ipairs({"Gamepad0", "Gamepad9", "Gamepad10", "Keyboard", "MouseButton1",
    "Touch", "", "FakeGamepad1", "Gamepad1Extra"}) do
    assert(not P.isGamepad(name), "Reject fake controller: "..name)
end
assert(not P.isGamepad(nil))
local slots = {"AssaultRifle","Pistol","Shotgun","Sniper","Knife"}
for i, weapon in ipairs(slots) do
    assert(P.cycle(slots, weapon, 1) == slots[i % #slots + 1])
    assert(P.cycle(slots, weapon, -1) == slots[(i-2 + #slots) % #slots + 1])
end
assert(P.cycle(slots, "Unknown", 1) == "AssaultRifle")
assert(P.cycle(slots, "Unknown", -1) == "AssaultRifle")
assert(P.cycle(slots, "Pistol", 0) == nil)
assert(P.cycle(nil, "Pistol", 1) == nil)
assert(P.cycle({}, "Pistol", 1) == nil)
print("IRON YARD controller mapping / five-slot wraparound / native input typing: OK")
