-- The replicated generation identifies both the mode and the session.
local PracticeMode = {}
PracticeMode.ATTRIBUTE = "IronYardRangeSession"
PracticeMode.STATS_ATTRIBUTE = "IronYardRangeStats"
PracticeMode.DRILL_ATTRIBUTE = "IronYardRangeDrill"
PracticeMode.DRILL_COUNTDOWN = 3
PracticeMode.DRILL_SECONDS = 30

function PracticeMode.session(player)
    return player:GetAttribute(PracticeMode.ATTRIBUTE) or 0
end

function PracticeMode.active(player)
    return PracticeMode.session(player) % 2 == 1
end

function PracticeMode.matches(player, session)
    local current = PracticeMode.session(player)
    return session == current or (session == nil and current == 0)
end

function PracticeMode.stats(player)
    local snapshot = player:GetAttribute(PracticeMode.STATS_ATTRIBUTE)
    if type(snapshot) == "string" then
        local separator = snapshot:find(";", 1, true)
        local totals = separator and snapshot:sub(1, separator - 1) or snapshot
        local session, shots, hits, targets, revision = totals:match("^(%d+):(%d+):(%d+):(%d+):(%d+)$")
        if tonumber(session) == PracticeMode.session(player) then
            return tonumber(shots), tonumber(hits), tonumber(targets), tonumber(revision),
                separator and snapshot:sub(separator)
        end
    end
    return 0, 0, 0
end

function PracticeMode.weaponStats(player)
    local _, _, _, _, details = PracticeMode.stats(player)
    local stats = {}
    if details then
        for weaponId, shots, hits, targets in details:gmatch(";([%w_]+):(%d+):(%d+):(%d+)") do
            stats[weaponId] = { shots = tonumber(shots), hits = tonumber(hits), targetsDown = tonumber(targets) }
        end
    end
    return stats
end

function PracticeMode.accuracy(shots, hits)
    return shots > 0 and math.round(100 * hits / shots) or nil
end

function PracticeMode.drill(player)
    local snapshot = player:GetAttribute(PracticeMode.DRILL_ATTRIBUTE)
    if type(snapshot) ~= "string" then return nil end
    local session, id, starts, ends, shots, hits, targets, done = snapshot:match(
        "^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):([01])$")
    if tonumber(session) ~= PracticeMode.session(player) then return nil end
    return {
        id = tonumber(id), startsAt = tonumber(starts) / 1000, endsAt = tonumber(ends) / 1000,
        shots = tonumber(shots), hits = tonumber(hits), targetsDown = tonumber(targets), finished = done == "1",
    }
end

function PracticeMode.drillReadout(drill)
    local accuracy = PracticeMode.accuracy(drill.shots, drill.hits)
    return string.format("%d DOWN  ·  %d/%d HITS  ·  %s", drill.targetsDown, drill.hits, drill.shots,
        accuracy and (accuracy .. "%") or "—")
end

return PracticeMode
