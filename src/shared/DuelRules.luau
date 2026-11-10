-- IRON YARD: pure 1v1 match adjudication (no game/Roblox dependencies).
local Duel = {}
Duel.WIN_LIMIT = 5
Duel.MAX_BOUTS = 24
Duel.RECOVERY_TIMEOUT_SECONDS = 20
Duel.PREP_SECONDS = 3

local function finite(n)
    return type(n) == "number" and n == n and n >= 0 and n < math.huge
end
function Duel.canStart(players, readyA, readyB)
    return type(players) == "number" and players == 2
        and readyA == true and readyB == true
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
function Duel.advance(scoreA, scoreB, bouts, result)
    if not finite(scoreA) or not finite(scoreB) or not finite(bouts)
        or scoreA % 1 ~= 0 or scoreB % 1 ~= 0 or bouts % 1 ~= 0
        or scoreA > Duel.WIN_LIMIT or scoreB > Duel.WIN_LIMIT
        or bouts > Duel.MAX_BOUTS
        or (result ~= "A" and result ~= "B" and result ~= "DRAW")
        then return nil end
    if result == "A" then scoreA += 1
    elseif result == "B" then scoreB += 1 end
    bouts += 1
    local completed = scoreA >= Duel.WIN_LIMIT or scoreB >= Duel.WIN_LIMIT
        or bouts >= Duel.MAX_BOUTS
    local winner = scoreA >= Duel.WIN_LIMIT and "A"
        or scoreB >= Duel.WIN_LIMIT and "B" or "DRAW"
    return scoreA, scoreB, bouts, completed, completed and winner or nil
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
    return playerCount == 2 and type(userId) == "number"
        and userId > 0 and a ~= b and (userId == a or userId == b)
end
return Duel
