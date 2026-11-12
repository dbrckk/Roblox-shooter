-- IRON YARD / server wiring for the LOT C1 lifecycle ledger.
-- The ledger answers "did this round release what it took?". This service feeds
-- it from the two places that own a resource's lifetime, without deciding
-- anything: a player joining or leaving, a weapon being equipped, and a round
-- changing phase. It never touches damage, movement, spawning or scoring.
-- Counters are published as Workspace attributes, written by the server only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LifecycleLedger = require(Shared:WaitForChild("LifecycleLedger"))

local LifecycleService = {}
local started = false
local ledger = LifecycleLedger.new()
-- What this service holds on behalf of each player, so a departure can release
-- exactly those entries and never somebody else's.
local held = {}

local function userIdOf(player)
    local ok, id = pcall(function() return player.UserId end)
    if ok and type(id) == "number" and id ~= 0 then return id end
    return nil
end

-- Every ledger call is guarded: an audit bug must never break a round.
local function acquire(kind, id)
    local ok, accepted = pcall(LifecycleLedger.acquire, ledger, kind, id)
    if not ok then return false end
    return accepted
end

local function release(kind, id)
    local ok = pcall(LifecycleLedger.release, ledger, kind, id)
    return ok
end

local function publish()
    local ok, report = pcall(LifecycleLedger.report, ledger)
    if not ok then return end
    Workspace:SetAttribute("IronYardAuditLive", report.total)
    Workspace:SetAttribute("IronYardAuditPeak", report.peak)
    Workspace:SetAttribute("IronYardAuditLeaks", #report.leaks)
    Workspace:SetAttribute("IronYardAuditDuplicates", report.duplicates)
    Workspace:SetAttribute("IronYardAuditOverflow", report.overflow)
end

-- A weapon swap replaces the previous model entry instead of adding one.
local function onWeaponChanged(player)
    local id = userIdOf(player)
    if id == nil then return end
    local weaponId = player:GetAttribute("IronYardEquippedWeapon")
    if type(weaponId) ~= "string" or #weaponId == 0 then return end
    local key = tostring(id) .. "/" .. weaponId
    local current = held[id]
    if current == nil then
        held[id] = { weapon = key }
    elseif current.weapon ~= key then
        release("weapon", current.weapon)
        current.weapon = key
    else
        return
    end
    acquire("weapon", key)
    publish()
end

local function onPlayerAdded(player)
    local id = userIdOf(player)
    if id == nil then return end
    held[id] = held[id] or {}
    acquire("player", id)
    if held[id].listener == nil then
        held[id].listener = true
        player:GetAttributeChangedSignal("IronYardEquippedWeapon"):Connect(function()
            onWeaponChanged(player)
        end)
    end
    onWeaponChanged(player)
    publish()
end

local function onPlayerRemoving(player)
    local id = userIdOf(player)
    if id == nil then return end
    local current = held[id]
    if current ~= nil then
        if current.weapon ~= nil then release("weapon", current.weapon) end
        held[id] = nil
    end
    release("player", id)
    publish()
end

-- Round-scoped resources die with the round: an effect or an impact mark that
-- outlives RESULTS is a leak, and the ledger is what makes it visible.
local function onPhaseChanged()
    local phase = Workspace:GetAttribute("IronYardRoundPhase")
    if phase == "LIVE" then
        acquire("fx", "round_live")
    elseif phase == "RESULTS" or phase == "WAITING" then
        release("fx", "round_live")
        pcall(LifecycleLedger.releaseKind, ledger, "fx")
        pcall(LifecycleLedger.releaseKind, ledger, "impact")
    end
    publish()
end

function LifecycleService.report()
    local ok, report = pcall(LifecycleLedger.report, ledger)
    if ok then return report end
    return nil
end

function LifecycleService.start()
    if started then return end
    started = true
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    Workspace:GetAttributeChangedSignal("IronYardRoundPhase"):Connect(onPhaseChanged)
    publish()
end

return LifecycleService
