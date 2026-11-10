local Scope = require("../src/shared/ScopeFovPolicy")
local Weapons = require("../src/shared/WeaponConfig")
assert(Scope.fieldOfView(70, false, Weapons.get("Sniper")) == 70)
assert(Scope.fieldOfView(70, true, Weapons.get("Sniper")) == 32)
assert(Scope.fieldOfView(70, true, Weapons.get("AssaultRifle")) == 58)
assert(Scope.fieldOfView(70, true, Weapons.get("Pistol")) == 62)
assert(Scope.fieldOfView(70, true, Weapons.get("Shotgun")) == 62)
assert(Scope.fieldOfView(82, false, Weapons.get("Sniper")) == 82)
assert(Scope.fieldOfView(82, true, Weapons.get("Sniper")) == 32)
assert(Scope.fieldOfView(70, true, Weapons.get("Knife")) == 70)
assert(Scope.fieldOfView(70, true, nil) == 70)
assert(Scope.fieldOfView(0/0, false, nil) == 70)
assert(Scope.fieldOfView(math.huge, false, nil) == 70)
assert(Scope.fieldOfView(160, false, nil) == 110)
assert(Scope.fieldOfView(10, false, nil) == 40)
assert(Scope.fieldOfView(70, true, {aimFov = math.huge}) == 70)
assert(Scope.fieldOfView(70, true, {aimFov = 200}) == 70)
assert(Scope.fieldOfView(70, true, {aimFov = -1}) == 70)
local sequence = {false, true, true, false, true, false}
for _, scoped in ipairs(sequence) do
    local expected = scoped and 32 or 70
    for _ = 1, 2000 do
        assert(Scope.fieldOfView(70, scoped, Weapons.get("Sniper")) == expected,
            "Repeated camera rebind must converge to current ADS state")
    end
end
print("IRON YARD scoped FOV resilience: respawn, swaps, camera replacement, invalid input: OK")
