-- IRON YARD / persistent progression, server only, v1.
-- DataStore writes are atomic, leased and idempotent within each game session.
-- If Roblox DataStore is unavailable, awards remain session-only and the HUD
-- explicitly announces that persistent progress is not confirmed.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OperatorFinishes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OperatorFinishes"))
local Objectives = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionObjectives"))
local PracticeMode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
local PrecisionNet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local Ledger = require(script.Parent:WaitForChild("ProgressionLedger"))
local ObjectiveLedger = require(script.Parent:WaitForChild("ObjectiveLedger"))
local ShutdownTracker = require(script.Parent:WaitForChild("ProgressionShutdownTracker"))
local DetachedRelease = require(script.Parent:WaitForChild("ProgressionDetachedRelease"))

local ProgressionService = {}
local STORE_NAME = "IronYard_Progression_v1"
local AUTOSAVE_SECONDS = 45
local OBJECTIVE_REFRESH_SECONDS = 90
local PRACTICE_REFRESH_SECONDS = 90
local LEASE_SECONDS = 180
local RETRY_LIMIT = 3
local records = {}
-- Count in-flight DataStore operations even after PlayerRemoving unlinks a
-- Player. BindToClose otherwise sees zero records and may end the server
-- while a late acquisition is still saving earned progression.
local shutdownTracker = ShutdownTracker.new()
local started = false
local store
local flush -- acquisition may finish after a player has already left
local queueDetachedRelease -- one final release, even after the player is unlinked

local zero = Ledger.zero
local safeInt = Ledger.safeInt
local copyStats = Ledger.copyStats
local cloneSnapshot = Ledger.copyStats

local function keyFor(player)
    return "player_" .. tostring(player.UserId)
end

local levelForXP = Ledger.levelForXP

local function rotateObjectiveDay(record)
    local day = Objectives.day(os.time())
    local old = record.objectiveEvents
    if old.day < day then
        record.previousObjectiveEvents = old.day == day - 1 and old or nil
        record.objectiveEvents = Objectives.forDay(nil, day)
    end
    return record.objectiveEvents.day
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
    -- Saved XP is confirmed by the last successful DataStore transaction.
    -- Earnings added while UpdateAsync yielded remain visibly pending.
    player:SetAttribute("IronYardSavedXP", base.xp + math.min(earned.xp, record.committed.xp))
    player:SetAttribute("IronYardLifetimeEliminations", base.eliminations + earned.eliminations)
    player:SetAttribute("IronYardLifetimeHeadshots", base.headshots + earned.headshots)
    player:SetAttribute("IronYardLifetimeVictories", base.victories + earned.victories)
    player:SetAttribute("IronYardProgressLevel", levelForXP(total))
    local day = rotateObjectiveDay(record)
    local saved = record.savedObjectiveRecord
    local view = ObjectiveLedger.commit(saved, record.token, day,
        record.objectiveEvents, record.previousObjectiveEvents, record.objectiveChoice)
    record.objectives = view.current.progress
    record.finishPreference = view.selection and view.selection.selected and Objectives.FINISH_ID
        or record.rankPreference
    player:SetAttribute(Objectives.ATTRIBUTE, Objectives.encode(record.objectives))
    player:SetAttribute(Objectives.SAVED_ATTRIBUTE, saved and Objectives.encode(saved.current.progress))
    player:SetAttribute(Objectives.UNLOCKED_ATTRIBUTE, record.objectives.unlocked)
    player:SetAttribute("IronYardFinishPreference", record.finishPreference)
    player:SetAttribute("IronYardSavedFinishPreference",
        saved and saved.selection and saved.selection.selected and Objectives.FINISH_ID or record.savedRankPreference)
end

local function createRecord(player)
    if records[player] then return records[player] end
    local record = {
        token = HttpService:GenerateGUID(false),
        status = "LOADING",
        base = zero(),
        earned = zero(),
        committed = zero(),
        objectiveEvents = Objectives.forDay(nil, Objectives.day(os.time())),
        loaded = false,
        triedAcquire = false,
        saving = false,
        closing = false,
        lastWriteAt = 0,
        detachedReleaseQueued = false,
        practiceRecords = {},
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

local function publishPracticeBest(player, record, mode, entry, status)
    if not isLive(player, record) then return end
    local attribute, statusAttribute = PracticeMode.drillBestAttributes(mode)
    player:SetAttribute(attribute, entry.best and PracticeMode.encodeDrillBest(entry.best))
    player:SetAttribute(statusAttribute, status)
end

local function practiceKey(player, mode)
    if mode == PracticeMode.OPEN_DRILL then return "practice_best_v1_" .. tostring(player.UserId) end
    return "practice_best_v1_" .. mode .. "_" .. tostring(player.UserId)
end

local function syncPracticeBest(player, record, mode, entry, departure)
    if record.status == "STUDIO" then return true end
    if record.closing and not departure then return false end
    if entry.saving then return entry.pending == nil end
    local pending = entry.pending
    if not pending and (departure or os.clock() < (entry.refreshAt or 0)) then return true end

    entry.saving = true
    record.practiceSaving = (record.practiceSaving or 0) + 1
    ShutdownTracker.begin(shutdownTracker)
    local ok, result = retry(function()
        if not store then store = DataStoreService:GetDataStore(STORE_NAME) end
        local key = practiceKey(player, mode)
        if not pending then return store:GetAsync(key) end
        return store:UpdateAsync(key, function(previous)
            local saved = PracticeMode.decodeDrillBest(previous)
            if PracticeMode.betterDrillBest(pending, saved) then
                return PracticeMode.encodeDrillBest(pending)
            end
            return previous
        end)
    end)
    entry.saving = false
    local outstanding = record.practiceSaving - 1
    record.practiceSaving = outstanding > 0 and outstanding or nil
    if ok then
        local saved = PracticeMode.decodeDrillBest(result)
        if saved and PracticeMode.betterDrillBest(saved, entry.best) then entry.best = saved end
        if saved and entry.pending and not PracticeMode.betterDrillBest(entry.pending, saved) then
            entry.pending = nil
        end
        entry.refreshAt = os.clock() + PRACTICE_REFRESH_SECONDS
    else
        warn("[IRON YARD] Practice record sync failed: " .. tostring(result))
    end
    local status = entry.pending and (ok and "SAVING" or "SAVE_RETRY") or (ok and "READY" or "LOAD_RETRY")
    publishPracticeBest(player, record, mode, entry, status)
    if isLive(player, record) and entry.pending and entry.pending ~= pending then
        task.defer(syncPracticeBest, player, record, mode, entry)
    end
    ShutdownTracker.finish(shutdownTracker)
    return entry.pending == nil
end

local function syncPracticeBests(player, record, departure)
    local saved = true
    for mode, entry in pairs(record.practiceRecords) do
        if not syncPracticeBest(player, record, mode, entry, departure) then saved = false end
    end
    return saved
end

local function getPracticeRecord(player, record, mode)
    local entry = record.practiceRecords[mode]
    if not entry then
        entry = {}
        record.practiceRecords[mode] = entry
        publishPracticeBest(player, record, mode, entry, record.status == "STUDIO" and "STUDIO" or "LOADING")
    end
    return entry
end

function ProgressionService.loadPracticeBest(player, mode)
    local record = records[player]
    if not record or record.closing then return end
    mode = mode or PracticeMode.OPEN_DRILL
    local entry = getPracticeRecord(player, record, mode)
    task.spawn(syncPracticeBest, player, record, mode, entry)
end

function ProgressionService.loadPracticeRecords(player)
    local record = records[player]
    if not record or record.closing or record.practiceBoardLoading then return end
    record.practiceBoardLoading = true
    for _, mode in ipairs(PracticeMode.DRILL_MODES) do
        getPracticeRecord(player, record, mode)
    end
    task.spawn(function()
        for _, mode in ipairs(PracticeMode.DRILL_MODES) do
            if record.closing then break end
            syncPracticeBest(player, record, mode, record.practiceRecords[mode])
        end
        record.practiceBoardLoading = nil
    end)
end

function ProgressionService.recordPracticeBest(player, score, mode)
    local record = records[player]
    mode = mode or PracticeMode.OPEN_DRILL
    local entry = record and record.practiceRecords[mode]
    if not entry or record.closing or not PracticeMode.betterDrillBest(score, entry.best) then return false end
    local best = { shots = score.shots, hits = score.hits, targetsDown = score.targetsDown }
    local knownBaseline = entry.refreshAt ~= nil or record.status == "STUDIO"
    entry.best = best
    if record.status == "STUDIO" then
        publishPracticeBest(player, record, mode, entry, "STUDIO")
    else
        entry.pending = best
        publishPracticeBest(player, record, mode, entry, "SAVING")
        task.spawn(syncPracticeBest, player, record, mode, entry)
    end
    return knownBaseline
end

local function syncObjectives(player, record, refresh)
    if record.status == "STUDIO" then return true end
    if not store or record.objectiveSaving then return false end
    local day = rotateObjectiveDay(record)
    local today, yesterday, choice = record.objectiveEvents, record.previousObjectiveEvents, record.objectiveChoice
    if not refresh and record.savedObjectiveRecord and today == record.savedObjectiveEvents
        and yesterday == record.savedPreviousObjectiveEvents
        and choice == record.savedObjectiveChoice then return true end

    record.objectiveSaving = true
    ShutdownTracker.begin(shutdownTracker)
    local ok, result = retry(function()
        return store:UpdateAsync("objectives_" .. tostring(player.UserId), function(previous)
            return ObjectiveLedger.commit(previous, record.token, day, today, yesterday, choice)
        end)
    end)
    record.objectiveSaving = false
    if ok and result then
        record.savedObjectiveRecord = result
        record.objectiveReadAt = os.clock()
        record.savedObjectiveEvents = today
        record.savedPreviousObjectiveEvents = yesterday
        record.savedObjectiveChoice = choice
        if isLive(player, record) then publish(player, record) end
    elseif not ok then
        warn("[IRON YARD] Objective save retry required: " .. tostring(result))
    end
    ShutdownTracker.finish(shutdownTracker)
    return ok and result ~= nil
end

local function acquire(player, record)
    if record.loaded or record.saving or record.closing or not store then return end
    record.saving = true
    record.triedAcquire = true
    ShutdownTracker.begin(shutdownTracker)
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
            record.base = Ledger.sessionBase(result, record.token)
            record.committed = copyStats(result.lock.committed)
            -- PlayerRemoving may already have unlinked the record. Reserve
            -- the ONE deferred final release before finishing this acquire.
            -- It must also handle a save that exceeded PlayerRemoving's wait.
            queueDetachedRelease(player, record)
            ShutdownTracker.finish(shutdownTracker)
            return true
        end
        ShutdownTracker.finish(shutdownTracker)
        return false
    end
    if success and result then
        record.loaded = true
        record.base = Ledger.sessionBase(result, record.token)
        record.committed = copyStats(result.lock.committed)
        local preference = result.finishPreference or 0
        record.rankPreference = OperatorFinishes.canSelect(preference, levelForXP(result.xp))
            and preference or 0
        record.savedRankPreference = record.rankPreference
        setStatus(player, record, "ONLINE")
        publish(player, record) -- includes XP earned during the load
        ShutdownTracker.finish(shutdownTracker)
        return true
    end
    setStatus(player, record, success and "LOCKED" or "RETRYING")
    if not success then warn("[IRON YARD] DataStore load retry required: " .. tostring(result)) end
    ShutdownTracker.finish(shutdownTracker)
    return false
end

flush = function(player, record, release)
    -- A load may have successfully acquired its lock before Roblox drops its
    -- response. On PlayerRemoving, safely release ONLY our GUID-owned lock
    -- and commit pending XP even when the initial acknowledgement was lost.
    if not store or (not record.loaded and not release) then return false end
    ShutdownTracker.begin(shutdownTracker)
    local waitStarted = os.clock()
    while record.saving and os.clock() - waitStarted < 12 do
        task.wait(0.15)
    end
    if record.saving then
        ShutdownTracker.finish(shutdownTracker)
        return false
    end
    record.saving = true
    local snapshot = cloneSnapshot(record.earned)
    local finishPreference = record.rankPreference
    local success, result = retry(function()
        local timestamp = os.time()
        return store:UpdateAsync(keyFor(player), function(previous)
            return Ledger.commit(previous, record.token, snapshot, timestamp,
                LEASE_SECONDS, release, finishPreference)
        end)
    end)
    record.saving = false
    if success and result then
        record.committed = cloneSnapshot(snapshot)
        record.savedRankPreference = finishPreference
        if release then record.careerReleased = true end
        record.lastWriteAt = os.clock()
        if player.Parent then
            setStatus(player, record, release and "CLOSED" or "ONLINE")
            publish(player, record)
        end
        ShutdownTracker.finish(shutdownTracker)
        return true
    end
    if player.Parent then setStatus(player, record, success and "LOCKED" or "RETRYING") end
    if not success then warn("[IRON YARD] DataStore save failed after retries: " .. tostring(result)) end
    ShutdownTracker.finish(shutdownTracker)
    return false
end

local function flushDeparture(player, record)
    local released = true
    if not record.careerReleased and (record.loaded or record.triedAcquire) then
        released = flush(player, record, true)
    end
    local objectivesSaved = syncObjectives(player, record)
    local practiceSaved = syncPracticeBests(player, record, true)
    return released and objectivesSaved and practiceSaved
end

-- PlayerRemoving gives a busy DataStore a bounded synchronous chance
-- to finish. If an autosave still occupies the record afterwards, retain
-- this player record off-roster and retry the FINAL release when it frees.
-- A late acquire and PlayerRemoving can both request this exact task:
-- claim it once, and register the shutdown slot BEFORE the task is queued.
queueDetachedRelease = function(player, record)
    if not DetachedRelease.claim(record) then return end
    ShutdownTracker.begin(shutdownTracker)
    task.spawn(function()
        local ok, released = pcall(function()
            -- A DataStore request can be slower than both 12s waits in
            -- PlayerRemoving/flush. Bound detached memory and work; the
            -- server's own BindToClose limit remains 26 seconds.
            local untilTime = os.clock() + 45
            while (record.saving or record.objectiveSaving or record.practiceSaving) and os.clock() < untilTime do
                task.wait(0.15)
            end
            if record.saving or record.objectiveSaving or record.practiceSaving then return false end
            -- Only the original server/session token can release this key.
            -- An unacknowledged acquisition may still own its lease.
            for attempt = 1, 2 do
                if flushDeparture(player, record) then return true end
                if attempt < 2 then task.wait(2) end
            end
            return false
        end)
        ShutdownTracker.finish(shutdownTracker)
        if not ok or not released then
            warn("[IRON YARD] Late DataStore release failed for UserId "
                .. tostring(player.UserId))
        end
    end)
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
        record.rankPreference = 0
        publish(player, record)
        return
    end
    task.spawn(loadOrRetry, player, record)
    task.spawn(syncObjectives, player, record)
end

local function add(player, deltas, objectiveWeapon)
    local record = records[player]
    if not record or not player.Parent then return end
    local previousXP = record.base.xp + record.earned.xp
    -- The pure ledger returns a complete validated snapshot or throws
    -- without touching the prior one. Keep all four counters consistent if
    -- an unexpected award is malformed or a session approaches integer limits.
    if record.closing then return end
    record.earned = Ledger.applyGrant(record.earned, deltas)
    if objectiveWeapon then
        local day = rotateObjectiveDay(record)
        record.objectiveEvents = Objectives.eliminate(record.objectiveEvents, day, objectiveWeapon)
    end
    publish(player, record)
    -- Only announce a crossing from a known career baseline. Loading or
    -- retrying the DataStore never enters this award path.
    if record.loaded or record.status == "STUDIO" then
        local finish = OperatorFinishes.earnedBetween(
            levelForXP(previousXP), levelForXP(record.base.xp + record.earned.xp))
        return finish and finish.level or nil
    end
end

function ProgressionService.recordElimination(player, points, headshot, objectiveWeapon)
    assert(safeInt(points) and points <= 1000, "Untrusted XP grant")
    return add(player, { xp = points, eliminations = 1, headshots = headshot and 1 or 0 }, objectiveWeapon)
end

function ProgressionService.recordVictory(player)
    return add(player, { xp = 250, victories = 1 })
end

function ProgressionService.recordFfaCompletion(player)
    local record = records[player]
    if not record or not isLive(player, record) then return end
    local day = rotateObjectiveDay(record)
    local updated = Objectives.finishFfa(record.objectiveEvents, day)
    if updated == record.objectiveEvents then return end
    record.objectiveEvents = updated
    publish(player, record)
end

local function setFinishPreference(player, preference)
    if not RemoteGuard.allow(player, "SetCareerFinish") then return end
    local record = records[player]
    if not record or record.closing or record.finishPreference == nil
        or preference == record.finishPreference then return end
    local level = levelForXP(record.base.xp + record.earned.xp)
    if not OperatorFinishes.canSelect(preference, level, record.objectives.unlocked) then return end
    local selected = preference == Objectives.FINISH_ID
    if not selected then record.rankPreference = preference end
    local localChoice = record.objectiveChoice
    local savedChoice = record.savedObjectiveRecord and record.savedObjectiveRecord.selection
    record.objectiveChoice = {
        selected = selected, token = record.token,
        stamp = math.max(DateTime.now().UnixTimestampMillis,
            localChoice and localChoice.stamp + 1 or 0,
            savedChoice and savedChoice.stamp + 1 or 0),
    }
    publish(player, record)
end

function ProgressionService.start()
    if started then return end
    started = true
    PrecisionNet.getRemotes(true).SetCareerFinish.OnServerEvent:Connect(setFinishPreference)
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
        -- Retain a shutdown slot across the PlayerRemoving wait AND the
        -- eventual detached release. Once records[player] is cleared, only
        -- this tracker can keep BindToClose waiting for the in-flight save.
        ShutdownTracker.begin(shutdownTracker)
        local untilTime = os.clock() + 12
        while (record.saving or record.objectiveSaving) and os.clock() < untilTime do task.wait(0.15) end
        if not flushDeparture(player, record) then
            -- The detached task survives unlink and has a shutdown slot.
            queueDetachedRelease(player, record)
        end
        records[player] = nil
        ShutdownTracker.finish(shutdownTracker)
    end)

    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            for player, record in pairs(records) do
                if not record.closing and player.Parent then
                    if next(record.practiceRecords) then task.spawn(syncPracticeBests, player, record) end
                    task.spawn(function()
                        if record.loaded then
                            flush(player, record, false)
                        else
                            loadOrRetry(player, record)
                        end
                    end)
                    task.spawn(function()
                        if rotateObjectiveDay(record) ~= record.objectives.day then publish(player, record) end
                        -- A destination server can load before the source's
                        -- final save. Reconcile again after joining, even if
                        -- this session has earned no objective progress yet.
                        local refresh = not record.objectivesReconciled
                            or os.clock() - (record.objectiveReadAt or 0) >= OBJECTIVE_REFRESH_SECONDS
                        if syncObjectives(player, record, refresh) then
                            record.objectivesReconciled = true
                        end
                    end)
                end
            end
        end
    end)

    game:BindToClose(function()
        local pending = 0
        for player, record in pairs(records) do
            -- PlayerRemoving already owns the final release of its record;
            -- never compete with that in-flight write on the same key.
            if not record.closing and record.status ~= "STUDIO" then
                record.closing = true
                pending += 1
                task.spawn(function()
                    if not flushDeparture(player, record) then queueDetachedRelease(player, record) end
                    pending -= 1
                end)
            end
        end
        -- Includes records already removed from the Players registry,
        -- acquisitions that finish after leave, and their late release tasks.
        -- Roblox's shutdown time is bounded; do not wait indefinitely.
        local deadline = os.clock() + 26
        while (pending > 0 or ShutdownTracker.hasPending(shutdownTracker))
            and os.clock() < deadline do
            task.wait(0.15)
        end
    end)
end

return ProgressionService
