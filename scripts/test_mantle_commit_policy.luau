-- Regression for delayed mantle displacements crossing FFA/duel phases.
-- Pure server-state policy: no Roblox physics is simulated.
local Policy = require("../src/shared/MantleCommitPolicy")
local rigA, rigB, rootA, rootB = {}, {}, {}, {}
local request = { character = rigA, root = rootA, token = 4, epoch = 17, phase = "LIVE" }
local function now(overrides)
    local result = { character = rigA, root = rootA, token = 4,
        epoch = 17, phase = "LIVE", anchored = false }
    for k, v in pairs(overrides or {}) do result[k] = v end
    return result
end
assert(Policy.canFinish(request, now()), "valid unanchored LIVE mantle must finish")

-- After the server enters duel preparation, the old callback must not move
-- an anchored, server-placed player. This was possible before the fix.
for _, phase in ipairs({ "DUEL_PREP", "DUEL_BREAK", "RESULTS", "COUNTDOWN", "WAITING" }) do
    assert(not Policy.canFinish(request, now({ phase = phase })),
        "delayed mantle crossed a phase boundary: " .. phase)
end
assert(not Policy.canFinish(request, now({ anchored = true })),
    "an anchored duel-prep root must not be repositioned")
assert(not Policy.canFinish(request, now({ token = 5 })),
    "resetDuelMovement must invalidate an earlier mantle generation")
assert(not Policy.canFinish(request, now({ character = rigB })),
    "a respawn must invalidate the original mantle")
assert(not Policy.canFinish(request, now({ root = rootB })),
    "a new root must not inherit the earlier teleport")
assert(not Policy.canFinish(request, now({ epoch = 18 })),
    "an earlier round cannot complete after the fire epoch advances")
assert(not Policy.canFinish(request, now({ epoch = 16 })),
    "a stale epoch must be rejected even while the phase is LIVE")
local badRequest = { character = rigA, root = rootA, token = 4, epoch = 17,
    phase = "COUNTDOWN" }
assert(not Policy.canFinish(badRequest, now()),
    "a mantle requested outside LIVE may never complete")
badRequest.phase = "LIVE"
badRequest.epoch = nil
assert(not Policy.canFinish(badRequest, now()),
    "unversioned requests must fail closed")
badRequest.epoch = 17
badRequest.token = 0
assert(not Policy.canFinish(badRequest, now()),
    "invalid generation tokens must fail closed")
assert(not Policy.canFinish({}, now()))
assert(not Policy.canFinish(nil, now()))
assert(not Policy.canFinish(request, nil))
assert(not Policy.canFinish(request, {}))
print("IRON YARD delayed mantle phase, duel anchor, epoch and respawn: OK")
