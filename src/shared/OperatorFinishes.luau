-- IRON YARD / cosmetic-only rank progression with no developer products.
-- Thresholds are derived from authoritative lifetime XP on the server.
-- RGB triplets keep this module testable in standalone Luau (no Roblox APIs).
local OperatorFinishes = {}

local finishes = {
    {
        level = 1, name = "FIELD ISSUE",
        accent = {112, 127, 89}, metal = {94, 103, 98},
        fabric = {99, 112, 90}, glove = {42, 49, 46},
    },
    {
        level = 3, name = "DESERT PATROL",
        accent = {184, 158, 116}, metal = {137, 126, 111},
        fabric = {158, 143, 109}, glove = {63, 59, 53},
    },
    {
        level = 6, name = "COLD STEEL",
        accent = {133, 157, 167}, metal = {101, 118, 128},
        fabric = {97, 111, 125}, glove = {42, 50, 57},
    },
    {
        level = 10, name = "FOUNDRY",
        accent = {184, 113, 82}, metal = {137, 109, 92},
        fabric = {112, 90, 75}, glove = {56, 47, 44},
    },
    {
        level = 15, name = "BLACK GRADE",
        accent = {222, 177, 94}, metal = {66, 74, 73},
        fabric = {57, 65, 60}, glove = {31, 37, 35},
    },
}

function OperatorFinishes.forLevel(level)
    local value = type(level) == "number" and level == level
        and math.max(1, math.floor(level)) or 1
    local finish = finishes[1]
    for i = 2, #finishes do
        if value < finishes[i].level then break end
        finish = finishes[i]
    end
    return finish
end

function OperatorFinishes.nextUnlock(level)
    local value = type(level) == "number" and level == level
        and math.max(1, math.floor(level)) or 1
    for _, finish in ipairs(finishes) do
        if finish.level > value then return finish end
    end
    return nil
end

function OperatorFinishes.count()
    return #finishes
end

return OperatorFinishes
