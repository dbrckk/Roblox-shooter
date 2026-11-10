-- IRON YARD / bot death callback invalidation during stream churn.
local Lifetime = require("../src/shared/BotDeathFxLifecycle")
local folder = { Name = "NeonStrikeBots" }
local elsewhere = { Name = "StreamingOut" }
local state = Lifetime.new()
assert(Lifetime.track(state, {}, folder) == nil)
assert(Lifetime.track(state, nil, folder) == nil)
local model = { Parent = folder }
local first = Lifetime.track(state, model, folder)
assert(first and Lifetime.active(state, model, first, folder))
assert(not Lifetime.track(state, model, folder), "One death listener per bot")
first.deathQueued = true
model.Parent = elsewhere
assert(not Lifetime.active(state, model, first, folder),
    "Unparented bots cannot emit delayed dust")
assert(Lifetime.retire(state, model) == first)
assert(not first.active and not Lifetime.active(state, model, first, folder))
model.Parent = folder
local second = Lifetime.track(state, model, folder)
assert(second and second ~= first and not second.deathQueued)
assert(not Lifetime.active(state, model, first, folder),
    "Old delayed callbacks must never affect a re-streamed model")
assert(Lifetime.active(state, model, second, folder))
assert(Lifetime.retire(state, model) == second)
assert(Lifetime.retire(state, model) == nil)
assert(next(state.byModel) == nil)

-- Stress 2500 rounds with four streamed-in/out bots and callbacks returning
-- after removal. No stale callback can pass the identity check.
local stale = {}
for round = 1, 2500 do
    for botId = 1, 4 do
        local bot = { Parent = folder, slot = botId }
        local token = Lifetime.track(state, bot, folder)
        assert(token and Lifetime.active(state, bot, token, folder))
        stale[#stale + 1] = { model = bot, entry = token }
        -- Simulate a late network/model callback after the bot vanished.
        bot.Parent = elsewhere
        assert(not Lifetime.active(state, bot, token, folder))
        assert(Lifetime.retire(state, bot) == token)
        bot.Parent = folder
        local replacement = Lifetime.track(state, bot, folder)
        assert(replacement and replacement ~= token)
        assert(not Lifetime.active(state, bot, token, folder))
        assert(Lifetime.active(state, bot, replacement, folder))
        assert(Lifetime.retire(state, bot) == replacement)
        bot.Parent = elsewhere
    end
    assert(next(state.byModel) == nil,
        "A round reset must not retain old bot model references")
end
for _, old in ipairs(stale) do
    assert(not Lifetime.active(state, old.model, old.entry, folder),
        "No delayed callback from any of 10k previous bots may emit")
end
assert(Lifetime.active(nil, model, second, folder) == false)
assert(Lifetime.retire(nil, model) == nil)
print("IRON YARD bot death lifecycle: 2500 round resets / 10000 invalidated callbacks: OK")
