-- IRON YARD: pure 1v1 match adjudication (no game/Roblox dependencies).
local Duel = {}
Duel.WIN_LIMIT = 5
Duel.MAX_BOUTS = 24
Duel.RECOVERY_TIMEOUT_SECONDS = 20
Duel.PREP_SECONDS = 3

local function finite(n)
    return type(n) == "number" and n == n and n >= 0 and n < math.huge
end
-- Compare Roblox Player instances, not UserIds; Studio IDs may be negative.
function Duel.sameParticipants(players, first, second)
    return type(players) == "table" and #players == 2
        and first ~= nil and second ~= nil and first ~= second
        and ((players[1] == first and players[2] == second)
            or (players[1] == second and players[2] == first))
end

-- An abandoned 1v1 is won only by the ORIGINAL surviving combatant.
-- A stale Player reference is truthy even after its owner disconnects;
-- never infer the winner from the existence of the two saved references.
-- Spectators, replacement occupants and empty lobbies cannot claim a win.
function Duel.forfeitSide(activePlayers, first, second)
    if type(activePlayers) ~= "table" or #activePlayers ~= 1
        or first == nil or second == nil or first == second then
        return nil
    end
    if activePlayers[1] == first then return "A" end
    if activePlayers[1] == second then return "B" end
    return nil
end

function Duel.canStart(players, readyA, readyB)
    return type(players) == "number" and players == 2
        and readyA == true and readyB == true
end
-- A replacement character must not count as an extra life during the bout.
function Duel.healthForBout(expectedCharacter, actualCharacter, health, maxHealth)
    if expectedCharacter == nil or expectedCharacter ~= actualCharacter then
        return 0, 100
    end
    if not finite(maxHealth) or maxHealth <= 0 then return 0, 100 end
    if not finite(health) then return 0, maxHealth end
    return math.clamp(health, 0, maxHealth), maxHealth
end

function Duel.boutWinner(healthA, maximumA, healthB, maximumB, expired)
    if not finite(healthA) or not finite(healthB)
        or not finite(maximumA) or not finite(maximumB)
        or maximumA <= 0 or maximumB <= 0 then return nil end
    if healthA <= 0 and healthB <= 0 then return "DRAW" end
    if healthA <= 0 then return "B" end
    if healthB <= 0 then return "A" end
    if expired ~= true then return nil end
    local a = math.min(1, healthA / maximumA)
    local b = math.min(1, healthB / maximumB)
    if math.abs(a - b) < 0.00001 then return "DRAW" end
    return a > b and "A" or "B"
end
-- A duel normally finishes at five wins. A hard bout cap prevents
-- unbounded series of draws, but at that cap a real points leader must
-- win rather than be incorrectly declared tied. Return the terminal reason
-- as a sixth value so XP eligibility cannot drift from the scoring rule.
function Duel.advance(scoreA, scoreB, bouts, result)
    if not finite(scoreA) or not finite(scoreB) or not finite(bouts)
        or scoreA % 1 ~= 0 or scoreB % 1 ~= 0 or bouts % 1 ~= 0
        or scoreA >= Duel.WIN_LIMIT or scoreB >= Duel.WIN_LIMIT
        or bouts >= Duel.MAX_BOUTS
        or scoreA + scoreB > bouts
        or (result ~= "A" and result ~= "B" and result ~= "DRAW")
        then return nil end

    if result == "A" then scoreA += 1
    elseif result == "B" then scoreB += 1 end
    bouts += 1

    local reachedWinLimit = scoreA >= Duel.WIN_LIMIT
        or scoreB >= Duel.WIN_LIMIT
    local reachedBoutLimit = bouts >= Duel.MAX_BOUTS
    local completed = reachedWinLimit or reachedBoutLimit
    local winner = nil
    local reason = nil
    if completed then
        if scoreA > scoreB then winner = "A"
        elseif scoreB > scoreA then winner = "B"
        else winner = "DRAW" end
        reason = reachedWinLimit and "SCORE_LIMIT" or "BOUT_LIMIT"
    end
    return scoreA, scoreB, bouts, completed, winner, reason
end
-- A missing avatar or fully obstructed duel spawn cannot hang a public
-- server forever in the between-bout phase. Server clock only.
function Duel.recoveryExpired(since, now)
    if not finite(since) or not finite(now) then return true end
    return now - since >= Duel.RECOVERY_TIMEOUT_SECONDS
end

-- Match transitions are valid only for the same two live Roblox characters.
-- Identity checks are pure; no engine service can spoof the original pair.
function Duel.prepValid(expectedA, actualA, readyA, expectedB, actualB, readyB)
    return expectedA ~= nil and expectedB ~= nil and expectedA ~= expectedB
        and expectedA == actualA and expectedB == actualB
        and readyA == true and readyB == true
end

function Duel.canFight(mode, userId, a, b, playerCount)
    if mode ~= "DUEL" then return true end
    local function validId(id)
        return type(id) == "number" and id == id and id ~= 0
            and math.abs(id) < math.huge and id % 1 == 0
    end
    return playerCount == 2 and validId(userId)
        and validId(a) and validId(b) and a ~= b
        and (userId == a or userId == b)
end
return Duel
