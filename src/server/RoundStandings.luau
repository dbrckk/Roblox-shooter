-- IRON YARD / pure, deterministic free-for-all results.
-- No Roblox services; can be tested with the standalone Luau interpreter.
local RoundStandings = {}

function RoundStandings.build(rawEntries, roundNumber)
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
    table.sort(rows, function(a, b)
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
        entry.rank = lastRank
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
        winner = uniqueLead and first.name or "DRAW",
        winnerUserId = uniqueLead and first.userId or 0,
    }
end

return RoundStandings
