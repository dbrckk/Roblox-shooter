-- IRON YARD / pure, deterministic opposite-pad selection for 1v1 rounds.
-- The server checks physical cover without considering either combatant an obstacle.
local Plan = {}
Plan.YARD = "YARD"
Plan.SORTING = "SORTING"
Plan.PAIRS = {{1,4}, {2,3}, {5,8}, {6,7}, {9,10}, {11,12}}

-- Indices are shared with the spawn transaction and its preparation HUD.
-- Coordinates remain in studs and Y is the existing ground-level spawn height.
Plan.PADS = {
    { x = -144, z = 145, label = "WEST / OUTER YARD" },
    { x = 144, z = 145, label = "EAST / OUTER YARD" },
    { x = -144, z = -144, label = "WEST / APPROACH" },
    { x = 144, z = -144, label = "EAST / APPROACH" },
    { x = -70, z = 145, label = "WEST / WAREHOUSE SIDE" },
    { x = 70, z = 145, label = "EAST / WAREHOUSE SIDE" },
    { x = -70, z = -145, label = "WEST / FREIGHT LANE" },
    { x = 70, z = -145, label = "EAST / FREIGHT LANE" },
    { x = 0, z = 140, label = "CENTRAL / WAREHOUSE SIDE" },
    { x = 0, z = -142, label = "CENTRAL / FREIGHT LANE" },
    { x = -145, z = 16, label = "WEST / UNDER THE CATWALK" },
    { x = 145, z = 16, label = "EAST / UNDER THE CATWALK" },
}

-- Sorting Bay's collider layout and opposite pads share local coordinates.
-- Each pair mirrors through the centre of the hall.
Plan.SortingBay = {
    originX = -1940,
    halfWidth = 56,
    halfDepth = 78,
    height = 32,
    pads = {
        { x = -27, z = 62, label = "WEST DOCK" },
        { x = 27, z = -62, label = "EAST DOCK" },
        { x = 0, z = 65, label = "SOUTH GATE" },
        { x = 0, z = -65, label = "NORTH GATE" },
        { x = 28, z = 57, label = "SOUTH SERVICE LANE" },
        { x = -28, z = -57, label = "NORTH SERVICE LANE" },
    },
    pairs = {{1,2}, {3,4}, {5,6}},
    covers = {
        { name = "Sorting conveyor", x = 0, z = 0, w = 16, h = 9, d = 44, material = "freight_steel" },
        { name = "Loading stack", x = -26, z = 42, w = 12, h = 7, d = 8, material = "freight_steel" },
        { name = "Dispatch pallet", x = 26, z = 35, w = 11, h = 4.6, d = 8, material = "warehouse_steel" },
        { name = "Service cabinet", x = 22, z = -8, w = 8, h = 6, d = 9, material = "warehouse_steel" },
    },
}

function Plan.nextArena(previous, jobId)
    if previous == Plan.YARD then return Plan.SORTING end
    if previous == Plan.SORTING then return Plan.YARD end
    -- Roblox JobIds end in a hexadecimal digit. Alternate on subsequent
    -- series in this instance. An empty Studio JobId starts in Sorting Bay.
    local seed = type(jobId) == "string" and tonumber(string.sub(jobId, -1), 16)
    return seed and seed % 2 == 0 and Plan.YARD or Plan.SORTING
end

function Plan.arenaLabel(arena)
    return arena == Plan.SORTING and "SORTING BAY" or "FREIGHT YARD"
end

function Plan.padLabel(index, arena)
    if type(index) ~= "number" or index ~= index then return nil end
    local pads = arena == Plan.SORTING and Plan.SortingBay.pads or Plan.PADS
    local pad = pads[index]
    return pad and pad.label or nil
end

function Plan.select(clear, bout, arena)
    if type(clear) ~= "table" or type(bout) ~= "number"
        or bout ~= bout or bout == math.huge or bout == -math.huge
        or bout < 1 or bout % 1 ~= 0 then
        return nil
    end
    -- Two consecutive bouts share a pair and exchange the sides.
    -- Then rotate to the next pair so 1v1 play does not repeat the same
    -- sightlines for an entire series when all six pairs are available.
    -- Obstacles may change: scan every pair cyclically from the intended
    -- start and never commit a partially blocked pair.
    local pairs = arena == Plan.SORTING and Plan.SortingBay.pairs or Plan.PAIRS
    local count = #pairs
    if count == 0 then return nil end
    local startIndex = math.floor((bout - 1) / 2) % count + 1
    for offset = 0, count - 1 do
        local pair = pairs[(startIndex + offset - 1) % count + 1]
        local first, second = pair[1], pair[2]
        if clear[first] == true and clear[second] == true then
            if bout % 2 == 0 then return second, first end
            return first, second
        end
    end
    return nil
end


-- Each team has two distinct pads on the same end of the map. Swap ends
-- in the next bout, then rotate to the next clear layout.
local yardTeams = {{1,4,5,8}, {3,2,7,6}, {1,3,5,7}}
local sortingTeams = {{1,2,3,4}, {3,4,5,6}, {1,2,5,6}}

function Plan.selectTeams(clear, bout, arena)
    local layouts = arena == Plan.SORTING and sortingTeams or yardTeams
    local start = math.floor((bout - 1) / 2)
    for offset = 0, #layouts - 1 do
        local layout = layouts[(start + offset) % #layouts + 1]
        local a, b, c, d = table.unpack(layout)
        if clear[a] and clear[b] and clear[c] and clear[d] then
            if bout % 2 == 0 then return {b, a, d, c} end
            return {a, b, c, d}
        end
    end
    return nil
end

-- Validate both ORIGINAL Roblox Player objects and character generations
-- immediately before an opposite-pad commit. A respawned avatar or missing
-- rig invalidates the entire pair, never half-spawns one competitor.
-- Pure Luau: exercised without running Roblox physics in CI.
function Plan.canCommit(aPlayer, bPlayer, expectedA, expectedB, aReady, bReady)
    return aPlayer ~= nil and bPlayer ~= nil and aPlayer ~= bPlayer
        and expectedA ~= nil and expectedB ~= nil and expectedA ~= expectedB
        and aPlayer.Character == expectedA and bPlayer.Character == expectedB
        and aReady == true and bReady == true
end

return Plan
