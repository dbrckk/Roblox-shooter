-- IRON YARD / deterministic non-disruptive imported-weapon upgrade policy.
-- Checked at a low cadence in the existing first-person render callback.
-- No remote events, network calls, server mutations or new frame loops.
local Policy = {}

function Policy.shouldRefresh(imported, activeLod, wantedLod, available, status)
    if available ~= true or (wantedLod ~= "LOD0" and wantedLod ~= "LOD1")
        or type(status) ~= "table" then
        return false
    end
    if imported == true and activeLod == wantedLod then return false end
    -- Do not reset recoil, ADS, reload animation or unplayed shell ejection.
    if status.scoped == true or status.sprinting == true
        or status.reloading == true or status.pendingCartridge == true
        or status.pendingFlash == true then
        return false
    end
    -- The source clone/part rebuild can momentarily pause presentation.
    -- Defer it until the walk bob and camera inertia have settled instead
    -- of rebuilding 3D meshes in the middle of an Android strafe/turn.
    -- Inputs are sampled by the existing 1.2-second check; no frame loop.
    if type(status.stepBlend) ~= "number" or status.stepBlend ~= status.stepBlend
        or status.stepBlend < 0 or status.stepBlend > 0.06 then return false end
    if type(status.swayMagnitude) ~= "number"
        or status.swayMagnitude ~= status.swayMagnitude
        or status.swayMagnitude < 0 or status.swayMagnitude > 0.012 then
        return false
    end
    -- A successful server-confirmed refill may start an extra sniper bolt
    -- or AR/pistol rack AFTER the reload flag and pose have ended.
    -- Leave 0.65 seconds for the full 0.49-second sniper cycle.
    -- math.huge denotes no confirmed refill yet (initial timestamp = -inf).
    if type(status.sinceReloadFinish) ~= "number"
        or status.sinceReloadFinish ~= status.sinceReloadFinish
        or status.sinceReloadFinish < 0.65 then return false end
    if type(status.aimBlend) ~= "number" or status.aimBlend ~= status.aimBlend
        or status.aimBlend > 0.04 or status.aimBlend < 0 then return false end
    if type(status.reloadBlend) ~= "number" or status.reloadBlend ~= status.reloadBlend
        or status.reloadBlend > 0.04 or status.reloadBlend < 0 then return false end
    if type(status.sinceShot) ~= "number" or status.sinceShot ~= status.sinceShot
        or status.sinceShot < 2.0 then return false end
    if type(status.sinceEquip) ~= "number" or status.sinceEquip ~= status.sinceEquip
        or status.sinceEquip < 0.8 then return false end
    return true
end

return Policy
