-- IRON YARD / original first-person pistol and knife detailing.
-- Data-only, immutable after import; no Roblox services, objects or networking.
-- Tier 1: ECO, tier 2: balanced touch, tier 3: desktop/QUALITY.
local Plan = {}
local DETAILS = { Pistol = {}, Knife = {}, AssaultRifle = {}, Shotgun = {}, Sniper = {} }
local CACHE = {}

local function add(weapon, name, tier, position, size, color, finish, shape, angles)
    table.insert(DETAILS[weapon], {
        name = name, tier = tier, position = position, size = size,
        color = color, finish = finish, shape = shape or "Block",
        angles = angles or {0, 0, 0},
    })
end

-- Sidearm: a complete rear grip, rounded muzzle ring and structural rail.
add("Pistol", "PistolGripRight", 1, {0.137,-0.30,0.07}, {0.027,0.46,0.18},
    {54,61,62}, "accent", "Block", {-14,0,0})
add("Pistol", "PistolMuzzleBushing", 1, {0,0.16,-1.11}, {0.19,0.04,0.19},
    {121,128,127}, "panel", "Cylinder", {90,0,0})
add("Pistol", "PistolDustCover", 1, {0,-0.11,-0.49}, {0.27,0.07,0.34},
    {43,48,49}, "panel")
add("Pistol", "PistolTriggerSafety", 1, {0,-0.23,-0.22}, {0.045,0.18,0.08},
    {146,153,149}, "accent", "Block", {12,0,0})

-- Rear slide serrations travel with the actual slide and extractor.
for i = 1, 2 do
    local z = 0.045 - (i-1)*0.11
    for _, side in ipairs({-1, 1}) do
        add("Pistol", "SlideDetailRear" .. i .. (side < 0 and "L" or "R"),
            2, {side*0.225,0.17,z}, {0.014,0.135,0.038},
            {37,42,43}, "dark", "Block", {0,0,12})
    end
end
add("Pistol", "PistolGripScrewFront", 2, {0.166,-0.20,0.08}, {0.048,0.048,0.048},
    {162,165,150}, "panel", "Ball")
add("Pistol", "PistolGripScrewRear", 2, {0.166,-0.47,0.13}, {0.048,0.048,0.048},
    {162,165,150}, "panel", "Ball")

-- Front slide serrations and a subdued chamber-indicator notch on QUALITY.
for i = 1, 2 do
    for _, side in ipairs({-1, 1}) do
        add("Pistol", "SlideDetailFront" .. i .. (side < 0 and "L" or "R"),
            3, {side*0.226,0.17,-0.48-(i-1)*0.10},
            {0.014,0.115,0.03}, {39,46,45}, "dark")
    end
end
add("Pistol", "SlideDetailChamberIndicator", 3, {0.12,0.274,-0.47},
    {0.095,0.015,0.055}, {151,113,80}, "accent")

-- Knife: a more recognizable full-tang tool with shaped furniture.
add("Knife", "KnifePommel", 1, {0,-0.04,0.54}, {0.235,0.235,0.08},
    {99,108,104}, "panel")
add("Knife", "KnifeGripInlayLeft", 1, {-0.113,-0.04,0.13}, {0.026,0.115,0.48},
    {71,82,69}, "accent")
add("Knife", "KnifeGripInlayRight", 1, {0.113,-0.04,0.13}, {0.026,0.115,0.48},
    {71,82,69}, "accent")
add("Knife", "KnifeGuardPommelLeft", 1, {-0.255,0,-0.18},
    {0.11,0.10,0.115}, {90,97,91}, "panel", "Ball")
for _, side in ipairs({-1,1}) do
    for i = 1, 2 do
        add("Knife", "KnifeHandlePin" .. i .. (side<0 and "L" or "R"),
            2, {side*0.14,-0.012,0.02+(i-1)*0.25},
            {0.045,0.045,0.045}, {184,184,167}, "panel", "Ball")
    end
end
add("Knife", "KnifeBladeFuller", 2, {-0.075,0.076,-0.63}, {0.065,0.012,0.52},
    {105,116,117}, "panel")
for i = 1, 3 do
    add("Knife", "KnifeSpineSerration" .. i, 3,
        {0,0.11,-0.28-(i-1)*0.10}, {0.165,0.037,0.035},
        {137,148,143}, "panel")
end
add("Knife", "KnifeLanyardSocket", 3, {0,-0.04,0.591},
    {0.085,0.085,0.02}, {21,27,28}, "dark", "Cylinder", {90,0,0})
add("Knife", "KnifeGuardPommelRight", 3, {0.255,0,-0.18},
    {0.11,0.10,0.115}, {90,97,91}, "panel", "Ball")


-- Long guns share the same immutable tier policy as sidearms.  Tier 1 adds
-- ZERO parts: ECO retains the existing silhouettes on lower-end Android.
-- These fittings stay on static receiver/stock/barrel surfaces, never on the
-- shotgun pump, sniper bolt or rifle charging handle (animated separately).
for _, side in ipairs({-1,1}) do
    local tag=side<0 and "L" or "R"
    add("AssaultRifle","ARReceiverInset"..tag,2,{side*0.223,-0.09,-0.34},
        {0.018,0.11,0.33},{25,31,31},"dark")
    add("AssaultRifle","ARHandguardFastener"..tag,2,
        {side*0.265,0.06,-1.24},{0.038,0.038,0.038},
        {139,143,131},"panel","Ball")
end
add("AssaultRifle","ARStockHinge",2,{0.19,-0.02,0.77},
    {0.075,0.20,0.14},{74,81,70},"panel")
add("AssaultRifle","ARMagazineFollower",2,{0,-0.18,-0.49},
    {0.31,0.045,0.24},{122,126,107},"accent")
for _, side in ipairs({-1,1}) do
    local tag=side<0 and "L" or "R"
    for i=1,2 do
        add("AssaultRifle","ARReceiverPin"..tag..i,3,
            {side*0.235,0.06,0.07-(i-1)*0.44},
            {0.039,0.039,0.039},{171,171,153},"panel","Ball")
    end
    add("AssaultRifle","ARStockReinforcement"..tag,3,
        {side*0.174,0.03,0.60},{0.018,0.09,0.35},
        {76,87,77},"accent")
end

for _, side in ipairs({-1,1}) do
    local tag=side<0 and "L" or "R"
    add("Shotgun","B8ReceiverFlute"..tag,2,
        {side*0.259,0.075,-0.05},{0.014,0.065,0.34},
        {32,38,38},"dark")
    add("Shotgun","B8StockTrim"..tag,3,
        {side*0.19,-0.02,0.92},{0.018,0.09,0.41},
        {143,134,111},"accent")
    for i=1,2 do
        add("Shotgun","B8ReceiverPin"..tag..i,3,
            {side*0.26,-0.04,0.06-(i-1)*0.30},
            {0.038,0.038,0.038},{160,158,142},"panel","Ball")
    end
end
add("Shotgun","B8BarrelCollar",2,{0,0.10,-2.03},
    {0.29,0.048,0.29},{83,89,85},"panel","Cylinder",{90,0,0})
add("Shotgun","B8StockSlingEye",2,{0.19,-0.11,1.04},
    {0.068,0.14,0.075},{127,131,116},"panel")
add("Shotgun","B8MagazineSupport",2,{0,-0.18,-2.03},
    {0.27,0.10,0.11},{79,84,79},"accent")

for _, side in ipairs({-1,1}) do
    local tag=side<0 and "L" or "R"
    add("Sniper","SniperCheekInlay"..tag,2,
        {side*0.183,0.16,0.51},{0.02,0.08,0.35},
        {65,70,68},"accent")
    add("Sniper","SniperStockRivet"..tag,3,
        {side*0.185,0.16,0.60},{0.042,0.042,0.042},
        {155,159,153},"panel","Ball")
    add("Sniper","SniperRailRib"..tag,3,
        {side*0.216,-0.105,-0.88},{0.022,0.07,0.42},
        {74,78,76},"panel")
end
for i=1,2 do
    add("Sniper","SniperOpticMount"..i,2,
        {0,0.205,-0.63+(i-1)*0.47},
        {0.20,0.11,0.10},{100,106,102},"panel")
end
add("Sniper","SniperBipodSaddle",2,{0,-0.22,-1.44},
    {0.25,0.12,0.18},{73,79,75},"panel")
add("Sniper","SniperTurretWitness",3,{0,0.696,-0.37},
    {0.13,0.01,0.13},{182,171,126},"accent","Cylinder")
add("Sniper","SniperBoltStop",3,{0.22,-0.03,-0.51},
    {0.065,0.09,0.12},{142,147,146},"panel")

for weapon, entries in pairs(DETAILS) do
    -- Plans are authored by surface grouping, which can interleave tiers.
    -- Reorder ONCE at module initialization so higher quality is a strict
    -- superset with the same object identity as each lower tier.
    local ordered = {}
    for detailTier = 1, 3 do
        for _, part in ipairs(entries) do
            if part.tier == detailTier then
                table.insert(ordered, part)
            end
        end
    end
    CACHE[weapon] = {}
    for tier = 1, 3 do
        local allowed = {}
        for _, part in ipairs(ordered) do
            if part.tier <= tier then table.insert(allowed, part) end
        end
        CACHE[weapon][tier] = allowed
    end
end

function Plan.tier(preset, touch)
    if preset == "ECO" then return 1 end
    if touch == true and preset ~= "QUALITY" then return 2 end
    return 3
end

-- Cached arrays are returned, never constructed during a frame update.
function Plan.get(weapon, preset, touch)
    local tiers = CACHE[weapon]
    return tiers and tiers[Plan.tier(preset, touch)] or nil
end

return Plan
