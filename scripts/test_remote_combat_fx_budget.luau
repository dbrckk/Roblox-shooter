-- IRON YARD / deterministic mobile performance admissions without Roblox.
local Budget = require("../src/shared/RemoteCombatFxBudget")

local function simulate(preset, touch, kind, count, duration, distance)
    local state = Budget.new()
    local approved = 0
    for n = 0, count - 1 do
        if Budget.allow(state, n * duration / count, preset, touch,
            distance, kind) then approved += 1 end
    end
    return approved, state
end

local function bounds(preset, touch, kind, distance)
    local limits = Budget.limits(preset, touch, kind)
    local count, _ = simulate(preset, touch, kind, 1000, 1, distance)
    assert(count <= limits.burst + limits.rate,
        "Remote visual groups must obey strict burst + one-second rate")
    assert(count >= limits.rate - 2,
        "Do not suppress every shot during sustained combat")
end

for _, config in ipairs({
    {"ECO", true, "PLAYER", 50},
    {"ECO", true, "BOT", 50},
    {"BALANCED", true, "PLAYER", 80},
    {"BALANCED", true, "BOT", 80},
    {"QUALITY", true, "PLAYER", 100},
    {"QUALITY", true, "BOT", 100},
    {"BALANCED", false, "PLAYER", 140},
    {"BALANCED", false, "BOT", 140},
    {"QUALITY", false, "PLAYER", 185},
    {"QUALITY", false, "BOT", 185},
}) do bounds(config[1], config[2], config[3], config[4]) end

local mobileCount = simulate("BALANCED", true, "BOT", 1000, 1, 40)
assert(mobileCount <= 10 and mobileCount >= 6,
    "Four-bot sustained mobile group allocation is genuinely bounded")
local ecoCount = simulate("ECO", true, "BOT", 1000, 1, 40)
assert(ecoCount <= 6 and ecoCount < mobileCount,
    "ECO visibly reduces bot FX versus balanced Android")

local playerAndBot = Budget.new()
local acceptedBot = 0
for n = 1, 200 do
    if Budget.allow(playerAndBot, 0, "ECO", true, 40, "BOT") then
        acceptedBot += 1
    end
end
assert(acceptedBot == 2, "Bot burst must stop immediately")
assert(Budget.allow(playerAndBot, 0, "ECO", true, 40, "PLAYER"),
    "Crowded bots must never starve human remote shot feedback")
assert(Budget.allow(playerAndBot, 0, "ECO", true, 40, "PLAYER"),
    "Second human remote shot fits separate burst")
assert(not Budget.allow(playerAndBot, 0, "ECO", true, 40, "PLAYER"),
    "Human bursts also have a ceiling")
assert(Budget.allow(playerAndBot, 0.26, "ECO", true, 40, "BOT"),
    "Idle time refills bot tokens")
assert(not Budget.allow(playerAndBot, 0.20, "ECO", true, 40, "BOT"),
    "Backwards timestamps cannot bypass rate limits")

local never = Budget.new()
for _, d in ipairs({-1, math.huge, 0/0, 99999}) do
    assert(not Budget.allow(never, 1, "ECO", true, d, "BOT"),
        "Invalid/out-of-range distance must not allocate effects")
end
assert(not Budget.allow(never, 0/0, "ECO", true, 40, "BOT"), "NaN time")
assert(not Budget.allow(never, -1, "ECO", true, 40, "BOT"), "Negative time")
assert(not Budget.allow(never, math.huge, "ECO", true, 40, "BOT"), "Inf time")
assert(not Budget.allow(never, 1, "ECO", true, 40, "OTHER"), "Invalid kind")
assert(not Budget.allow(nil, 1, "ECO", true, 40, "BOT"), "Invalid state")
assert(next(never) == nil, "Rejected messages do not allocate bucket state")
assert(not Budget.allow(Budget.new(), 1, "ECO", true, 71, "PLAYER"),
    "Never override existing strict ECO distance culling")
assert(not Budget.allow(Budget.new(), 1, "BALANCED", true, 116, "PLAYER"),
    "Never override existing Android distance culling")
assert(Budget.allow(Budget.new(), 1, "BALANCED", true, 115, "PLAYER"),
    "Shots exactly at range limit remain eligible")

local high = Budget.new()
for _ = 1, 500 do
    Budget.allow(high, 1, "QUALITY", false, 30, "BOT")
    Budget.allow(high, 1, "QUALITY", false, 30, "PLAYER")
end
assert(high.BOT.tokens >= 0 and high.PLAYER.tokens >= 0)
local used=0
for _ in pairs(high) do used += 1 end
assert(used == 2, "Fixed memory regardless of total bot fire events")
print("IRON YARD 4-bot mobile FX caps, local priority and distance admission: OK")
