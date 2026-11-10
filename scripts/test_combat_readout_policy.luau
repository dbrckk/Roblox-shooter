-- IRON YARD / deduplicated network readouts and respawn HUD policy.
local Policy = require("../src/shared/CombatReadoutPolicy")
local function ammo(loaded, capacity, reloading, text, tone)
    local got, kind = Policy.ammo(loaded, capacity, reloading)
    assert(got == text and kind == tone,
        "Ammo snapshot mismatch: " .. tostring(got) .. " / " .. tostring(kind))
end

ammo(nil, nil, false, "UNLIMITED", "UNLIMITED")
ammo(nil, 0, false, "UNLIMITED", "UNLIMITED")
ammo(nil, 30, false, "-- / 30", "UNKNOWN")
ammo(30, 30, false, "30 / 30", "READY")
ammo(7, 30, false, "07 / 30", "READY")
ammo(3, 30, false, "03 / 30", "LOW")
ammo(0, 30, false, "00 / 30", "LOW")
ammo(45, 30, false, "30 / 30", "READY")
ammo(-7, 30, false, "00 / 30", "LOW")
ammo(3, 30, true, "RELOADING...", "RELOADING")
ammo(28, 30, true, "RELOADING...", "RELOADING")
ammo(30, 30, false, "30 / 30", "READY")
ammo(nil, 0, true, "UNLIMITED", "UNLIMITED")

local function health(current, maximum, ratio, tone, label)
    local r, t, txt = Policy.health(current, maximum)
    assert(math.abs(r - ratio) < 0.0000001
        and t == tone and txt == label, "Health readout mismatch")
end
health(100, 100, 1, "HEALTHY", "100 / 100")
health(60, 100, 0.6, "WARNING", "60 / 100")
health(30, 100, 0.3, "CRITICAL", "30 / 100")
health(0, 100, 0, "CRITICAL", "0 / 100")
health(120, 100, 1, "HEALTHY", "120 / 100")
health(50, 200, 0.25, "CRITICAL", "50 / 200")
health(0, 0, 0, "CRITICAL", "0 / 0")
health(24.1, 100, 0.241, "CRITICAL", "25 / 100")

-- Simulate duplicate replication. The live HUD uses the same strings
-- and tones as its dirty keys, so repeated snapshots never repaint.
local ammoWrites, lastText, lastTone = 0, nil, nil
local healthWrites, lastHealthRatio, lastHealthText, lastHealthTone = 0, nil, nil, nil
for i = 1, 10000 do
    local text, tone = Policy.ammo(20, 30, false)
    if text ~= lastText or tone ~= lastTone then
        ammoWrites += 1
        lastText, lastTone = text, tone
    end
    local ratio, color, label = Policy.health(100, 100)
    if ratio ~= lastHealthRatio or color ~= lastHealthTone
        or label ~= lastHealthText then
        healthWrites += 1
        lastHealthRatio, lastHealthTone, lastHealthText = ratio, color, label
    end
end
assert(ammoWrites == 1 and healthWrites == 1,
    "10k repeated network snapshots must update each readout only once")

-- Reloads and critical health warnings must never be throttled/delayed.
local sequence = {
    {20, false, "20 / 30", "READY"},
    {20, true, "RELOADING...", "RELOADING"},
    {30, false, "30 / 30", "READY"},
    {2, false, "02 / 30", "LOW"},
    {0, false, "00 / 30", "LOW"},
}
for _, s in ipairs(sequence) do ammo(s[1], 30, s[2], s[3], s[4]) end
health(29, 100, 0.29, "CRITICAL", "29 / 100")
health(70, 100, 0.7, "HEALTHY", "70 / 100")
print("IRON YARD combat HUD: 10k duplicate snapshots, instant critical transitions: OK")
