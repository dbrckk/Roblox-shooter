-- IRON YARD / pure server-side funnel telemetry (LOT 0b of the RIVALS plan).
-- Answers the four questions that cannot be answered today: does a joining
-- player reach a first kill, does a round actually finish, do players come
-- back for a second session, and which weapon scores the kills.
-- This module never publishes anything: no remote, no HTTP, no DataStore.
-- The server owns the state and decides where a snapshot goes, which keeps
-- the accounting deterministic and testable offline.
local TelemetryFunnel = {}

TelemetryFunnel.STAGES = { "JOINED", "FIRST_KILL", "ROUND_COMPLETED", "SECOND_SESSION" }
-- Bounded memory: a long-lived server must not grow one key per visitor.
TelemetryFunnel.MAX_TRACKED_PLAYERS = 64
TelemetryFunnel.MAX_TRACKED_WEAPONS = 24
TelemetryFunnel.OTHER_WEAPON = "other"
TelemetryFunnel.MAX_IDENTIFIER = 32
-- A round longer than this is a bug, not a measurement: clamp instead of
-- letting one stale timestamp poison the average.
TelemetryFunnel.MAX_ROUND_SECONDS = 3600

local function validUserId(userId)
    return type(userId) == "number" and userId == userId
        and userId > -math.huge and userId < math.huge and userId ~= 0
end

local function validSeconds(seconds)
    return type(seconds) == "number" and seconds == seconds
        and seconds >= 0 and seconds <= TelemetryFunnel.MAX_ROUND_SECONDS
end

local function mark(state, stage)
    if state.stages[stage] then return false end
    state.stages[stage] = true
    return true
end

local function identifier(value)
    assert(type(value) == "string" and #value > 0, "Invalid weapon identifier")
    if #value > TelemetryFunnel.MAX_IDENTIFIER then
        return string.sub(value, 1, TelemetryFunnel.MAX_IDENTIFIER)
    end
    return value
end

function TelemetryFunnel.new()
    return {
        stages = {},
        players = {},
        trackedPlayers = 0,
        kills = 0,
        weapons = {},
        trackedWeapons = 0,
        rounds = { completed = 0, abandoned = 0, totalSeconds = 0, longestSeconds = 0 },
    }
end

-- Returns "FIRST_SESSION" or "RETURNING"; the second visit of a known player
-- is what marks SECOND_SESSION, once and for all.
function TelemetryFunnel.recordJoin(state, userId)
    assert(type(state) == "table", "Missing funnel state")
    assert(validUserId(userId), "Invalid userId")
    local visits = state.players[userId]
    mark(state, "JOINED")
    if visits == nil then
        if state.trackedPlayers < TelemetryFunnel.MAX_TRACKED_PLAYERS then
            state.players[userId] = 1
            state.trackedPlayers = state.trackedPlayers + 1
        end
        return "FIRST_SESSION"
    end
    state.players[userId] = visits + 1
    if visits == 1 then mark(state, "SECOND_SESSION") end
    return "RETURNING"
end

-- One accepted kill, attributed to the weapon that scored it.
function TelemetryFunnel.recordKill(state, weaponId)
    assert(type(state) == "table", "Missing funnel state")
    local id = identifier(weaponId)
    state.kills = state.kills + 1
    local known = state.weapons[id]
    if known ~= nil then
        state.weapons[id] = known + 1
    elseif state.trackedWeapons < TelemetryFunnel.MAX_TRACKED_WEAPONS then
        state.weapons[id] = 1
        state.trackedWeapons = state.trackedWeapons + 1
    else
        local other = state.weapons[TelemetryFunnel.OTHER_WEAPON] or 0
        state.weapons[TelemetryFunnel.OTHER_WEAPON] = other + 1
    end
    mark(state, "FIRST_KILL")
    return state.kills
end

-- One finished round. `completed` is false for an abandoned round, which is
-- exactly the split the funnel needs; an abandoned round still counts its
-- duration so a crash loop cannot look like a fast, healthy server.
function TelemetryFunnel.recordRound(state, durationSeconds, completed)
    assert(type(state) == "table", "Missing funnel state")
    assert(validSeconds(durationSeconds), "Invalid round duration")
    assert(type(completed) == "boolean", "Round completion must be a boolean")
    local rounds = state.rounds
    if completed then
        rounds.completed = rounds.completed + 1
        mark(state, "ROUND_COMPLETED")
    else
        rounds.abandoned = rounds.abandoned + 1
    end
    rounds.totalSeconds = rounds.totalSeconds + durationSeconds
    if durationSeconds > rounds.longestSeconds then
        rounds.longestSeconds = durationSeconds
    end
    return rounds.completed + rounds.abandoned
end

function TelemetryFunnel.roundCount(state)
    assert(type(state) == "table", "Missing funnel state")
    return state.rounds.completed + state.rounds.abandoned
end

-- Share of rounds that never reached RESULTS, in [0, 1]. Zero rounds is
-- reported as 0 rather than a division by zero.
function TelemetryFunnel.abandonRate(state)
    local total = TelemetryFunnel.roundCount(state)
    if total == 0 then return 0 end
    return state.rounds.abandoned / total
end

function TelemetryFunnel.averageRoundSeconds(state)
    local total = TelemetryFunnel.roundCount(state)
    if total == 0 then return 0 end
    return state.rounds.totalSeconds / total
end

-- Detached copy: a caller can never mutate the live counters by accident.
function TelemetryFunnel.snapshot(state)
    assert(type(state) == "table", "Missing funnel state")
    local weapons = {}
    for id, kills in pairs(state.weapons) do
        table.insert(weapons, { id = id, kills = kills })
    end
    table.sort(weapons, function(a, b)
        if a.kills == b.kills then return a.id < b.id end
        return a.kills > b.kills
    end)
    local stages = {}
    for _, stage in ipairs(TelemetryFunnel.STAGES) do
        stages[stage] = state.stages[stage] == true
    end
    return {
        stages = stages,
        uniquePlayers = state.trackedPlayers,
        kills = state.kills,
        weapons = weapons,
        rounds = {
            completed = state.rounds.completed,
            abandoned = state.rounds.abandoned,
            averageSeconds = TelemetryFunnel.averageRoundSeconds(state),
            longestSeconds = state.rounds.longestSeconds,
            abandonRate = TelemetryFunnel.abandonRate(state),
        },
    }
end

return TelemetryFunnel
