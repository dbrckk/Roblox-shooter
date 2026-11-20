-- The replicated generation identifies both the mode and the session.
local WeaponConfig = if script then require(script.Parent:WaitForChild("WeaponConfig")) else require("./WeaponConfig")
local PracticeMode = {}
PracticeMode.ATTRIBUTE = "IronYardRangeSession"
PracticeMode.STATS_ATTRIBUTE = "IronYardRangeStats"
PracticeMode.DRILL_ATTRIBUTE = "IronYardRangeDrill"
PracticeMode.DRILL_MODE_ATTRIBUTE = "IronYardRangeDrillMode"
PracticeMode.DRILL_BEST_ATTRIBUTE = "IronYardRangeDrillBest"
PracticeMode.DRILL_BEST_STATUS_ATTRIBUTE = "IronYardRangeDrillBestStatus"
PracticeMode.OPEN_DRILL = "Open"
PracticeMode.DRILL_MODES = table.freeze({ PracticeMode.OPEN_DRILL, table.unpack(WeaponConfig.Order) })
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

function PracticeMode.validDrillMode(mode)
    return type(mode) == "string" and table.find(PracticeMode.DRILL_MODES, mode) ~= nil
end

function PracticeMode.drillMode(player)
    return player:GetAttribute(PracticeMode.DRILL_MODE_ATTRIBUTE) or PracticeMode.OPEN_DRILL
end

function PracticeMode.drillLabel(mode)
    if mode == PracticeMode.OPEN_DRILL then return "OPEN" end
    if mode == "Knife" then return "KNIFE" end
    local name = WeaponConfig.get(mode).displayName
    return string.upper(name:match("^(.-) | ") or name)
end

function PracticeMode.nextDrillMode(mode)
    local index = table.find(PracticeMode.DRILL_MODES, mode)
    return index and PracticeMode.DRILL_MODES[index + 1] or PracticeMode.OPEN_DRILL
end

function PracticeMode.drill(player)
    local snapshot = player:GetAttribute(PracticeMode.DRILL_ATTRIBUTE)
    if type(snapshot) ~= "string" then return nil end
    local score, baseline = snapshot:match("^([^|]+)|(.+)$")
    score = score or snapshot
    local body, mode = score:match("^(.*):([%a][%w_]*)$")
    mode = mode or PracticeMode.OPEN_DRILL
    local session, id, starts, ends, shots, hits, targets, result = (body or score):match(
        "^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):([012])$")
    if tonumber(session) ~= PracticeMode.session(player) or not PracticeMode.validDrillMode(mode) then return nil end
    local previousBest = PracticeMode.decodeDrillBest(baseline)
    return {
        id = tonumber(id), startsAt = tonumber(starts) / 1000, endsAt = tonumber(ends) / 1000,
        shots = tonumber(shots), hits = tonumber(hits), targetsDown = tonumber(targets),
        finished = result ~= "0", newBest = result == "2", mode = mode,
        previousBest = previousBest, baselineKnown = baseline == "-" or previousBest ~= nil,
    }
end

function PracticeMode.lockedDrillWeapon(player)
    local drill = PracticeMode.drill(player)
    return drill and not drill.finished and drill.mode ~= PracticeMode.OPEN_DRILL and drill.mode or nil
end

function PracticeMode.permitsWeapon(drill, weaponId)
    return not drill or drill.finished or drill.mode == PracticeMode.OPEN_DRILL or drill.mode == weaponId
end

function PracticeMode.decodeDrillBest(snapshot)
    if type(snapshot) ~= "string" then return nil end
    local shots, hits, targets = snapshot:match("^(%d+):(%d+):(%d+)$")
    shots, hits, targets = tonumber(shots), tonumber(hits), tonumber(targets)
    if not shots or shots > 10000 or hits > shots or targets < 1 or targets > hits * 8 then return nil end
    return { shots = shots, hits = hits, targetsDown = targets }
end

function PracticeMode.encodeDrillBest(score)
    return string.format("%d:%d:%d", score.shots, score.hits, score.targetsDown)
end

function PracticeMode.drillBestAttributes(mode)
    local suffix = mode and mode ~= PracticeMode.OPEN_DRILL and ("_" .. mode) or ""
    return PracticeMode.DRILL_BEST_ATTRIBUTE .. suffix, PracticeMode.DRILL_BEST_STATUS_ATTRIBUTE .. suffix
end

function PracticeMode.drillBest(player, mode)
    local attribute, status = PracticeMode.drillBestAttributes(mode)
    return PracticeMode.decodeDrillBest(player:GetAttribute(attribute)), player:GetAttribute(status)
end

function PracticeMode.betterDrillBest(score, best)
    return not best or score.targetsDown > best.targetsDown or (score.targetsDown == best.targetsDown
        and score.hits * best.shots > best.hits * score.shots)
end

function PracticeMode.drillReadout(drill)
    local accuracy = PracticeMode.accuracy(drill.shots, drill.hits)
    return string.format("%d DOWN  ·  %d/%d HITS  ·  %s", drill.targetsDown, drill.hits, drill.shots,
        accuracy and (accuracy .. "%") or "—")
end

function PracticeMode.drillBestGap(drill, best)
    local targets = drill.targetsDown - best.targetsDown
    if targets ~= 0 then return string.format("%+d DOWN VS BEST", targets) end
    -- Match the exact precision tie-breaker used by the server, even when
    -- the two rounded percentages shown in the score rows are identical.
    local numerator = drill.hits * best.shots - best.hits * drill.shots
    if numerator == 0 then return "BEST MATCHED" end
    local points = math.abs(numerator) * 100 / (drill.shots * best.shots)
    if points < 0.1 then
        return numerator > 0 and "<0.1 ACC POINTS ABOVE BEST" or "<0.1 ACC POINTS BELOW BEST"
    end
    local sign = numerator > 0 and "+" or "-"
    return string.format("%s%.1f ACC POINTS VS BEST", sign, points)
end

return PracticeMode
