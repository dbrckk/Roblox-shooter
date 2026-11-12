-- IRON YARD / allocation-free, purely cosmetic B-8 reload choreography.
-- The server refills the magazine atomically; these repeated visual insertions
-- do not grant ammunition, delay fire or create per-frame objects.
local Visual = {}

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

-- Return the normalized progress of the currently visible shell or -1.
-- Without a count, preserve the legacy single-shell timings for callers.
-- With a server-snapshot deficit, show at most six distinct insertions,
-- reusing one physical PBR/Part shell between beats.
function Visual.phase(progress, missingRounds)
    if not finite(progress) then return -1 end
    if missingRounds == nil then
        if progress < 0.27 or progress > 0.74 then return -1 end
        return math.clamp((progress - 0.27) / 0.47, 0, 1)
    end
    if not finite(missingRounds) or missingRounds < 1 then return -1 end
    if progress < 0.18 or progress >= 0.88 then return -1 end
    local count = math.clamp(math.floor(missingRounds), 1, 6)
    local beat = (progress - 0.18) / 0.70 * count
    local withinBeat = beat - math.floor(beat)
    -- Hidden return interval prevents a shell teleporting through the gun
    -- when the same render object is reused for the next cartridge.
    if withinBeat < 0.10 or withinBeat > 0.88 then return -1 end
    return (withinBeat - 0.10) / 0.78
end

-- Returns four scalar offsets; NEVER creates a table every RenderStepped.
-- nil first return hides the shell (ECO / no reload / between insertions).
function Visual.sample(progress, reloading, graphicsPreset, missingRounds)
    if reloading ~= true or graphicsPreset == "ECO" then return nil end
    local t = Visual.phase(progress, missingRounds)
    if t < 0 then return nil end
    local seated = t * t * (3 - 2 * t)
    return 0.23 * seated,
        0.065 * math.sin(math.pi * t),
        -0.26 * seated,
        -0.28 * seated
end

return Visual
