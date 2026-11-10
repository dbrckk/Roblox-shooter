-- IRON YARD / original first-person pistol and knife detailing.
-- Data-only, immutable after import; no Roblox services, objects or networking.
-- Tier 1: ECO, tier 2: balanced touch, tier 3: desktop/QUALITY.
local Plan = {}
local DETAILS = { Pistol = {}, Knife = {} }
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

for weapon, entries in pairs(DETAILS) do
    CACHE[weapon] = {}
    for tier = 1, 3 do
        local allowed = {}
        for _, part in ipairs(entries) do
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
