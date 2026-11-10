-- IRON YARD / pure client-only visual detail visibility policy.
-- Spatial groups accelerate far-field decoration checks without touching
-- gameplay colliders, server art replication or Core silhouettes.
local Policy = {}

-- Detail animations move at most 5.6 studs from their authoring origins.
-- Expand each group's AABB by eight studs to remain conservative while
-- animated gantry parts move locally.
Policy.MotionMargin = 8
Policy.CellSize = 48

local function finite(n)
    return type(n) == "number" and n == n
        and n < math.huge and n > -math.huge
end

-- Limit the one-time art inventory initialization per Heartbeat. No
-- per-frame background LOD loop or gameplay scheduling is introduced.
function Policy.bootstrapBatch(preset, isTouch)
    if preset == "ECO" then return isTouch and 48 or 96 end
    if isTouch then return preset == "QUALITY" and 128 or 96 end
    return 192
end

-- The ordinary poll remains 1Hz. Fast movement may request up to 4Hz
-- (never once per frame), preventing a one-second delayed LOD reveal.
Policy.ArtPollSeconds = 1
Policy.FastPollSeconds = 0.25
Policy.FastTravelStuds = 20

local function validEye(eye)
    return eye and finite(eye.X) and finite(eye.Y) and finite(eye.Z)
end

function Policy.shouldPollArt(now, lastAt, eye, lastEye, preset, lastPreset)
    if not finite(now) then return false end
    if lastAt == nil or not finite(lastAt) or now < lastAt then return true end
    local elapsed = now - lastAt
    if elapsed >= Policy.ArtPollSeconds then return true end
    if elapsed < Policy.FastPollSeconds then return false end
    if preset ~= lastPreset then return true end
    if validEye(eye) ~= validEye(lastEye) then return true end
    if not validEye(eye) then return false end
    local dx, dy, dz = eye.X - lastEye.X, eye.Y - lastEye.Y, eye.Z - lastEye.Z
    return dx * dx + dy * dy + dz * dz
        >= Policy.FastTravelStuds * Policy.FastTravelStuds
end

-- When details stream in during boosting, never make the admission
-- decision with the eye position captured by the previous 1Hz art sweep.
function Policy.streamedHidden(position, liveEye, fallbackEye, hideBeyond, showBefore)
    local eye = validEye(liveEye) and liveEye or fallbackEye
    if not validEye(eye) or not validEye(position) then return false end
    local dx, dy, dz = position.X - eye.X, position.Y - eye.Y, position.Z - eye.Z
    return Policy.hiddenSquared(dx * dx + dy * dy + dz * dz,
        false, hideBeyond, showBefore)
end

function Policy.limits(preset, isTouch)
    local bot, art
    if preset == "ECO" then
        bot, art = 38, 70
    elseif preset == "QUALITY" then
        bot = isTouch and 112 or 170
        art = isTouch and 165 or 245
    else
        bot = isTouch and 65 or 120
        art = isTouch and 110 or 195
    end
    return {
        botHide = bot, botShow = bot - 12,
        artHide = art, artShow = art - 16,
    }
end

function Policy.cellKey(x, z)
    if not finite(x) or not finite(z) then return nil end
    return string.format("%d:%d",
        math.floor(x / Policy.CellSize),
        math.floor(z / Policy.CellSize))
end

function Policy.extendBounds(bounds, position)
    local x, y, z = position.X, position.Y, position.Z
    if not finite(x) or not finite(y) or not finite(z) then return false end
    bounds.minX = math.min(bounds.minX or x, x)
    bounds.maxX = math.max(bounds.maxX or x, x)
    bounds.minY = math.min(bounds.minY or y, y)
    bounds.maxY = math.max(bounds.maxY or y, y)
    bounds.minZ = math.min(bounds.minZ or z, z)
    bounds.maxZ = math.max(bounds.maxZ or z, z)
    return true
end

local function outsideDistance(v, lower, upper)
    if v < lower then return lower - v end
    if v > upper then return v - upper end
    return 0
end

-- Return HIDE only when EVERY authoring origin in a sector is past the
-- far threshold; SHOW only when EVERY origin is within the near threshold.
-- Else MIXED triggers exact per-part checks with the old hysteresis.
-- Padding protects locally-moving cosmetic gantries from incorrect culling.
function Policy.classify(bounds, eye, hideBeyond, showBefore)
    if not bounds.minX or not finite(eye.X) or not finite(eye.Y)
        or not finite(eye.Z) or not finite(hideBeyond)
        or not finite(showBefore) then return "MIXED" end
    local pad = Policy.MotionMargin
    local minX, maxX = bounds.minX - pad, bounds.maxX + pad
    local minY, maxY = bounds.minY - pad, bounds.maxY + pad
    local minZ, maxZ = bounds.minZ - pad, bounds.maxZ + pad

    local dx = outsideDistance(eye.X, minX, maxX)
    local dy = outsideDistance(eye.Y, minY, maxY)
    local dz = outsideDistance(eye.Z, minZ, maxZ)
    if dx * dx + dy * dy + dz * dz > hideBeyond * hideBeyond then
        return "HIDE"
    end

    local mx = math.max(math.abs(eye.X - minX), math.abs(eye.X - maxX))
    local my = math.max(math.abs(eye.Y - minY), math.abs(eye.Y - maxY))
    local mz = math.max(math.abs(eye.Z - minZ), math.abs(eye.Z - maxZ))
    if mx * mx + my * my + mz * mz < showBefore * showBefore then
        return "SHOW"
    end
    return "MIXED"
end

-- Preserve previous hysteresis at each actual detail part. Using squared
-- distance avoids a square root for hundreds of pieces per tick.
function Policy.hiddenSquared(distanceSquared, wasHidden, hideBeyond, showBefore)
    if not finite(distanceSquared) or distanceSquared < 0 then
        return wasHidden == true
    end
    if wasHidden then
        return distanceSquared > showBefore * showBefore
    end
    return distanceSquared > hideBeyond * hideBeyond
end

return Policy
