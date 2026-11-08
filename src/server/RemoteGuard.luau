-- IRON YARD / server-only remote admission and per-player cleanup.
-- No user-controlled timestamps, global player throttling, or replicated
-- counters. Different players and categories always have separate buckets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteRatePolicy"))
local Guard = {}
local buckets = setmetatable({}, { __mode = "k" })

function Guard.allow(player, channel)
    if not player or player.Parent ~= Players then return false end
    local state = buckets[player]
    if not state then
        state = {}
        buckets[player] = state
    end
    return Policy.allow(state, channel, os.clock())
end

function Guard.movement(player, action)
    local special = Policy.channelForAction(action)
    if special == "MovementStop" then
        return Guard.allow(player, special)
    end
    if not Guard.allow(player, "MovementAction") then return false end
    if special == "MovementUpdate" then
        return Guard.allow(player, special)
    end
    return true
end

Players.PlayerRemoving:Connect(function(player)
    buckets[player] = nil
end)

return Guard
