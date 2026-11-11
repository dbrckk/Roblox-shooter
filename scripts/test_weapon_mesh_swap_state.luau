local P = require("../src/shared/WeaponMeshSwapState")
local state = {
    currentWeaponId = "Shotgun",
    currentWeaponImported = false,
    activeMeshLod = nil,
    model = "PROCEDURAL",
    equipStartedAt = 50,
    fireStartedAt = 49,
    recoil = 0.02,
    reloadActive = false,
    reloadStartedAt = 42,
    reloadBlend = 0.01,
    aimBlend = 0.01,
    stepPhase = 1.25,
    stepBlend = 0.42,
    sway = "CAMERA_SWAY",
    lastCameraPosition = "CAMERA_POSITION",
    lastCameraCFrame = "CAMERA_ORIENTATION",
}
local before = P.capture(state)
assert(before.currentWeaponId == nil and before.model == nil)
-- setWeapon() is also called by actual weapon switches and deliberately
-- resets multiple animation fields. A cosmetic hot-swap must restore them.
for _, field in ipairs(P.Fields) do state[field] = nil end
state.currentWeaponImported = true
state.activeMeshLod = "LOD1"
state.model = "IMPORTED"
P.restore(state, before)
for _, field in ipairs(P.Fields) do
    assert(state[field] == before[field], "Late PBR swap lost "..field)
end
assert(state.currentWeaponId == "Shotgun")
assert(state.currentWeaponImported == true and state.activeMeshLod == "LOD1")
assert(state.model == "IMPORTED", "Never restore destroyed old viewmodel")
-- Do not capture gameplay state, transient effects, connections or ownership.
for _, field in ipairs(P.Fields) do
    assert(field ~= "model" and field ~= "currentWeaponId"
        and field ~= "currentWeaponImported" and field ~= "activeMeshLod"
        and field ~= "pendingCartridge" and field ~= "renderConnection")
end
print("IRON YARD PBR hot-swap preserves equip, recoil, ADS, reload and camera motion OK")
