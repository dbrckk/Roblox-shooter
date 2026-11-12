-- IRON YARD / pure per-player, per-RemoteEvent token-bucket admission.
-- Only server code owns and advances time; clients cannot set quotas.
local Policy = {}
local PROFILES = {
    -- Burst capacity covers fast weapon swaps and touchscreen UI changes.
    EquipWeapon = { rate = 8, burst = 8 },
    FireWeapon = { rate = 18, burst = 12 },
    ReloadWeapon = { rate = 5, burst = 5 },
    SetSprinting = { rate = 10, burst = 6 },
    SetAiming = { rate = 10, burst = 8 },
    SetDuelReady = { rate = 3, burst = 3 },
    -- Move updates are sent at ~12.5 Hz while boost/wallrun is active.
    MovementAction = { rate = 34, burst = 22 },
    MovementUpdate = { rate = 22, burst = 14 },
    -- Safety-critical stops have their OWN budget so a saturated movement
    -- channel cannot prevent release of active thrust/wall-running.
    MovementStop = { rate = 8, burst = 6 },
    Diagnostics = { rate = 3, burst = 3 },
}

-- Return a snapshot, never the live quota configuration. Callers (including
-- diagnostics and test helpers) must not be able to raise a server admission
-- limit by mutating a table returned from this shared module.
function Policy.profile(channel)
    local config = PROFILES[channel]
    if not config then return nil end
    return { rate = config.rate, burst = config.burst }
end

local function finite(value)
    return type(value) == "number" and value == value
        and value < math.huge and value > -math.huge
end

-- Consume a token only for a valid, non-replayed time. A rejected flood
-- cannot drive the bucket negative or indefinitely move its refill clock.
function Policy.allow(bucket, channel, now)
    local profile = PROFILES[channel]
    if not profile or type(bucket) ~= "table" or not finite(now) then return false end
    local state = bucket[channel]
    if not state then
        state = { tokens = profile.burst, at = now }
        bucket[channel] = state
    end
    if now < state.at then return false end
    local delta = math.min(now - state.at, 60)
    state.tokens = math.min(profile.burst, state.tokens + delta * profile.rate)
    state.at = now
    if state.tokens < 1 then return false end
    state.tokens -= 1
    return true
end

-- Classifying by exact action (and not by untrusted payload structure)
-- reserves emergency stop capacity under high-volume movement updates.
function Policy.channelForAction(action)
    if action == "BoostStop" or action == "StopWallRun" then
        return "MovementStop"
    end
    if action == "BoostUpdate" or action == "WallRunUpdate" then
        return "MovementUpdate"
    end
    return nil
end

return Policy
