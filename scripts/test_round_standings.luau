local R = require("../src/server/RoundStandings")

local function row(name, kills, deaths, bot, userId, key)
    return {
        name = name, eliminations = kills, deaths = deaths,
        bot = bot, userId = userId, sortKey = key,
    }
end

local input = {
    row("Rook", 8, 4, true, 0, 2),
    row("Echo", 12, 6, false, 781, 781),
    row("Echo", 6, 1, false, 221, 221),
    row("Hawk", 8, 3, true, 0, 1),
}
local result = R.build(input, 7)
assert(result.round == 7 and result.winner == "Echo", "Unique human winner")
assert(result.winnerUserId == 781, "Winner identity must use userId, never display name")
assert(result.standings[1].userId == 781, "Champion occupies the first row")
assert(result.standings[2].name == "Hawk", "Deaths order tied scores")
assert(result.standings[2].rank == 2 and result.standings[3].rank == 2,
    "Equal eliminations share a competition rank")
assert(result.standings[4].rank == 4, "Following rank skips tied positions")
assert(result.standings[1].sortKey == nil, "Internal tie-break key is not public")
input[2].eliminations = 0
assert(result.standings[1].eliminations == 12,
    "Final results are a detached snapshot, not references to live scores")

local tied = R.build({
    row("A", 15, 2, false, 1, 1),
    row("B", 15, 3, false, 2, 2),
}, 3)
assert(tied.winner == "DRAW" and tied.winnerUserId == 0, "Equal kills cannot grant a victory")
assert(tied.standings[1].rank == 1 and tied.standings[2].rank == 1, "Shared first place")

local botWin = R.build({
    row("Player", 8, 3, false, 123, 123),
    row("[BOT] Hawk", 15, 1, true, 0, 1),
}, 4)
assert(botWin.winner == "[BOT] Hawk" and botWin.winnerUserId == 0,
    "An AI can win without receiving player XP")

local zero = R.build({ row("Solo", 0, 0, false, 345, 345) }, 5)
assert(zero.winner == "DRAW" and zero.winnerUserId == 0,
    "Zero eliminations cannot win")
local studio = R.build({
    row("StudioGuest1", 5, 0, false, -1, -1),
    row("StudioGuest2", 2, 2, false, -2, -2),
}, 10)
assert(studio.standings[1].userId == -1
    and studio.standings[2].userId == -2)
assert(studio.winnerUserId == -1)
-- Forfeit from a duel: the original surviving player ranks first even
-- when they had fewer actual bout wins. Do not fake their scores.
local forfeitRows = {
    row("Disconnected A", 4, 0, false, 71, 71),
    row("Surviving B", 2, 0, false, 72, 72),
}
local forfeit = R.build(forfeitRows, 6, 72)
assert(forfeit.winner == "Surviving B" and forfeit.winnerUserId == 72)
assert(forfeit.standings[1].userId == 72
    and forfeit.standings[1].rank == 1 and forfeit.standings[1].eliminations == 2)
assert(forfeit.standings[2].userId == 71
    and forfeit.standings[2].rank == 2 and forfeit.standings[2].eliminations == 4)
-- Normal FFA/duel score-limit uses ordinary scoring, not an arbitrary ID.
local ordinary = R.build(forfeitRows, 6)
assert(ordinary.winnerUserId == 71 and ordinary.standings[1].userId == 71)
local ghost = R.build(forfeitRows, 6, 999)
assert(ghost.winnerUserId == 71 and ghost.standings[1].userId == 71)
local fake = R.build(forfeitRows, 6, 0/0)
assert(fake.winnerUserId == 71)
local invalid = R.build(forfeitRows, 6, 0)
assert(invalid.winnerUserId == 71)
local emptyForfeit = R.build({}, 6, 72)
assert(emptyForfeit.winner == "DRAW" and emptyForfeit.winnerUserId == 0)
-- Two equal bout totals still show the confirmed survivor alone as #1.
local tiedForfeit = R.build({
    row("A", 3, 1, false, 71, 71),
    row("B", 3, 0, false, 72, 72),
}, 6, 71)
assert(tiedForfeit.winnerUserId == 71 and tiedForfeit.standings[1].rank == 1)
assert(tiedForfeit.standings[2].rank == 2)

local empty = R.build({}, 5)
assert(empty.winner == "DRAW" and #empty.standings == 0, "Empty lobby")
print("IRON YARD final scoreboard ranking, ties, rewards and snapshot isolation: OK")
