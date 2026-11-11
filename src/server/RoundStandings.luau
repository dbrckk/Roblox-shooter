-- IRON YARD / pure, deterministic free-for-all results.
-- No Roblox services; can be tested with the standalone Luau interpreter.
local RoundStandings = {}

-- championUserId is an optional, verified duel-forfeit survivor.
-- It is never passed for normal FFA or score-limit rounds. Keep the actual
-- bout scores visible, but show the surviving champion first, with rank 1.
function RoundStandings.build(rawEntries, roundNumber, championUserId)
    local rows = {}
    for _, entry in ipairs(rawEntries) do
        local kills = math.max(0, math.floor(tonumber(entry.eliminations) or 0))
        local deaths = math.max(0, math.floor(tonumber(entry.deaths) or 0))
        local isBot = entry.bot == true
        -- Studio local test users have negative IDs, unlike public players.
        local rawId = tonumber(entry.userId)
        local validId = rawId and rawId == rawId and rawId ~= 0
            and math.abs(rawId) < math.huge and rawId % 1 == 0
        local userId = (not isBot and validId) and rawId or 0
        table.insert(rows, {
            name = tostring(entry.name or "Operator"),
            eliminations = kills,
            deaths = deaths,
            bot = isBot,
            userId = userId,
            sortKey = tonumber(entry.sortKey) or 0,
        })
    end
    local championRow = nil
    if type(championUserId) == "number"
        and championUserId == championUserId
        and championUserId ~= 0 and math.abs(championUserId) < math.huge
        and championUserId % 1 == 0 then
        for _, entry in ipairs(rows) do
            if not entry.bot and entry.userId == championUserId then
                championRow = entry
                break
            end
        end
    end
    table.sort(rows, function(a, b)
        if championRow then
            if a == championRow then return true end
            if b == championRow then return false end
        end
        if a.eliminations ~= b.eliminations then
            return a.eliminations > b.eliminations
        end
        if a.deaths ~= b.deaths then return a.deaths < b.deaths end
        if a.bot ~= b.bot then return not a.bot end
        return a.sortKey < b.sortKey
    end)

    local lastKills = nil
    local lastRank = 0
    for index, entry in ipairs(rows) do
        if entry.eliminations ~= lastKills then lastRank = index end
        entry.rank = championRow and index or lastRank
        lastKills = entry.eliminations
        entry.sortKey = nil -- not part of the replicated public result
    end

    -- Equal elimination counts mean a DRAW, even when deaths differ.
    local first = rows[1]
    local uniqueLead = first and first.eliminations > 0
        and (not rows[2] or first.eliminations > rows[2].eliminations)
    return {
        round = roundNumber,
        standings = rows,
        winner = championRow and championRow.name
            or (uniqueLead and first.name or "DRAW"),
        winnerUserId = championRow and championRow.userId
            or (uniqueLead and first.userId or 0),
    }
end

return RoundStandings
