-- IRON YARD / strict server-wide bound for physically running ComputeAsync.
-- Tickets represent actual outstanding engine calls, NOT logical bot jobs.
-- A timed-out bot can abandon its result, but the engine call still owns its
-- slot until its asynchronous callback returns. This prevents hidden overlap.
local Budget = {}

Budget.MAX_IN_FLIGHT = 2
Budget.MIN_START_GAP = 0.18
Budget.LEASE_SECONDS = 5.8 -- discard result after this age, not the active slot
Budget.MOVE_REFRESH_SECONDS = 1.15
Budget.MOVE_DELTA = 1.25

local function finite(value)
    return type(value) == "number" and value == value
        and value < math.huge and value > -math.huge
end

function Budget.new()
    return { leases = {}, lastStart = -math.huge, nextToken = 0 }
end

-- Claims never yield. Outstanding calls are not automatically reaped:
-- doing so would let a hung ComputeAsync keep running while new ones start.
function Budget.claim(state, now)
    if not finite(now) then return nil end
    if now - state.lastStart < Budget.MIN_START_GAP then return nil end
    local active = 0
    for _ in pairs(state.leases) do
        active += 1
    end
    if active >= Budget.MAX_IN_FLIGHT then return nil end
    state.nextToken += 1
    local token = state.nextToken
    state.leases[token] = now
    state.lastStart = now
    return token
end

-- Completion can be too late to apply to a bot whose goal has changed.
-- Stale results are discarded while the slot is still released separately.
function Budget.valid(state, token, now)
    local startedAt = state.leases[token]
    return startedAt ~= nil and finite(now) and now >= startedAt
        and now - startedAt < Budget.LEASE_SECONDS
end

function Budget.release(state, token)
    if state.leases[token] == nil then return false end
    state.leases[token] = nil
    return true
end

function Budget.inFlight(state)
    local n = 0
    for _ in pairs(state.leases) do n += 1 end
    return n
end

function Budget.shouldIssueMove(goalDistance, age)
    if not finite(goalDistance) or not finite(age) then return true end
    if age < 0 or goalDistance < 0 then return true end
    return goalDistance >= Budget.MOVE_DELTA
        or age >= Budget.MOVE_REFRESH_SECONDS
end

return Budget
