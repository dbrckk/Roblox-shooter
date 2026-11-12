local P = require("../src/shared/VictoryAwardPolicy")
local a,b = {}, {}
assert(P.claim(a), "First server victory is valid")
for i=1,10000 do
    assert(not P.claim(a), "Repeated result cannot grant XP twice")
end
assert(P.claim(b), "Another participant's state is independent")
assert(not P.claim(b))
P.reset(a)
assert(P.claim(a), "Next round may award a fresh victory")
assert(not P.claim(a))
assert(not P.claim(nil))
assert(not P.claim("invalid"))
P.reset(nil)
P.reset("invalid")
local c = {}
for i=1,1000 do
    P.reset(c)
    assert(P.claim(c), "Each new round grants at most one victory")
    assert(not P.claim(c), "Duplicate finalization must be rejected")
end
print("IRON YARD victory award: 10000 repeated results and 1000 round resets are idempotent")
