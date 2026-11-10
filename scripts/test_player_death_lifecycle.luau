-- IRON YARD / prevent stale Humanoid.Died callbacks after a respawn.
local Life = require("../src/shared/PlayerDeathLifecycle")
local a = { Name = "old" }
local b = { Name = "new" }
local h1, h2 = {}, {}
local state = Life.new()
assert(not Life.bind(state, nil))
assert(not Life.retire(state, nil))
assert(not Life.recordDeath(state, 0, nil, nil, nil, true),
    "No real Humanoid means no death award")
local first = Life.bind(state, a)
assert(first == 1)
assert(not Life.bindHumanoid(state, first, a, h1, b))
assert(Life.bindHumanoid(state, first, a, h1, a))
assert(not Life.bindHumanoid(state, first, a, h2, a),
    "A second Humanoid may not replace one bound to the same generation")
assert(not Life.recordDeath(state, first, a, h1, a, false),
    "Warmup / RESULTS cannot count a human death")
assert(not Life.recordDeath(state, first, a, h2, a, true))
assert(Life.recordDeath(state, first, a, h1, a, true))
assert(not Life.recordDeath(state, first, a, h1, a, true),
    "One death signal can never count more than once")
assert(Life.retire(state, a))
assert(not Life.recordDeath(state, first, a, h1, a, true))
assert(not Life.retire(state, b))
local second = Life.bind(state, b)
assert(second > first)
assert(not Life.bindHumanoid(state, first, a, h1, a),
    "The old WaitForChild continuation must be ignored")
assert(Life.bindHumanoid(state, second, b, h2, b))
assert(not Life.recordDeath(state, second, b, h2, a, true))
assert(Life.recordDeath(state, second, b, h2, b, true))

-- 4 players x 2,500 rounds x 3 respawns. Keep only one active character
-- per player and make all earlier callbacks ineligible.
local accepted = 0
for playerId = 1, 4 do
    local lifecycle = Life.new()
    local oldToken, oldChar, oldHumanoid
    for round = 1, 2500 do
        for spawn = 1, 3 do
            local char = { id = round * 10 + spawn, player = playerId }
            local hum = { parent = char }
            local token = Life.bind(lifecycle, char)
            assert(Life.bindHumanoid(lifecycle, token, char, hum, char))
            if oldChar then
                assert(not Life.recordDeath(lifecycle, oldToken, oldChar,
                    oldHumanoid, oldChar, true))
            end
            assert(not Life.recordDeath(lifecycle, token, char, hum, char, false))
            assert(Life.recordDeath(lifecycle, token, char, hum, char, true))
            accepted += 1
            assert(not Life.recordDeath(lifecycle, token, char, hum, char, true))
            oldToken, oldChar, oldHumanoid = token, char, hum
            assert(Life.retire(lifecycle, char))
            assert(lifecycle.character == nil and lifecycle.humanoid == nil)
        end
    end
end
assert(accepted == 30000)
print("IRON YARD score lifecycle: 30k respawns, no stale or duplicate death awards: OK")
