-- IRON YARD / pure, bounded 1v1 public score and result readout.
-- Never uses local predicted shots or raw/unverified client scores.
local Readout = {}
local function validId(n)
    return type(n) == "number" and n == n and n > 0
        and n < math.huge and n % 1 == 0
end
local function score(n)
    if type(n) ~= "number" or n ~= n or n < 0 or n > 5
        or n % 1 ~= 0 then return nil end
    return n
end
function Readout.scores(userId, aId, bId, aWins, bWins)
    if not validId(userId) or not validId(aId) or not validId(bId)
        or aId == bId then return nil end
    local a,b = score(aWins), score(bWins)
    if a == nil or b == nil then return nil end
    if userId == aId then return a,b end
    if userId == bId then return b,a end
    return nil
end
function Readout.boutLabel(result, userId, aId, bId)
    if not validId(userId) or not validId(aId)
        or not validId(bId) or aId == bId then return nil end
    if userId ~= aId and userId ~= bId then return nil end
    if result == "DRAW" then return "ROUND DRAW" end
    if result ~= "A" and result ~= "B" then return nil end
    local winningId = result == "A" and aId or bId
    return userId == winningId and "ROUND WON" or "ROUND LOST"
end
return Readout
