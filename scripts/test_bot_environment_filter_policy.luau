-- IRON YARD / long-session terrain raycast filter invalidation.
-- Engine-free generation tests guard navigation and cover lookup reuse.
local Policy = require("../src/shared/BotEnvironmentFilterPolicy")

local state = Policy.new()
local firstModel = {}
local rebuiltModel = {}
local firstFolder = {}
local rebuiltFolder = {}
local rayParams = {}
local function stale(params, revision, model, folder)
    return Policy.stale(params, revision, state.generation,
        model, firstModel, folder, firstFolder)
end

assert(state.generation == 0)
assert(stale(nil, 0, firstModel, firstFolder))
assert(not stale(rayParams, 0, firstModel, firstFolder))
assert(stale(rayParams, -1, firstModel, firstFolder))
assert(stale(rayParams, 0, rebuiltModel, firstFolder))
assert(stale(rayParams, 0, firstModel, rebuiltFolder))
assert(stale(rayParams, 0, firstModel, nil))
assert(Policy.invalidate(state) == 1)
assert(stale(rayParams, 0, firstModel, firstFolder))
assert(not stale(rayParams, 1, firstModel, firstFolder))
assert(Policy.invalidate(state) == 2)

-- Four bots, 2,500 simulated waves (20+ player joins/leaves per wave).
-- Stable references should not rebuild; every roster transition should.
local bots = {}
for slot = 1, 4 do
    bots[slot] = {
        model = { slot = slot },
        folder = firstFolder,
        revision = -1,
        params = nil,
    }
end
local constructions, listUpdates, reused = 0, 0, 0
local function getFilter(bot)
    if Policy.stale(bot.params, bot.revision, state.generation,
        bot.cachedModel, bot.model, bot.cachedFolder, bot.folder) then
        if not bot.params then
            bot.params = {}
            constructions += 1
        end
        listUpdates += 1
        bot.revision = state.generation
        bot.cachedModel = bot.model
        bot.cachedFolder = bot.folder
    else
        reused += 1
    end
    return bot.params
end
for wave = 1, 2500 do
    -- Every 100 waves a new arena folder is constructed; individual bots
    -- can also be rebuilt while their roster is unchanged.
    if wave % 100 == 0 then
        for _, bot in ipairs(bots) do bot.folder = {} end
    end
    if wave % 75 == 0 then bots[1].model = {} end
    for _ = 1, 20 do
        Policy.invalidate(state) -- player join, leave or respawn
        for _, bot in ipairs(bots) do
            local p = getFilter(bot)
            assert(p == getFilter(bot), "Unchanged probes must share one object")
        end
    end
    for _ = 1, 6 do
        for _, bot in ipairs(bots) do getFilter(bot) end
    end
end
assert(constructions == 4, "At most one RaycastParams per surviving bot")
assert(listUpdates == 200000,
    "Only roster changes should rebuild filter lists: 2500*20*4")
assert(reused == 260000,
    "Repeated nav/cover probes should reuse existing filters")
assert(#bots == 4 and state.generation == 50002)
print("IRON YARD bot environment filters: 50k roster transitions, 4 bots, zero hot-path allocations: OK")
