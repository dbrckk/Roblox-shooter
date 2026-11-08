-- IRON YARD / deterministic, shared server-side navmesh workload budget.
-- Pure Luau so resource limits and movement refresh policy can run in CI.
-- Authoritative collision checks and path accuracy stay in BotNavigation.
local Budget = {}

Budget.MAX_IN_FLIGHT = 2
Budget.MIN_START_GAP = 0.18
Budget.LEASE_SECONDS = 5.8
Budget.MOVE_REFRESH_SECONDS = 1.15
Budget.MOVE_DELTA = 1.25

local function finite(value)
    return type(value) == "number" and value == value
        and value < math.huge and value > -math.huge
end

function Budget.new()
    return { leases = {}, lastStart = -math.huge, nextToken = 0 }
end

local function reap(state, now)
    for token, startedAt in pairs(state.leases) do
        if now - startedAt >= Budget.LEASE_SECONDS then
            state.leases[token] = nil
        end
    end
end

-- A claim never waits/yields. When two bots are already calculating paths,
-- another bot can still execute its safe local detour while its request is
-- deferred until the next ordinary 5Hz tactical tick.
function Budget.claim(state, now)
    if not finite(now) then return nil end
    reap(state, now)
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

function Budget.valid(state, token, now)
    local startedAt = state.leases[token]
    return startedAt ~= nil and finite(now) and now >= startedAt
        and now - startedAt < Budget.LEASE_SECONDS
end

-- Only the owning asynchronous completion releases its ticket. Old,
-- abandoned ComputeAsync requests are never counted as new work.
function Budget.release(state, token)
    if state.leases[token] == nil then return false end
    state.leases[token] = nil
    return true
end

-- MoveTo restarts its internal timeout whenever reissued. Most unchanged
-- waypoints need neither a 5Hz resend nor a forced collision response.
-- A new or materially changed goal is always sent immediately; unchanged
-- goals are refreshed well before Roblox's movement timeout.
function Budget.shouldIssueMove(goalDistance, age)
    if not finite(goalDistance) or not finite(age) then return true end
    if age < 0 or goalDistance < 0 then return true end
    return goalDistance >= Budget.MOVE_DELTA
        or age >= Budget.MOVE_REFRESH_SECONDS
end

return Budget
