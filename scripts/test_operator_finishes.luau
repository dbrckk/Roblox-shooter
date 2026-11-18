-- Real Luau tests for all operator finish unlock thresholds.
local F = require("../src/shared/OperatorFinishes")

local function equal(actual, expected, name)
    assert(actual == expected,
        name .. ": wanted " .. tostring(expected) .. ", received " .. tostring(actual))
end

equal(F.count(), 5, "Five distinct cosmetic career finishes")
equal(F.forLevel(0).name, "FIELD ISSUE", "Unranked fallback")
equal(F.forLevel(1).name, "FIELD ISSUE", "Rank 1")
equal(F.forLevel(2).name, "FIELD ISSUE", "Rank 2")
equal(F.forLevel(3).name, "DESERT PATROL", "Rank 3 unlock")
equal(F.forLevel(5).name, "DESERT PATROL", "Before rank 6")
equal(F.forLevel(6).name, "COLD STEEL", "Rank 6 unlock")
equal(F.forLevel(9).name, "COLD STEEL", "Before rank 10")
equal(F.forLevel(10).name, "FOUNDRY", "Rank 10 unlock")
equal(F.forLevel(14).name, "FOUNDRY", "Before rank 15")
equal(F.forLevel(15).name, "BLACK GRADE", "Rank 15 final unlock")
equal(F.forLevel(200).name, "BLACK GRADE", "Permanent max finish")
equal(F.forLevel(0/0).name, "FIELD ISSUE", "NaN safe default")
equal(F.forLevel(nil).name, "FIELD ISSUE", "Unset level safe default")

local expected = {3, 6, 10, 15}
local level = 1
for _, nextLevel in ipairs(expected) do
    local unlock = F.nextUnlock(level)
    assert(unlock and unlock.level == nextLevel, "Next unlock missing")
    level = nextLevel
end
equal(F.nextUnlock(15), nil, "No fake next unlock after final tier")
for _, threshold in ipairs(expected) do
    equal(F.earnedBetween(threshold - 1, threshold), F.forLevel(threshold), "New finish earned")
    equal(F.earnedBetween(threshold, threshold), nil, "Same rank never repeats a finish")
end
equal(F.earnedBetween(3, 5), nil, "Ranks in an existing finish are not unlocks")
equal(F.earnedBetween(15, 6), nil, "Lower rank does not emit an unlock")

for _, levelToCheck in ipairs({1, 3, 6, 10, 15}) do
    local finish = F.forLevel(levelToCheck)
    for _, field in ipairs({"accent", "metal", "fabric", "glove"}) do
        local values = finish[field]
        assert(type(values) == "table" and #values == 3,
            "Finish has no three-channel " .. field)
        for _, value in ipairs(values) do
            assert(value >= 0 and value <= 255 and value % 1 == 0,
                "Finish RGB channel out of range")
        end
    end
end

print("IRON YARD five earned operator finishes: tested all unlock thresholds")
