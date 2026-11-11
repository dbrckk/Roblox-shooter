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
        or status.reloading == true or status.pendingCartridge == true then
        return false
    end
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
