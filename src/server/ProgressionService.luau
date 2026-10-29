-- IRON YARD / persistent progression, server only, v1.
-- DataStore writes are atomic, leased and idempotent within each game session.
-- If Roblox DataStore is unavailable, awards remain session-only and the HUD
-- explicitly announces that persistent progress is not confirmed.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProgressionService = {}
local STORE_NAME = "IronYard_Progression_v1"
local AUTOSAVE_SECONDS = 45
local LEASE_SECONDS = 180
local RETRY_LIMIT = 3
local STATS = { "xp", "eliminations", "headshots", "victories" }
local records = {}
local started = false
local store

local function zero()
    return { xp = 0, eliminations = 0, headshots = 0, victories = 0 }
end

local function safeInt(value)
    return type(value) == "number" and value == value and value >= 0
        and value < 9007199254740991 and value % 1 == 0
end

local function copyStats(value)
    local result = {}
    for _, field in ipairs(STATS) do
        local amount = value and value[field] or 0
        assert(safeInt(amount), "Unexpected progression counter: " .. field)
        result[field] = amount
    end
    return result
end

-- Reject unknown/corrupt records instead of quietly replacing earned progress.
-- Return a NEW table, because UpdateAsync may invoke the callback repeatedly.
local function normalize(raw)
    if raw == nil then
        return { schema = 1, xp = 0, eliminations = 0, headshots = 0,
            victories = 0, lock = nil, lastSession = nil }
    end
    assert(type(raw) == "table" and raw.schema == 1, "Unsupported progression schema")
    local counters = copyStats(raw)
    local record = { schema = 1, lock = nil, lastSession = nil }
    for _, field in ipairs(STATS) do record[field] = counters[field] end

    if raw.lock ~= nil then
        assert(type(raw.lock) == "table", "Damaged progression lock")
        assert(type(raw.lock.owner) == "string" and #raw.lock.owner > 4,
            "Damaged progression lock owner")
        assert(safeInt(raw.lock.expiresAt), "Damaged progression lock expiry")
        record.lock = {
            owner = raw.lock.owner,
            expiresAt = raw.lock.expiresAt,
            committed = copyStats(raw.lock.committed),
        }
    end
    if raw.lastSession ~= nil then
        assert(type(raw.lastSession) == "table"
            and type(raw.lastSession.owner) == "string", "Damaged session marker")
        record.lastSession = {
            owner = raw.lastSession.owner,
            committed = copyStats(raw.lastSession.committed),
        }
    end
    return record
end

local function cloneSnapshot(stats)
    return copyStats(stats)
end

local function keyFor(player)
    return "player_" .. tostring(player.UserId)
end

local function levelForXP(xp)
    return math.clamp(1 + math.floor(math.sqrt(math.max(0, xp) / 250)), 1, 1000)
end

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
    local success, result = retry(function()
        local timestamp = os.time()
        return store:UpdateAsync(keyFor(player), function(previous)
            local data = normalize(previous)
            local lock = data.lock
            if lock and lock.owner ~= record.token and lock.expiresAt > timestamp then
                return nil -- The other server owns this key. Fail closed.
            end
            -- An UpdateAsync request may commit even when its response fails.
            -- Never clear our own committed counters on a repeated acquire:
            -- doing so would award the same earned XP a second time.
            if lock and lock.owner == record.token then
                lock.expiresAt = timestamp + LEASE_SECONDS
            else
                data.lock = {
                    owner = record.token,
                    expiresAt = timestamp + LEASE_SECONDS,
                    committed = zero(),
                }
            end
            return data
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
    if not store or not record.loaded then return false end
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
            local data = normalize(previous)
            if not data.lock or data.lock.owner ~= record.token then
                -- A timed-out lock may now belong to another server.
                -- An acknowledged release can be retried safely.
                if release and not data.lock and data.lastSession
                    and data.lastSession.owner == record.token then
                    for _, field in ipairs(STATS) do
                        if data.lastSession.committed[field] < snapshot[field] then
                            return nil
                        end
                    end
                    return data
                end
                return nil
            end
            for _, field in ipairs(STATS) do
                local committed = data.lock.committed[field]
                local increment = math.max(0, snapshot[field] - committed)
                data[field] += increment
                data.lock.committed[field] = math.max(committed, snapshot[field])
            end
            if release then
                data.lastSession = {
                    owner = record.token,
                    committed = copyStats(data.lock.committed),
                }
                data.lock = nil
            else
                data.lock.expiresAt = timestamp + LEASE_SECONDS
            end
            return data
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
    add(player, { victories = 1 })
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
        if record.loaded then flush(player, record, true) end
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
            if record.loaded then
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
