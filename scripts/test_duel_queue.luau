local Queue = require("../src/shared/DuelQueue")

local order = { "A", "B", "C", "D", "E" }
local function check(entries, first, second, unavailable)
    local a, b = Queue.pair(entries, order, function(player)
        return player ~= unavailable
    end)
    assert(a == first and b == second,
        string.format("Expected %s/%s, got %s/%s", tostring(first), tostring(second), tostring(a), tostring(b)))
end

check({ A = {}, B = {}, C = {} }, "A", "B")
check({ A = {}, B = {}, C = {} }, "A", "C", "B")
check({ A = { target = "B" }, B = {}, C = {} }, "B", "C")
check({ A = { target = "B" }, B = { target = "A" }, C = {}, D = {} }, "A", "B")
check({ A = {}, B = {}, C = { target = "E" }, E = { target = "C" } }, "A", "B")
check({ A = { target = "B" }, B = { target = "C" }, C = { target = "A" } }, nil, nil)
check({ A = { target = "B" }, B = { target = "A" } }, nil, nil, "B")
check({ A = { target = "B" }, C = {}, D = {} }, "C", "D")
print("Duel queue: FIFO, reciprocal invites, stale roster and consent: OK")
