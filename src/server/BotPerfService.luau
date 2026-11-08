-- IRON YARD / opt-in owner-only performance snapshots, NEVER gameplay state.
-- Inactive outside a private diagnostic session; no per-frame extra loops,
-- persistent metrics, client-supplied measurements or global replication.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotPerfProfile"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet"))
local Service = {}

local viewer = nil
local state = nil
local generation = 0
local started = false
local lastCommand = setmetatable({}, { __mode = "k" })

local function authorized(player)
    if not player or not player:IsA("Player") then return false end
    if RunService:IsStudio() then return true end
    return game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0
        and player.UserId == game.CreatorId
end

local function stopCapture()
    viewer = nil
    state = nil
    generation += 1
end

function Service.active()
    return viewer ~= nil
end

function Service.count(key)
    if state then Profile.count(state, key) end
end

function Service.begin()
    return state and os.clock() or nil
end

function Service.measure(key, sampleStart)
    if state and sampleStart then
        Profile.timing(state, key, math.max(0, (os.clock() - sampleStart) * 1000))
    end
end

function Service.start()
    if started then return end
    started = true
    local remote = Remotes.getRemotes(true).PerformanceDiagnostics
    remote.OnServerEvent:Connect(function(player, command)
        if not authorized(player) or (command ~= "start" and command ~= "stop") then
            return
        end
        local now = os.clock()
        if now - (lastCommand[player] or -math.huge) < 0.4 then return end
        lastCommand[player] = now

        if command == "stop" then
            if viewer == player then stopCapture() end
            remote:FireClient(player, { status = "OFF" })
            return
        end
        -- Only one authorized observer per server; a second Studio test
        -- account cannot leak player data (only aggregate bot counts).
        stopCapture()
        viewer = player
        state = Profile.new(now)
        local myGeneration = generation
        remote:FireClient(player, { status = "ON" })
        task.spawn(function()
            while viewer == player and generation == myGeneration do
                task.wait(Profile.WINDOW_SECONDS)
                if viewer ~= player or generation ~= myGeneration or not state then
                    break
                end
                local snapshot = Profile.flush(state, os.clock(),
                    workspace:GetAttribute("NeonBotCount") or 0)
                if snapshot then
                    snapshot.status = "ON"
                    remote:FireClient(player, snapshot)
                end
            end
        end)
    end)
    Players.PlayerRemoving:Connect(function(player)
        lastCommand[player] = nil
        if viewer == player then stopCapture() end
    end)
end

return Service
