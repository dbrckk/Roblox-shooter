-- IRON YARD / server wiring for the LOT 0b observability core.
-- Two jobs only: classify every joining player against the server capacity
-- decision, and aggregate the warnings the server already emits.
-- It never kicks, never moves a player and never publishes to a client remote:
-- the hard cap stays Players.MaxPlayers, which the place must still declare.
-- A player beyond the policy is labelled FULL and logged, not removed, because
-- a handling rule invented here would be untested server behaviour.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LogService = game:GetService("LogService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServerCapacity = require(Shared:WaitForChild("ServerCapacity"))
local TelemetryFunnel = require(Shared:WaitForChild("TelemetryFunnel"))
local DiagnosticsLog = require(Shared:WaitForChild("DiagnosticsLog"))

local ObservabilityService = {}
local started = false
local funnel = TelemetryFunnel.new()
local log = DiagnosticsLog.new()

local function clock()
    local ok, value = pcall(os.clock)
    if ok and type(value) == "number" then return value end
    return 0
end

-- Read-only mirrors for a dashboard or Studio inspection. Attributes replicate
-- but only the server writes them, so this is not a client trust surface.
local function publish()
    local population = #Players:GetPlayers()
    local funnelSnapshot = TelemetryFunnel.snapshot(funnel)
    local logSnapshot = DiagnosticsLog.snapshot(log)
    Workspace:SetAttribute("IronYardFreeSlots", ServerCapacity.freeSlots(population))
    Workspace:SetAttribute("IronYardFunnelJoined", funnelSnapshot.stages.JOINED)
    Workspace:SetAttribute("IronYardFunnelPlayers", funnelSnapshot.uniquePlayers)
    Workspace:SetAttribute("IronYardFunnelReturning",
        funnelSnapshot.stages.SECOND_SESSION)
    Workspace:SetAttribute("IronYardLogDistinct", logSnapshot.distinct)
    Workspace:SetAttribute("IronYardLogEvicted", logSnapshot.evicted)
    Workspace:SetAttribute("IronYardLogSaturated", DiagnosticsLog.saturated(log))
end

-- Records one warning without printing it. The caller keeps ownership of its
-- own output; this only feeds the bounded summary.
function ObservabilityService.record(category, message)
    local ok, count = pcall(DiagnosticsLog.record, log, category, message, clock())
    if not ok then return nil end
    return count
end

-- Where a joining player lands. `PlayerAdded` fires once the player is already
-- in Players, hence the -1: the policy is stated on the population before it.
function ObservabilityService.classify(player)
    local population = #Players:GetPlayers() - 1
    if population < 0 then population = 0 end
    local slot = ServerCapacity.classify(population)
    player:SetAttribute("IronYardSlot", slot)
    if slot == "FULL" then
        -- Declaring Players.MaxPlayers = 12 should make this unreachable.
        ObservabilityService.record("capacity", "join beyond the 12-player policy")
    end
    return slot
end

function ObservabilityService.snapshot()
    return {
        funnel = TelemetryFunnel.snapshot(funnel),
        log = DiagnosticsLog.snapshot(log),
    }
end

-- Never print from here: this handler sees every warning, so calling warn()
-- inside it would loop forever. It only buckets.
local function onMessage(message, messageType)
    if messageType ~= Enum.MessageType.MessageWarning then return end
    local text = tostring(message)
    ObservabilityService.record(DiagnosticsLog.categorize(text), text)
end

function ObservabilityService.start()
    if started then return end
    started = true
    Players.PlayerAdded:Connect(function(player)
        ObservabilityService.classify(player)
        if TelemetryFunnel.recordJoin(funnel, player.UserId) == "RETURNING" then
            ObservabilityService.record("session", "returning player joined")
        end
        publish()
    end)
    Players.PlayerRemoving:Connect(function()
        publish()
    end)
    -- Aggregating warnings through LogService is the only way to cover the
    -- services that already warn without editing every one of them.
    local ok = pcall(function()
        LogService.MessageOut:Connect(onMessage)
    end)
    if not ok then
        ObservabilityService.record("observability", "LogService.MessageOut unavailable")
    end
    publish()
end

return ObservabilityService
