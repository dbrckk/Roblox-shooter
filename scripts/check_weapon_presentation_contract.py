#!/usr/bin/env python3
"""Validate live client integration of deterministic weapon feel and audio.

Pure Luau tests verify profiles. This checks source wiring, not Roblox rendering
or final sound licensing; all audio still uses existing bundled Roblox sounds.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def get(path):
    return (root / path).read_text(encoding="utf-8")

feel = get("src/shared/WeaponFeelProfile.luau")
audio = get("src/shared/WeaponAudioPolicy.luau")
visuals = get("src/client/WeaponVisuals.luau")
client = get("src/client/init.client.luau")
server = get("src/server/WeaponService.luau")
config = get("src/shared/WeaponConfig.luau")
ejection = get("src/shared/CartridgeEjectionPolicy.luau")
ads = get("src/shared/WeaponAimPose.luau")
scope_fov = get("src/shared/ScopeFovPolicy.luau")
hud = get("src/client/HudController.luau")
crosshair = get("src/shared/CrosshairFeedbackPolicy.luau")

for needle in (
    "function Feel.get(id)", "function Feel.kick(id, current, added)",
    "function Feel.recover(id, current, dt)",
    "function Feel.shotEnvelope(id, age)", "function Feel.mechanism(id, age)",
):
    assert needle in feel, f"Pure weapon feel missing: {needle}"

for needle in (
    "function Audio.select(preset, mobile, distance, localShot, activeVoices, weaponId)",
    "if localShot then", "activeVoices >= maxVoices",
    "distance > maxDistance", "layers = far and 1 or 2",
    "REACH[weaponId] or 1",
    "function Audio.needsOcclusion(distance, localShot)",
    "function Audio.occludedMix(mix, blocked)",
    "volume = mix.volume * 0.40",
    "highGain = -24", "midGain = -12",
    "highGain = far and -10 or 0",
):
    assert needle in audio, f"Audio admission missing: {needle}"

for needle in (
    'WaitForChild("WeaponFeelProfile")',
    'WaitForChild("WeaponAudioPolicy")',
    "self.recoil = WeaponFeel.kick(weaponId, self.recoil, config.recoilKick or 0.08)",
    "self.recoil = WeaponFeel.recover(self.currentWeaponId, self.recoil, deltaTime)",
    "WeaponFeel.shotEnvelope(self.currentWeaponId,",
    "WeaponFeel.mechanism(self.currentWeaponId, shotAge)",
    "function WeaponVisuals:_syncScopeVisibility()",
    "ViewmodelRenderPolicy.needsUpdate(",
    "ViewmodelRenderPolicy.transparency(",
    "feel.reloadPitch * reloadingPose",
    "feel.handTravel",
    'partName == "ChargingHandle"',
    'partName == "PumpAction"',
    'partName == "Bolt"',
    'partName == "Slide"',
    "function WeaponVisuals:playFireSound(weaponId, origin, localShot)",
    "WeaponAudio.select(",
    "UserInputService.TouchEnabled, distance, ownShot, #self.remoteSoundEmitters, weaponId)",
    "self.remoteSoundEmitters = {}",
    "table.insert(self.remoteSoundEmitters, emitter)",
    "if index > mix.layers then break end",
    "Debris:AddItem(emitter, mix.lifetime)",
    "if WeaponAudio.needsOcclusion(distance, ownShot) then",
    "params.RespectCanCollide = true",
    "params.IgnoreWater = true",
    "workspace:Raycast(",
    "mix = WeaponAudio.occludedMix(mix, cover ~= nil)",
    'Instance.new("EqualizerSoundEffect")',
    'eq.Name = "IronYardDistanceFilter"',
    "eq.HighGain = mix.highGain or 0",
    "eq.MidGain = mix.midGain or 0",
    "eq.LowGain = mix.lowGain or 0",
    "if (mix.highGain or 0) < 0 or (mix.midGain or 0) < 0 then",
):
    assert needle in visuals, f"Weapon visuals not wired: {needle}"

# PBR sight centers come from authored Blender geometry; the fallback uses
# its original Part positions. Select AFTER the source is actually created.
aim_profile = get("src/shared/WeaponAimPose.luau")
assert "local IMPORTED_PROFILES = {" in aim_profile
assert 'local pose = WeaponAimPose.get(weaponId, self.currentWeaponImported)' in visuals
set_weapon_body = visuals.split("function WeaponVisuals:setWeapon(weaponId)", 1)[1]
set_weapon_body = set_weapon_body.split("function WeaponVisuals:_refreshImportedWeaponIfSafe", 1)[0]
assert set_weapon_body.index('local pose = WeaponAimPose.get(weaponId, self.currentWeaponImported)') > ( 
    set_weapon_body.index('model:SetAttribute("IronYardWeaponSource", "PROCEDURAL_PARTS")')
), "Do not select a procedural ADS profile before the imported asset is chosen"

# The cosmetic reload must use real server Ammo state and no new animation loop.
reload_visual = get("src/shared/ShotgunReloadVisual.luau")
for needle in (
    "function Visual.sample(progress, reloading, graphicsPreset)",
    'graphicsPreset == "ECO"',
    'reloading ~= true',
):
    assert needle in reload_visual, f"Shotgun loading policy missing: {needle}"
for needle in (
    'WaitForChild("ShotgunReloadVisual")',
    '"ShotgunEjectionPort"',
    '"ShotgunLoadingPort"',
    '"CarrierShellBody" .. i',
    '"CarrierShellBrass" .. i',
    '"LoadingShellBody"',
    '"LoadingShellBrass"',
    'shellX, shellY, shellZ, shellRoll = ShotgunReloadVisual.sample(',
    'local targetAlpha = shellX and not self.lastViewmodelHidden and 0 or 1',
    'if entry.part.Transparency ~= targetAlpha then',
):
    assert needle in visuals, f"Shotgun reload model / visible mechanism missing: {needle}"
assert 'Shotgun = { anchor = "ShotgunEjectionPort"' in ejection
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1
assert 'FireServer' not in reload_visual and 'Instance.new' not in reload_visual
assert 'return {' not in reload_visual, "No per-frame allocation of shell pose tables"
assert 'local loadingShell = self.currentWeaponId' not in visuals, (
    "Shotgun reload viewmodel must consume scalar motion, not tables")

# Scoped rifle and AR-24 viewmodels gained deterministic detail geometry.
# These create geometry only on equip, never in combat frame callbacks.
for needle in (
    '"ScopeRingFront"',
    '"ScopeRingRear"',
    '"ScopeEyepiece"',
    '"BoltHandle"',
    '"BoltHandleKnob"',
    'or partName == "BoltHandleKnob") and self.currentWeaponId == "Sniper"',
    '"ReceiverDeflector"',
    '"SelectorDial"',
    '"GasBlock"',
    '"VentLeft" .. i',
    '"VentRight" .. i',
    '"RailTooth" .. i',
    'for i = 1, 3 do',
):
    assert needle in visuals, f"Detailed 3D firearm part missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Precision models must not add a second frame loop"
)
# The material-detail loops are authored inside equip-time constructor functions.
assert visuals.index('"VentLeft" .. i') < visuals.index('function WeaponVisuals:_createShotgun')
assert visuals.index('"ScopeRingFront"') < visuals.index('function WeaponVisuals:_createAssaultRifle')

# Reproducible first-person mechanical detailing is device-L0D bounded.
detail_plan = get("src/shared/WeaponDetailPlan.luau")
mesh_policy = get("src/shared/WeaponMeshPolicy.luau")
studio_importer = get("tools/studio/install_weapon_meshes.lua")
asset_loader = get("src/server/WeaponAssetLoader.luau")
asset_policy = get("src/shared/WeaponAssetPolicy.luau")
server_init = get("src/server/init.server.luau")
weapon_registry = get("src/shared/WeaponAssetIds.luau")
for needle in (
    'require(script:WaitForChild("WeaponAssetLoader"))',
    "WeaponAssetLoader.start()",
):
    assert needle in server_init, f"Automated weapon loader not started: {needle}"
for needle in (
    'AssetService:LoadAssetAsync(assetId)',
    'MeshPolicy.mapsReady({',
    'MeshPolicy.Required[weaponId]',
    'Policy.sameOwner(Registry,',
    'Policy.pair(Registry, weaponId)',
    'task.spawn(loadConfigured)',
    'clone:FindFirstChildOfClass("SurfaceAppearance")',
    'descendant:Destroy()',
    'LoadPlan.queue(Policy.Weapons, function(weaponId)',
    'LoadPlan.workers(#queue)',
    'if validPair(existing, job.weaponId) then',
    'task.spawn(worker)',
    'reportStatus(ReplicatedStorage:FindFirstChild(ROOT_NAME), pending, true)',
    'template:SetAttribute("IronYardStudioApproved", true)',
    '"IronYardWeaponMeshStatus"',
):
    assert needle in asset_loader, f"Owner PBR runtime loader missing: {needle}"
assert 'game.CreatorType == Enum.CreatorType.User' in asset_loader
assert 'function Policy.sameOwner(registry, creatorType, creatorId)' in asset_policy
assert 'function Policy.pair(registry, weaponId)' in asset_policy
assert 'ownerUserId = 9774173158' in weapon_registry
# Career finishes must NOT alter an imported PBR mesh's authored
# base color, even when its mechanical runtime name matches a tiered finish.
assert 'function P.canRetint(entry)' in mesh_policy
assert 'return type(entry)=="table" and entry.isPbrMesh~=true' in mesh_policy
assert 'isPbrMesh=true,' in visuals
for needle in (
    'if WeaponMeshPolicy.canRetint(entry) then',
    'entry.part.Color = color',
):
    assert needle in visuals, f"PBR surface finish preservation missing: {needle}"
finish_section = visuals.split("function WeaponVisuals:_applyCareerFinish()",1)[1]
finish_section = finish_section.split("function WeaponVisuals:_addArms",1)[0]
assert finish_section.index("if WeaponMeshPolicy.canRetint(entry) then") < (
    finish_section.index("entry.part.Color = color")
), "Guard the actual BasePart.Color write for imported SurfaceAppearance meshes"
# No expensive GLB mesh+PBR-map traversal during ADS, reload, or active fire.
refresh_section = visuals.split(
    "function WeaponVisuals:_refreshImportedWeaponIfSafe(now)",1)[1]
refresh_section = refresh_section.split("function WeaponVisuals:setSprinting",1)[0]
assert refresh_section.index("WeaponMeshRefresh.shouldRefresh(") < (
    refresh_section.index("self:_getImportedWeapon(self.currentWeaponId, lod)")
), "Skip texture scans until the safe idle window"
assert 'if not safe then return end' in refresh_section


load_plan = get("src/shared/WeaponAssetLoadPlan.luau")
for needle in (
    "Plan.MAX_WORKERS = 2",
    "function Plan.queue(weapons, pairFor, isComplete)",
    "function Plan.status(ready, pending, authorized)",
    "if pair ~= nil and isComplete(weaponId) ~= true then",
    'return authorized == true and "FALLBACK" or "DISABLED"',
):
    assert needle in load_plan, f"Server asset scheduler policy missing: {needle}"
assert 'Workspace:SetAttribute("IronYardWeaponMeshReadyCount", ready)' in asset_loader
assert 'Workspace:SetAttribute("IronYardWeaponMeshPendingCount", pending)' in asset_loader
assert 'replacement.Parent = root' in asset_loader
assert 'if existing then existing:Destroy() end' in asset_loader
assert 'if liveRoot == root then' in asset_loader
assert 'task.spawn(loadConfigured)' in asset_loader
assert asset_loader.count('AssetService:LoadAssetAsync(assetId)') == 1

for needle in (
    'function P.lod(preset,touch)',
    'function P.mapsReady(m)',
    'function P.namesComplete(weapon,names)',
    'Pistol={"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"}',
):
    assert needle in mesh_policy, f"Owner mesh runtime import policy missing: {needle}"
for needle in (
    'function WeaponVisuals:_createImportedWeapon(model, weaponId)',
    'IronYardWeaponTemplates',
    'IronYardStudioApproved',
    'WeaponMeshPolicy.mapsReady({',
    'not part:IsA("MeshPart")',
    'if descendant ~= appearance or descendant.Parent ~= clone then',
    'configurePart(clone)',
    'self.currentWeaponImported = true',
    'model:SetAttribute("IronYardWeaponSource", "PBR_MESH")',
    'if not self:_createImportedWeapon(model, "Pistol") then',
    'if not self:_createImportedWeapon(model, "Knife") then',
    'model:SetAttribute("IronYardWeaponSource", "PROCEDURAL_PARTS")',
):
    assert needle in visuals, f"Secure PBR first-person path missing: {needle}"
for needle in (
    'assert(#selected>=2 and #selected<=10 and #selected%2==0',
    'child.MeshId~="" and validAppearance(child)',
    'item:Destroy()',
    'local stage=Instance.new("Folder")',
    'if previous then previous:Destroy() end',
    'installVariant(high,weapon,"LOD0")',
    'installVariant(low,weapon,"LOD1")',
):
    assert needle in studio_importer, f"Secure Studio import missing: {needle}"

for needle in (
    'function Plan.tier(preset, touch)',
    'function Plan.get(weapon, preset, touch)',
    'CACHE[weapon][tier] = allowed',
    'if preset == "ECO" then return 1 end',
    'if touch == true and preset ~= "QUALITY" then return 2 end',
):
    assert needle in detail_plan, f"Weapon detail tier plan missing: {needle}"
for needle in (
    'WaitForChild("WeaponDetailPlan")',
    'function WeaponVisuals:_addDetailGeometry(model, weaponId)',
    'self:_addDetailGeometry(model, "Pistol")',
    'self:_addDetailGeometry(model, "Knife")',
    'or string.sub(partName, 1, 11) == "SlideDetail"',
    'added.finishRole = spec.finish',
    'added.isDetail = true',
    'self.detailPresetConnection = Players.LocalPlayer:GetAttributeChangedSignal(',
    'function WeaponVisuals:_syncDetailTier()',
    'if newTier == self.detailTier then return end',
    'if entry.isDetail and not allowed[entry.part.Name] then',
    'entry.part:Destroy()',
    'self:_addDetailGeometry(self.model, self.currentWeaponId)',
    'self:_applyCareerFinish()',
):
    assert needle in visuals, f"Viewmodel cosmetic detail rendering missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Details must use the existing viewmodel renderer"
)

layout = get("src/shared/WeaponMeshLayout.luau")
# PBR weapon origin MUST follow the authored Blender coordinate frame.
# Roblox's outer Model:GetPivot() can be recentered to the imported bounds.
weapon_forge = get("tools/weaponforge/build_weapons.py")
weapon_validator = get("tools/weaponforge/validate_weapon_exports.py")
weapon_uploader = get("scripts/upload_weapon_models.py")
for needle in (
    'box("IRONYARD_WeaponOrigin", (0, 0, 0), (.10, .10, .10),',
    'use_selection=True,export_yup=True',
):
    assert needle in weapon_forge, f"Authoring root or glTF axis missing: {needle}"
for needle in (
    'ORIGIN_NAME="IRONYARD_WeaponOrigin"',
    "set(names)==REQUIRED[weapon] | {ORIGIN_NAME}",
    '"Origin marker geometry exceeds 12.2cm bounding cube"',
    '"originMarker":ORIGIN_NAME',
):
    assert needle in weapon_validator, f"GLB pivot validation missing: {needle}"
assert 'from validate_weapon_exports import REQUIRED, ORIGIN_NAME, inspect' in weapon_uploader
assert 'REQUIRED[weapon] | {ORIGIN_NAME}' in weapon_uploader, (
    "Open Cloud must reject unanchored, misaligned GLB releases"
)
assert 'function Layout.origin(root, validate)' in layout
assert 'Layout.ORIGIN_NAME = "IRONYARD_WeaponOrigin"' in layout
assert 'local marker = Layout.origin(package, function(mesh)' in asset_loader
assert 'origin.CFrame = marker.CFrame' in asset_loader
assert 'origin.CFrame = package:GetPivot()' not in asset_loader
assert 'local marker=WeaponMeshLayout.origin(source, function(mesh)' in studio_importer
assert 'origin.CFrame=rootCFrame' in studio_importer
assert 'origin.CFrame=source:GetPivot()' not in studio_importer

# Late owner-authorized uploads must activate without a weapon swap.
# A preset change must switch a currently imported viewmodel to its new LOD,
# but never during combat, reload, aiming, or before full PBR map replication.
layout = get("src/shared/WeaponMeshLayout.luau")
for needle in (
    "function Layout.componentName(candidate, required)",
    "function Layout.collect(root, required, validate)",
    'part:IsA("MeshPart")',
    'parent:IsA("Model") or parent:IsA("Folder")',
    "Layout.MAX_PER_COMPONENT = 8",
    "Layout.MAX_TOTAL = 32",
    "if owners[key] and owners[key] ~= owner then return nil end",
):
    assert needle in layout, f"Roblox multi-primitive glTF import missing: {needle}"
for needle in (
    'WaitForChild("WeaponMeshLayout")',
    'WeaponMeshLayout.collect(template, required, function(part)',
    'for _, componentName in ipairs(WeaponMeshPolicy.Required[weaponId]) do',
    'for _, sourcePart in ipairs(selected[componentName]) do',
):
    assert needle in visuals, f"Client GLB multi-primitive animation missing: {needle}"
for needle in (
    'Layout.collect(package,',
    'Layout.collect(model, MeshPolicy.Required[weaponId], validMesh)',
    'for index, part in ipairs(selected[name]) do',
):
    assert needle in asset_loader, f"Server GLB nested mesh load missing: {needle}"
for needle in (
    'WeaponMeshLayout.collect(root, expected[weapon], function(child)',
    'for i,sourcePart in ipairs(found[name]) do',
    'component.Name=name',
):
    assert needle in studio_importer, f"Studio multi-primitive install missing: {needle}"

swap_state = get("src/shared/WeaponMeshSwapState.luau")
for needle in (
    '"equipStartedAt", "fireStartedAt", "recoil"',
    '"reloadActive", "reloadStartedAt", "reloadBlend"',
    '"aimBlend", "stepPhase", "stepBlend", "sway"',
    '"lastCameraPosition"',
    "function P.capture(viewmodel)",
    "function P.restore(viewmodel, snapshot)",
):
    assert needle in swap_state, f"Cosmetic PBR swap must preserve {needle}"
for needle in (
    'WaitForChild("WeaponMeshSwapState")',
    'local previousPose = WeaponMeshSwapState.capture(self)',
    'WeaponMeshSwapState.restore(self, previousPose)',
    'if self.currentWeaponImported then',
):
    assert needle in visuals, f"Seamless viewmodel PBR hot-swap missing {needle}"
upgrade = visuals.split(
    "function WeaponVisuals:_refreshImportedWeaponIfSafe(now)", 1)[1]
upgrade = upgrade.split("function WeaponVisuals:setSprinting", 1)[0]
assert upgrade.index("WeaponMeshSwapState.capture(self)") < upgrade.index(
    "self:setWeapon(weaponId)") < upgrade.index(
    "WeaponMeshSwapState.restore(self, previousPose)"), (
        "Cosmetic mesh hot-swap must restore all interpolated animation state"
    )

refresh_policy = get("src/shared/WeaponMeshRefreshPolicy.luau")
for needle in (
    "function Policy.shouldRefresh(imported, activeLod, wantedLod, available, status)",
    "status.scoped == true",
    "status.sprinting == true",
    "status.reloading == true",
    "status.pendingCartridge == true",
    "status.sinceShot < 2.0",
    "status.sinceEquip < 0.8",
):
    assert needle in refresh_policy, f"Non-disruptive hot swap policy missing: {needle}"
for needle in (
    'WaitForChild("WeaponMeshRefreshPolicy")',
    'function WeaponVisuals:_getImportedWeapon(weaponId, lod)',
    "function WeaponVisuals:_refreshImportedWeaponIfSafe(now)",
    "self.nextWeaponMeshCheck = now + 1.2",
    "WeaponMeshRefresh.shouldRefresh(self.currentWeaponImported,",
    "self.activeMeshLod = lod",
    'model:SetAttribute("IronYardWeaponLOD", lod)',
    'self.model:SetAttribute("IronYardWeaponUpgrade", "DEFERRED_IDLE")',
    "self:_refreshImportedWeaponIfSafe(clock)",
):
    assert needle in visuals, f"Deferred PBR LOD refresh not wired: {needle}"
assert visuals.count("self:_refreshImportedWeaponIfSafe(clock)") == 1, (
    "Mesh polling must share the original client RenderStepped hook"
)
getter = visuals.split("function WeaponVisuals:_getImportedWeapon(weaponId, lod)", 1)[1]
getter = getter.split("function WeaponVisuals:_createImportedWeapon", 1)[0]
assert "\n    return false" not in getter, (
    "An incomplete imported template must be nil, not a truthy refresh status"
)
assert getter.count("return nil") >= 5
assert visuals.index("local origin = self:_getImportedWeapon(self.currentWeaponId, lod)") < (
    visuals.index("self:setWeapon(weaponId)", visuals.index(
        "function WeaponVisuals:_refreshImportedWeaponIfSafe(now)"))
), "Verify complete source before resetting an equipped weapon"

# Five authored PBR meshes, retaining original animation and FX on import.
for weapon in ("AssaultRifle", "Shotgun", "Sniper"):
    assert f'if not self:_createImportedWeapon(model, "{weapon}") then' in visuals
    assert f'{weapon}={{' in mesh_policy
for needle in (
    'clone.Name = WeaponMeshPolicy.runtimeName(componentName)',
    'anchor("FlashHider"',
    'anchor("ShotgunEjectionPort"',
    'anchor("MuzzleBrake"',
    'self:_addPart(model, "Part", "LoadingShellBody"',
    'self:_addPart(model, "Part", "LoadingShellBrass"',
):
    assert needle in visuals, f"Imported PBR weapon animation/ejection missing: {needle}"


# Rifle, shotgun and sniper use the exact same equip-time detail renderer.
# The LOD switch must not be limited to the pistol and knife.
for weapon in ("AssaultRifle", "Shotgun", "Sniper"):
    assert f'self:_addDetailGeometry(model, "{weapon}")' in visuals, (
        f"{weapon}: missing authored adaptive first-person detail"
    )
    assert f'{weapon} = {{}}' in detail_plan, (
        f"{weapon}: missing capped device-specific detail plan"
    )
assert 'self.currentWeaponId ~= "Pistol" and self.currentWeaponId ~= "Knife"' not in visuals, (
    "Live graphics quality must update long-gun detail without re-equipping"
)
assert 'added.baseTransparency, self.lastViewmodelHidden == true' in visuals, (
    "New sniper detail must not leak into the optical scope on quality change"
)

# Mechanically linked pieces share transforms in the existing frame loop.
for needle in (
    '"MagazineBase", Vector3.new(0.22, 0.09, 0.20)',
    '"Extractor", Vector3.new(0.035, 0.032, 0.14)',
    'local supportMotion = self.currentWeaponId == "Shotgun"',
    'localOffset = localOffset * workingHand * supportMotion',
    '(partName == "Magazine" or partName == "MagazineBase")',
    '(partName == "Slide" or partName == "EjectionPort"',
    'or partName == "Extractor"',
    'or string.sub(partName, 1, 11) == "SlideDetail")',
    'and self.currentWeaponId == "Pistol" then',
):
    assert needle in visuals, f"Moving first-person weapon part missing: {needle}"
assert visuals.count('RunService.RenderStepped:Connect(function(deltaTime)') == 1, (
    "Mechanical motion must reuse the existing single frame loop"
)
for needle in (
    "function Policy.plan(weaponId, preset, touch, shotNumber)",
    'preset == "ECO"', "function Policy.arc(progress, height)",
    "AssaultRifle =", "Pistol =", "Shotgun =", "Sniper =",
):
    assert needle in ejection, f"Spent-shell policy missing: {needle}"
for needle in (
    'WaitForChild("CartridgeEjectionPolicy")',
    "function WeaponVisuals:_ejectCartridge(plan)",
    'name = "IronYardSpentCartridge"',
    "shape = Enum.PartType.Cylinder",
    "priority = 1",
    "slot.arcHeight = spec.arcHeight or 0",
    "slot.spinAngle = spec.spinAngle or 0",
    "CartridgeEjection.arc(t, slot.arcHeight)",
    "local pending = self.pendingCartridge",
    "self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap",
    "function WeaponVisuals:kick(weaponId)",
    "CartridgeEjection.plan(weaponId,",
    "self:_ejectCartridge(pending.plan)",
):
    assert needle in visuals, f"Client casings not wired: {needle}"
assert visuals.count("function WeaponVisuals:_ejectCartridge(plan)") == 1
assert visuals.index("self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap") < (
    visuals.index("function WeaponVisuals:_ejectCartridge(plan)"))
assert "FireServer" not in ejection and "Instance.new" not in ejection
for needle in (
    "function Pose.get(id)", "function Pose.damping(blend)",
    "sightX = 0, sightY = 0.32, sightZ = -0.05",
    "sightX = 0, sightY = 0.30, sightZ = 0.10",
    "sightX = 0, sightY = 0.24, sightZ = -0.28",
):
    assert needle in ads, f"ADS policy missing: {needle}"
for needle in (
    'WaitForChild("WeaponAimPose")',
    "WeaponAimPose.damping(self.aimBlend)",
    "self.aimPose = pose and CFrame.new(pose.x, pose.y, pose.z) or nil",
    "offset:Lerp(self.aimPose, self.aimBlend)",
    '"ScopeAdjustmentTurret"', '"ScopeAdjustmentCap"',
    '"RearSight", Vector3.new(0.19, 0.09, 0.14)',
):
    assert needle in visuals, f"Sight geometry or pose missing: {needle}"
assert "local aimOffset = CFrame.new(-0.40, 0.13, -0.14)" not in visuals
assert "if currentWeaponId ~= weaponId and scoped then" in client
assert client.index("if currentWeaponId ~= weaponId and scoped then") < client.index(
    "currentWeaponId = weaponId", client.index("local function equipWeapon("))
assert "function Scope.fieldOfView(baseFov, scoped, config)" in scope_fov
for needle in (
    'WaitForChild("ScopeFovPolicy")',
    "ScopeFovPolicy.fieldOfView(baseFieldOfView, scoped, config)",
    "local function applyCameraFov()",
    "if camera.FieldOfView ~= target then",
    "local function setScoped(enabled)",
    "if enabled == scoped then",
    "setScoped(false)\n\t\tenforceFirstPerson()",
    'workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()',
    "task.defer(enforceFirstPerson)",
):
    assert needle in client, f"Camera FOV and respawn resilience missing: {needle}"
assert "if camera and not scoped then" not in client, (
    "Camera replacement must also restore scoped magnification")
assert "if not camera then\n\t\treturn\n\tend\n\n\tlocal config" not in client, (
    "Missing camera must not prevent scope state cleanup")
assert "visuals:playFireSound(weaponId, ray.Origin, true)" in client, (
    "Locally predicted shot must never be culled as a remote shot"
)
assert "visuals:playFireSound(message.weaponId, message.origin)" in client, (
    "Remote gun audio must pass through spatial voice budget"
)
assert "self.recoil - deltaTime * 5.5" not in visuals, (
    "Generic 5.5/s recoil no longer belongs in weapon handling"
)
for needle in (
    'scopeRing.Size = UDim2.fromScale(0.55, 0.55)',
    'Instance.new("UIAspectRatioConstraint")',
    'aspect.DominantAxis = Enum.DominantAxis.Height',
    'Instance.new("UISizeConstraint")',
    'sizeLimit.MinSize = Vector2.new(150, 150)',
    'sizeLimit.MaxSize = Vector2.new(350, 350)',
    'segment("ScopeLeftStadia"', 'segment("ScopeRightStadia"',
    'segment("ScopeTopStadia"', 'segment("ScopeBottomStadia"',
    'segment("ScopeCenterDot"', 'segment("ScopeWindageTick"',
    'segment("ScopeElevationTick"', 'self.hitMarker.ZIndex = 4',
    'self.damageReadout.ZIndex = 4', 'self.eliminationConfirmation.ZIndex = 4',
    'self.scopeOverlay.Visible = scoped and isOptical',
    'self.scopeRing.Visible = scoped and isOptical',
):
    assert needle in hud, f"Missing optically scoped UI element: {needle}"
assert 'scopeRing.Size = UDim2.fromOffset(310, 310)' not in hud
assert 'RenderStepped:Connect' not in hud, "Sniper UI must not add a frame loop"
for needle in (
    "function Policy.kick(weaponId, previous)",
    "function Policy.recover(previous, dt)",
    "function Policy.radius(weaponId, moveAmount, sprinting, kick)",
    "function Policy.shouldDraw(now, previousAt, previousRadius, radius)",
):
    assert needle in crosshair, f"Cosmetic crosshair policy missing: {needle}"
for needle in (
    'WaitForChild("CrosshairFeedbackPolicy")',
    'function HudController:registerPredictedShot(weaponId)',
    'function HudController:updateCrosshair(dt, moving, running)',
    'CrosshairFeedback.shouldDraw(now,',
    'self.crosshair.Visible = not scoped',
    'self.adsDot.Visible = scoped and not isOptical',
    'self.crosshairLines[1].Position = UDim2.new(0.5, 0, 0.5, -radius)',
    'self.adsDot.BackgroundColor3 = color',
):
    assert needle in hud, f"Adaptive hip-fire / ADS UI missing: {needle}"
assert 'hud:registerPredictedShot(weaponId)' in client
assert 'hud:updateCrosshair(deltaTime, moveAmount, sprinting)' in client
assert client.index('hud:registerPredictedShot(weaponId)') < (
    client.index('remotes.FireWeapon:FireServer({', client.index('local function fireWeapon(')))
assert client.count('RenderStepped:Connect') == 1, (
    "Hip-fire responsiveness must reuse the existing frame callback")
assert "FireServer" not in crosshair and "Instance.new" not in crosshair

assert "targetHumanoid:TakeDamage(damage)" in server
assert "fireCooldown = 0.115" in config, "Server/weapon cadence not rewritten"
print("IRON YARD five original viewmodels and bounded spatial audio wiring: OK")
