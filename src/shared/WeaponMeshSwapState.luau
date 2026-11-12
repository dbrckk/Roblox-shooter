-- IRON YARD / preserve client-only weapon animation across a late PBR/LOD swap.
-- Not used for genuine weapon changes: they deliberately start a fresh equip.
local P = {}
P.Fields = {
    "equipStartedAt", "fireStartedAt", "recoil",
    "reloadActive", "reloadStartedAt", "reloadBlend",
    "reloadHandX", "reloadHandY", "reloadHandZ",
    "magazineDipBlend", "pistolOffhandAlpha",
    "aimBlend", "stepPhase", "stepBlend", "sway",
    "lastCameraPosition", "lastCameraCFrame",
}

function P.capture(viewmodel)
    local snapshot = {}
    for _, field in ipairs(P.Fields) do
        snapshot[field] = viewmodel[field]
    end
    return snapshot
end

function P.restore(viewmodel, snapshot)
    for _, field in ipairs(P.Fields) do
        viewmodel[field] = snapshot[field]
    end
end

return P
