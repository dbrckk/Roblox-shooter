local P = require("../src/shared/FireEpochPolicy")
assert(P.valid(0) and P.valid(1) and P.valid(1024))
for _, wrong in ipairs({-1, 1.5, math.huge, -math.huge, 0/0, "1", true}) do
    assert(not P.valid(wrong))
    assert(not P.matches(wrong, 1))
    assert(not P.acceptAmmo(wrong, 1, 1))
end
assert(not P.matches(0, 0), "Lobby snapshots must never permit shots")
assert(not P.matches(1, 0), "No shots during boot")
assert(P.matches(1, 1) and P.matches(200, 200))
assert(not P.matches(1, 2), "Old round shot cannot spend a new magazine")
assert(not P.matches(2, 1), "Future round shot cannot get ahead of the server")
assert(not P.matches(2, nil), "Uninitialized server does not shoot")
-- Same-round status and the latest round are valid; older messages are not.
assert(P.acceptAmmo(0, 0, nil), "Initial lobby HUD is allowed")
assert(P.acceptAmmo(1, 1, 1))
assert(P.acceptAmmo(2, 1, 1), "Server reply may precede attribute replication")
assert(P.acceptAmmo(2, 2, 1))
assert(not P.acceptAmmo(1, 2, 1), "Replicated round is already newer")
assert(not P.acceptAmmo(1, 1, 2), "Newest server ammo reply takes precedence")
assert(not P.acceptAmmo(0, 1, nil))
assert(P.acceptAmmo(3, nil, nil))
-- Once a new duel bout begins, no earlier bout's shot OR Ammo can be used.
local current = 1
for bout = 1, 24 do
    current += 1
    assert(P.matches(current, current))
    assert(not P.matches(current - 1, current))
    assert(not P.acceptAmmo(current - 1, current, current - 1))
end
print("IRON YARD round-bound combat epochs / stale ammo reply policy: OK")
