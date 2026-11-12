-- Deterministic cosmetic-only weapon handling tests, no Roblox engine needed.
local Feel = require("../src/shared/WeaponFeelProfile")
local WeaponConfig = require("../src/shared/WeaponConfig")
local ids = { "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife" }

local durations = {}
local kicks = {}
for _, id in ipairs(ids) do
    local p = Feel.get(id)
    local config = WeaponConfig.get(id)
    assert(p and config, "Five valid presentation profiles")
    assert(p.kickCap > 0 and p.recovery > 0 and p.shotSeconds > 0)
    assert(p.reloadPitch == p.reloadPitch)
    local base = Feel.kick(id, 0, config.recoilKick)
    assert(base > 0 and base <= p.kickCap, id .. " first kick")
    local stacked = Feel.kick(id, base, config.recoilKick)
    assert(stacked >= base and stacked <= p.kickCap, id .. " recoil stays bounded")
    local settled = Feel.recover(id, stacked, 0.1)
    assert(settled > 0 and settled < stacked, id .. " smoothly recovers")
    assert(Feel.recover(id, stacked, 0) == stacked)
    assert(Feel.shotEnvelope(id, 0) == 1)
    assert(Feel.shotEnvelope(id, p.shotSeconds + 0.001) == 0)
    assert(Feel.shotEnvelope(id, p.shotSeconds / 2) > 0)
    durations[id] = p.shotSeconds
    kicks[id] = p.pitch
end

assert(durations.Shotgun > durations.AssaultRifle,
    "Heavy shotgun retains recoil longer than automatic rifle")
assert(durations.Sniper > durations.Pistol,
    "Sniper pose visibly persists longer than pistol")
assert(kicks.Knife < 0 and kicks.Shotgun > kicks.AssaultRifle,
    "Knife throw and shotgun are not generic rifle recoil")
assert(Feel.get("Unknown") == nil)
assert(Feel.kick("Unknown", 0, 0.5) == 0)
assert(Feel.recover("Shotgun", 0/0, 0.1) == 0)
assert(Feel.recover("Shotgun", 0.2, -1) == 0.2)
assert(Feel.shotEnvelope("Shotgun", math.huge) == 0)
assert(Feel.shotEnvelope("Shotgun", -1) == 0)
assert(Feel.mechanism("Shotgun", 0.39) == 1)
assert(Feel.mechanism("Shotgun", 0.01) == 0)
assert(Feel.mechanism("Sniper", 0.43) == 1)
assert(Feel.mechanism("Pistol", 0) == 1)
assert(Feel.mechanism("Pistol", 0.20) == 0)
assert(Feel.mechanism("Knife", 0.04) == 0)
print("IRON YARD differentiated recoil, reload poses and mechanisms for five weapons: OK")

-- Cosmetic recoil is time-based, not frame-count-based. Returning from
-- Android background must not preserve recoil from a shot minutes ago.
for _, id in ipairs(ids) do
    local p = Feel.get(id)
    local start = p.kickCap
    local function simulate(fps)
        local current = start
        for _ = 1, fps do
            current = Feel.recover(id, current, 1 / fps)
        end
        return current
    end
    local at30, at60, at120 = simulate(30), simulate(60), simulate(120)
    local expected = start * math.exp(-p.recovery)
    assert(math.abs(at30 - expected) < 1e-10)
    assert(math.abs(at60 - expected) < 1e-10)
    assert(math.abs(at120 - expected) < 1e-10)
    local afterPause = Feel.recover(id, start, 30)
    assert(afterPause < 1e-20, "A 30-second background hitch must clear recoil")
    assert(Feel.recover(id, start, math.huge) == 0)
    assert(Feel.recover(id, start, -math.huge) == 0)
    assert(Feel.recover(id, start, 0/0) == 0)
    assert(Feel.recover(id, start, 0.05) > 0)
end
print("IRON YARD cosmetic recoil: frame-rate independent and background-resume safe OK")
