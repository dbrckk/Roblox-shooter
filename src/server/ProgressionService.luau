-- IRON YARD / persistent progression, server only, v1.
-- DataStore writes are atomic, leased and idempotent within each game session.
-- If Roblox DataStore is unavailable, awards remain session-only and the HUD
-- explicitly announces that persistent progress is not confirmed.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Ledger = require(script.Parent:WaitForChild("ProgressionLedger"))

local ProgressionService = {}
local STORE_NAME = "IronYard_Progression_v1"
local AUTOSAVE_SECONDS = 45
local LEASE_SECONDS = 180
local RETRY_LIMIT = 3
local STATS = Ledger.STATS
local records = {}
local started = false
local store

local zero = Ledger.zero
local safeInt = Ledger.safeInt
local copyStats = Ledger.copyStats
local cloneSnapshot = Ledger.copyStats

local function keyFor(player)
    return "player_" .. tostring(player.UserId)
end

local levelForXP = Ledger.levelForXP

local function setStatus(player, record, status)
    record.status = status
    if player.Parent then
        player:SetAttribute("IronYardProgressStatus", status)
    end
end

local function publish(player, record)
    if not player.Parent then return end
    local base = record.base
    local earned = record.earned
    local total = base.xp + earned.xp
    player:SetAttribute("IronYardLifetimeXP", total)
    player:SetAttribute("IronYardLifetimeEliminations", base.eliminations + earned.eliminations)
    player:SetAttribute("IronYardLifetimeHeadshots", base.headshots + earned.headshots)
    player:SetAttribute("IronYardLifetimeVictories", base.victories + earned.victories)
    player:SetAttribute("IronYardProgressLevel", levelForXP(total))
end

local function createRecord(player)
    if records[player] then return records[player] end
    local record = {
        token = HttpService:GenerateGUID(false),
        status = "LOADING",
        base = zero(),
        earned = zero(),
        committed = zero(),
        loaded = false,
        triedAcquire = false,
        saving = false,
        closing = false,
        lastWriteAt = 0,
    }
    records[player] = record
    setStatus(player, record, "LOADING")
    publish(player, record)
    return record
end

local function isLive(player, record)
    return player.Parent ~= nil and records[player] == record and not record.closing
end

local function retry(operation)
    local lastError
    for attempt = 1, RETRY_LIMIT do
        local ok, result = pcall(operation)
        if ok then return true, result end
        lastError = tostring(result)
        if attempt < RETRY_LIMIT then
            task.wait(attempt * 1.5)
        end
    end
    return false, lastError
end

local function acquire(player, record)
    if record.loaded or record.saving or record.closing or not store then return end
    record.saving = true
    record.triedAcquire = true
    local success, result = retry(function()
        local timestamp = os.time()
        return store:UpdateAsync(keyFor(player), function(previous)
            return Ledger.acquire(previous, record.token, timestamp, LEASE_SECONDS)
        end)
    end)
    record.saving = false
    if not isLive(player, record) then
        -- The player left during acquisition; release any lock just acquired.
        if success and result then
            record.loaded = true
            record.base = copyStats(result)
            return true
        end
        return false
    end
    if success and result then
        record.loaded = true
        record.base = copyStats(result)
        record.committed = zero()
        setStatus(player, record, "ONLINE")
        publish(player, record) -- includes XP earned during the load
        return true
    end
    setStatus(player, record, success and "LOCKED" or "RETRYING")
    if not success then warn("[IRON YARD] DataStore load retry required: " .. tostring(result)) end
    return false
end

local function flush(player, record, release)
    -- A load may have successfully acquired its lock before Roblox drops its
    -- response. On PlayerRemoving, safely release ONLY our GUID-owned lock
    -- and commit pending XP even when the initial acknowledgement was lost.
    if not store or (not record.loaded and not release) then return false end
    local waitStarted = os.clock()
    while record.saving and os.clock() - waitStarted < 12 do
        task.wait(0.15)
    end
    if record.saving then return false end
    record.saving = true
    local snapshot = cloneSnapshot(record.earned)
    local success, result = retry(function()
        local timestamp = os.time()
        return store:UpdateAsync(keyFor(player), function(previous)
            return Ledger.commit(previous, record.token, snapshot, timestamp,
                LEASE_SECONDS, release)
        end)
    end)
    record.saving = false
    if success and result then
        record.committed = cloneSnapshot(snapshot)
        record.lastWriteAt = os.clock()
        if player.Parent then
            setStatus(player, record, release and "CLOSED" or "ONLINE")
        end
        return true
    end
    if player.Parent then setStatus(player, record, success and "LOCKED" or "RETRYING") end
    if not success then warn("[IRON YARD] DataStore save failed after retries: " .. tostring(result)) end
    return false
end

local function loadOrRetry(player, record)
    if not isLive(player, record) or record.loaded then return end
    if not store and not RunService:IsStudio() and game.GameId ~= 0 then
        -- GetDataStore itself may fail transiently. Recover on the next
        -- autosave tick rather than freezing every player's status forever.
        local ok, candidate = pcall(function()
            return DataStoreService:GetDataStore(STORE_NAME)
        end)
        if ok then store = candidate end
    end
    if not store then
        setStatus(player, record, RunService:IsStudio() and "STUDIO" or "UNAVAILABLE")
        return
    end
    acquire(player, record)
end

local function attach(player)
    local record = createRecord(player)
    if RunService:IsStudio() or game.GameId == 0 then
        -- Deliberately keep Studio builds off live player keys. Studio API
        -- access, if enabled, otherwise writes into the production universe.
        setStatus(player, record, "STUDIO")
        return
    end
    task.spawn(loadOrRetry, player, record)
end

local function add(player, deltas)
    local record = records[player]
    if not record or not player.Parent then return end
    for _, field in ipairs(STATS) do
        local amount = deltas[field] or 0
        assert(safeInt(amount) and amount <= 10000, "Invalid progression event")
        record.earned[field] += amount
    end
    publish(player, record)
end

function ProgressionService.recordElimination(player, points, headshot)
    assert(safeInt(points) and points <= 1000, "Untrusted XP grant")
    add(player, { xp = points, eliminations = 1, headshots = headshot and 1 or 0 })
end

function ProgressionService.recordVictory(player)
    add(player, { xp = 250, victories = 1 })
end

function ProgressionService.start()
    if started then return end
    started = true
    if not RunService:IsStudio() and game.GameId ~= 0 then
        local ok, result = pcall(function()
            return DataStoreService:GetDataStore(STORE_NAME)
        end)
        if ok then store = result else
            warn("[IRON YARD] Persistent progression store unavailable: " .. tostring(result))
        end
    end

    Players.PlayerAdded:Connect(attach)
    for _, player in ipairs(Players:GetPlayers()) do attach(player) end
    Players.PlayerRemoving:Connect(function(player)
        local record = records[player]
        if not record then return end
        record.closing = true
        -- A pending UpdateAsync load might complete after PlayerRemoving.
        local untilTime = os.clock() + 12
        while record.saving and os.clock() < untilTime do task.wait(0.15) end
        if record.loaded or record.triedAcquire then
            flush(player, record, true)
        end
        records[player] = nil
    end)

    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            for player, record in pairs(records) do
                if not record.closing and player.Parent then
                    task.spawn(function()
                        if record.loaded then
                            flush(player, record, false)
                        else
                            loadOrRetry(player, record)
                        end
                    end)
                end
            end
        end
    end)

    game:BindToClose(function()
        local pending = 0
        for player, record in pairs(records) do
            if record.loaded or record.triedAcquire then
                pending += 1
                task.spawn(function()
                    flush(player, record, true)
                    pending -= 1
                end)
            end
        end
        local deadline = os.clock() + 26
        while pending > 0 and os.clock() < deadline do task.wait(0.15) end
    end)
end

return ProgressionService
