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
    'role == WeaponPartMotionRole.RIFLE_CHARGING_HANDLE',
    'role == WeaponPartMotionRole.SHOTGUN_PUMP',
    'role == WeaponPartMotionRole.SNIPER_BOLT',
    'role == WeaponPartMotionRole.PISTOL_SLIDE',
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
assert 'p.pitch = -math.atan2(heightDelta, forwardDistance)' in aim_profile
assert 'p.y = -(c * p.sightY - s * p.sightZ)' in aim_profile
assert 'p.z = -p.eyeRelief - (s * p.sightY + c * p.sightZ)' in aim_profile
assert 'CFrame.Angles(pose.pitch, 0, 0)' in visuals
assert 'p.pitch = 0' in aim_profile
assert "frontY = 0.42, frontZ = -1.57" in aim_profile
assert "frontY = 0.36, frontZ = -0.50" in aim_profile
assert "frontY = 0.36, frontZ = -2.20" in aim_profile
set_weapon_body = visuals.split("function WeaponVisuals:setWeapon(weaponId)", 1)[1]
set_weapon_body = set_weapon_body.split("function WeaponVisuals:_refreshImportedWeaponIfSafe", 1)[0]
assert set_weapon_body.index('local pose = WeaponAimPose.get(weaponId, self.currentWeaponImported)') > ( 
    set_weapon_body.index('model:SetAttribute("IronYardWeaponSource", "PROCEDURAL_PARTS")')
), "Do not select a procedural ADS profile before the imported asset is chosen"

# First-person PBR effects follow the actual authored Blender geometry,
# not the differently shaped fallback Part gun. This also ensures the
# delayed sniper casing leaves a dedicated socket rather than a Model pivot.
pbr_fx = get("src/shared/WeaponPbrFxSockets.luau")
for needle in (
    "function Sockets.get(weaponId, socketName)",
    "function Sockets.muzzleAdvance(isImported)",
    "Pistol = {", "AssaultRifle = {", "Shotgun = {", "Sniper = {",
    "SniperEjectionPort = {0.20, 0.07, -0.13}",
):
    assert needle in pbr_fx, f"Missing authored PBR FX socket: {needle}"
for needle in (
    'WaitForChild("WeaponPbrFxSockets")',
    "local x, y, z = WeaponPbrFxSockets.get(weaponId, name)",
    'anchor("Muzzle")', 'anchor("FlashHider")',
    'anchor("MuzzleRing")', 'anchor("MuzzleBrake")',
    'anchor("SniperEjectionPort")',
    '"Part", "SniperEjectionPort",',
    "local MUZZLE_NAMES = {",
    "WeaponPbrFxSockets.muzzleAdvance(self.currentWeaponImported)",
):
    assert needle in visuals, f"PBR effect placement not wired: {needle}"
assert 'Sniper = { anchor = "SniperEjectionPort"' in ejection
assert 'Sniper = { anchor = "Bolt"' not in ejection
assert "local muzzleNames = {" not in visuals, (
    "Repeated shots must not allocate a fresh muzzle lookup table")
assert visuals.count('anchor("SniperEjectionPort")') == 1
assert visuals.count('WeaponPbrFxSockets.muzzleAdvance(self.currentWeaponImported)') == 1

# The cosmetic reload must use real server Ammo state and no new animation loop.
reload_visual = get("src/shared/ShotgunReloadVisual.luau")
for needle in (
    "function Visual.sample(progress, reloading, graphicsPreset, missingRounds)",
    'graphicsPreset == "ECO"',
    'reloading ~= true',
):
    assert needle in reload_visual, f"Shotgun loading policy missing: {needle}"
for needle in (
    "function Visual.phase(progress, missingRounds)",
    "local count = math.clamp(math.floor(missingRounds), 1, 6)",
    "if withinBeat < 0.10 or withinBeat > 0.88 then return -1 end",
):
    assert needle in reload_visual, f"Missing B-8 cartridge cycling contract: {needle}"
for needle in (
    "self.reloadShellCount = math.clamp(math.floor(capacity - loaded), 1, 6)",
    "ShotgunReloadVisual.phase(progress, self.reloadShellCount)",
    "self.currentWeaponImported, self.currentWeaponHasPbrMagazine, shellBeat)",
    "self.reloadShellCount)",
):
    assert needle in visuals, f"B-8 live visual coordination missing: {needle}"

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
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1
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
    'role == WeaponPartMotionRole.SNIPER_BOLT then',
    '"ReceiverDeflector"',
    '"SelectorDial"',
    '"GasBlock"',
    '"VentLeft" .. i',
    '"VentRight" .. i',
    '"RailTooth" .. i',
    'for i = 1, 3 do',
):
    assert needle in visuals, f"Detailed 3D firearm part missing: {needle}"
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1, (
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
    'motionRole = WeaponPartMotionRole.classify(self.currentWeaponId, name)',
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
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1, (
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
    "function Layout.collect(root, required, validate, optional)",
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
    'for _, componentName in ipairs(WeaponMeshPolicy.components(weaponId)) do',
    'if selected[componentName] then',
    'for _, sourcePart in ipairs(selected[componentName]) do',
):
    assert needle in visuals, f"Client GLB multi-primitive animation missing: {needle}"
for needle in (
    'Layout.collect(package,',
    'Layout.collect(model, MeshPolicy.Required[weaponId], validMesh,',
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

# Mechanical classification is resolved once when Parts/PBR primitives are equipped.
motion_roles = get("src/shared/WeaponPartMotionRole.luau")
assert 'function Role.classify(weaponId, name)' in motion_roles
for needle in (
    'WaitForChild("WeaponPartMotionRole")',
    'motionRole = WeaponPartMotionRole.classify(self.currentWeaponId, name)',
    'motionRole=WeaponPartMotionRole.classify(self.currentWeaponId, clone.Name)',
    'local role = entry.motionRole',
    'role == WeaponPartMotionRole.LEFT_HAND',
    'role == WeaponPartMotionRole.SNIPER_RIGHT_HAND',
    'role == WeaponPartMotionRole.SHOTGUN_LOADING_SHELL',
    'role == WeaponPartMotionRole.MAGAZINE',
    'role == WeaponPartMotionRole.RIFLE_CHARGING_HANDLE',
    'role == WeaponPartMotionRole.PISTOL_SLIDE',
    'role == WeaponPartMotionRole.SHOTGUN_PUMP',
    'role == WeaponPartMotionRole.SNIPER_BOLT',
):
    assert needle in visuals, f"Missing equip-time mechanical role: {needle}"
render_motion = visuals.split("function WeaponVisuals:_render(deltaTime)", 1)[1]
render_motion = render_motion.split("    -- Emission MUST happen after all parts", 1)[0]
assert "local partName = entry.part.Name" not in render_motion
assert "string.sub(partName" not in render_motion
assert "WeaponPartMotionRole.classify(" not in render_motion
assert 'string.sub(name, 1, 11) == "SlideDetail"' in motion_roles

# Mechanically linked pieces share transforms in the existing frame loop.
for needle in (
    '"MagazineBase", Vector3.new(0.22, 0.09, 0.20)',
    '"Extractor", Vector3.new(0.035, 0.032, 0.14)',
    'local supportMotion = self.currentWeaponId == "Shotgun"',
    'localOffset = localOffset * workingHand * supportMotion',
    'role == WeaponPartMotionRole.MAGAZINE then',
    'role == WeaponPartMotionRole.PISTOL_SLIDE then',
    'role == WeaponPartMotionRole.SHOTGUN_PUMP then',
    'role == WeaponPartMotionRole.RIFLE_CHARGING_HANDLE then',
    'role == WeaponPartMotionRole.SHOTGUN_LOADING_SHELL then',
):
    assert needle in visuals, f"Moving first-person weapon part missing: {needle}"
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1, (
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
    "CFrame.new(plan.origin[1], plan.origin[2], plan.origin[3])",
    "CFrame.new(plan.travel[1], plan.travel[2], plan.travel[3])",
    "CFrame.Angles(plan.tumble[1], plan.tumble[2], plan.tumble[3])",
    "material = plan.hull and MATERIAL_SMOOTH or MATERIAL_METAL",
    "reflectance = plan.reflectance",
    "gravityDrop = plan.drop",
    "part.Reflectance = spec.reflectance or 0",
):
    assert needle in visuals, f"Client casings not wired: {needle}"
for needle in (
    "origin = {0.12, 0.06, 0.00}",
    "origin = {0.10, 0.08, 0.02}",
    "origin = {0.14, 0.02, 0.03}",
    "origin = {0.17, 0.09, 0.03}",
    "reflectance = 0, hull = true",
    "drop = 0.45",
):
    assert needle in ejection, f"Missing physically distinct original casing plan: {needle}"
assert visuals.count("function WeaponVisuals:_ejectCartridge(plan)") == 1
assert visuals.index("self.pendingCartridge = nil -- cancel unplayed pump/bolt on weapon swap") < (
    visuals.index("function WeaponVisuals:_ejectCartridge(plan)"))
assert "FireServer" not in ejection and "Instance.new" not in ejection
# Local FX must follow the final post-camera, animated PBR/procedural parts.
# A muzzle flash spawned from FireWeapon input sees the previous frame's gun.
fx_policy = get("src/shared/WeaponFxFramePolicy.luau")
fx_test = get("scripts/test_weapon_fx_frame_policy.luau")
for needle in ("function Policy.flashReady(", "function Policy.casingReady("):
    assert needle in fx_policy and needle.split("(")[1] in fx_test
assert 'WaitForChild("WeaponFxFramePolicy")' in visuals
assert "self.pendingLocalFlashAt = nil -- prevent late flash" in visuals
assert "self.pendingLocalFlashAt = weaponId ~= \"Knife\" and self.fireStartedAt or nil" in visuals
assert "visuals:drawLocalMuzzleFlash()" not in client, (
    "Local muzzle flash must use post-camera rendered muzzle, not input-time anchor")
render = visuals.split("function WeaponVisuals:_render(deltaTime)", 1)[1]
render = render.split("function WeaponVisuals:_spawnTransient(spec)", 1)[0]
assert render.index("entry.part.CFrame = root * localOffset") < (
    render.index("self:drawLocalMuzzleFlash()") )
assert render.index("entry.part.CFrame = root * localOffset") < (
    render.index("self:_ejectCartridge(pending.plan)") )
assert "WeaponFxFramePolicy.flashReady(self.currentWeaponId, flashAt, now)" in render
assert "WeaponFxFramePolicy.casingReady(self.currentWeaponId," in render
assert visuals.index("self.pendingCartridge = plan and {") < (
    visuals.index("function WeaponVisuals:_getAnimationCFrame(") )
assert "FireServer" not in fx_policy and "Instance.new" not in fx_policy
for needle in (
    "function Pose.get(id, imported)", "function Pose.damping(blend)",
    "sightX = 0, sightY = 0.32, sightZ = -0.05",
    "sightX = 0, sightY = 0.30, sightZ = 0.10",
    "sightX = 0, sightY = 0.24, sightZ = -0.28",
):
    assert needle in ads, f"ADS policy missing: {needle}"
for needle in (
    'WaitForChild("WeaponAimPose")',
    "WeaponAimPose.damping(self.aimBlend)",
    "self.aimPose = pose and (CFrame.new(pose.x, pose.y, pose.z)",
    "* CFrame.Angles(pose.pitch, 0, 0)) or nil",
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
assert client.count('RunService:BindToRenderStep("IronYardClientCameraFeel",') == 1, (
    "Hip-fire responsiveness must reuse the existing frame callback")
assert "FireServer" not in crosshair and "Instance.new" not in crosshair

# Fully hidden optical sniper should not write dozens of PBR primitive CFrames
# on idle Android frames, but any queued muzzle or delayed bolt casing must
# still receive the camera-final viewmodel pose before the FX is emitted.
render_policy = get("src/shared/ViewmodelRenderPolicy.luau")
assert "function Policy.skipHiddenSniper(weaponId, scoped, hidden, reloading," in render_policy
assert "return now < pendingCartridge.at" in render_policy, (
    "Scoped sniper must update its ejection anchors once the casing is due")
for needle in (
    "ViewmodelRenderPolicy.skipHiddenSniper(self.currentWeaponId, self.scoped,",
    "self.lastViewmodelHidden, self.reloadActive, self.pendingLocalFlashAt,",
    "self.pendingCartridge, clock) then",
    "self.lastCameraCFrame = camera.CFrame",
    "self.sway = self.sway * (1 - ViewmodelRenderPolicy.blendAlpha(animationDt, 14))",
):
    assert needle in visuals, f"Idle sniper optical optimization missing: {needle}"
render_start = visuals.index("function WeaponVisuals:_render(deltaTime)")
skip_start = visuals.index("if ViewmodelRenderPolicy.skipHiddenSniper(", render_start)
skip_end = visuals.index("return", skip_start)
assert visuals.index("self:_updateTransientFx(clock)", render_start) < skip_start
assert visuals.index("self:_updateImpactMarks(clock)", render_start) < skip_start
assert visuals.index("self:_refreshImportedWeaponIfSafe(clock)", render_start) < skip_start
assert visuals.index("self.lastCameraCFrame = camera.CFrame", skip_start) < skip_end
assert skip_end < visuals.index("local now = os.clock()", skip_end)
assert skip_end < visuals.index("for _, entry in ipairs(self.parts) do", skip_end)
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1

# Material-specific bullet scar footprints and per-weapon muzzle silhouettes
# must consume the same existing Parts and preset caps on Android/Desktop.
vfx_profile = get("src/shared/CombatVfxProfile.luau")
for needle in (
    "function Profile.markStyle(materialName)",
    "function Profile.muzzleSignature(weaponId)",
    "AssaultRifle = {tint", "Pistol = {tint",
    "Shotgun = {tint", "Sniper = {tint",
):
    assert needle in vfx_profile, f"Authored visual identity missing: {needle}"
for needle in (
    "local markStyle = CombatVfxProfile.markStyle(materialName)",
    "mark.Material = markStyle.metallic and MATERIAL_METAL or MATERIAL_SMOOTH",
    "markStyle.surfaceOffset",
    "local signature = CombatVfxProfile.muzzleSignature(weaponId)",
    "signature.coreRadius", "signature.finLength",
    "signature.duration",
):
    assert needle in visuals, f"Weapon/surface render integration missing: {needle}"
assert "nil, direction, true, self.currentWeaponId)" in visuals
assert client.count("nil, message.weaponId)") >= 2
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1

# Impact marks recycle as usual, but after the last mark expires no
# RenderStepped pool traversal should continue forever on mobile.
impact_pool = get("src/shared/ImpactMarkPool.luau")
assert "function Pool.live(slot, now)" in impact_pool
for needle in (
    "self.hasActiveImpactMarks = false",
    "if self.hasActiveImpactMarks and clock >= self.nextImpactMarkUpdateAt then",
    "self.hasActiveImpactMarks = true",
    "if ImpactMarkPool.live(slot, now) then",
    "self.hasActiveImpactMarks = anyLive",
):
    assert needle in visuals, f"Impact mark idle scanner guard missing: {needle}"
assert visuals.index("self.hasActiveImpactMarks = true") < (
    visuals.index("if not slot.part then", visuals.index("function WeaponVisuals:_trackImpactMark")))
assert visuals.index("self.hasActiveImpactMarks = anyLive") > (
    visuals.index("function WeaponVisuals:_updateImpactMarks"))

# Mobile VFX priority 4 must not preempt another confirmed core when a
# lower-priority dust/tracer is still active; stationary flash/glints avoid
# redundant CFrame interpolation while keeping Size/Opacity animation.
pool = get("src/shared/TransientFxPool.luau")
for needle in (
    "lowestPriority = math.huge",  # declared alongside oldestTime
    "slot.priority < lowestPriority",
    "slot.priority == lowestPriority and slot.expiresAt < oldestTime",
    "function Pool.moves(targetProvided, arcHeight, gravityDrop, spinAngle)",
):
    if needle == "lowestPriority = math.huge":
        assert "oldestTime, lowestPriority = math.huge, math.huge" in pool
    else:
        assert needle in pool, f"VFX priority or motion contract missing: {needle}"
for needle in (
    "slot.moves = TransientFxPool.moves(spec.target ~= nil,",
    "if slot.moves then",
    "part.CFrame = transform",
    "part.Size = slot.fromSize:Lerp(slot.toSize, blend)",
    "part.Transparency = math.clamp(baseAlpha",
):
    assert needle in visuals, f"Pooled stationary/mobile VFX wiring missing: {needle}"
assert visuals.index("if slot.moves then") < visuals.index("part.CFrame = transform")
assert visuals.index("part.CFrame = transform") < visuals.index(
    "part.Size = slot.fromSize:Lerp(slot.toSize, blend)")
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1

# Both paths must use deterministic post-camera render priorities.
# The gameplay/HUD pass may change camera roll/FOV; gun transform follows it.
assert 'Enum.RenderPriority.Camera.Value + 1' in client
assert 'Enum.RenderPriority.Camera.Value + 2' in visuals
assert 'RunService.RenderStepped:Connect' not in visuals
assert 'RunService.RenderStepped:Connect' not in client
assert 'ViewmodelRenderPolicy.animationDelta(deltaTime)' in visuals
for update in (
    'self.reloadBlend += (reloadTarget - self.reloadBlend) * poseAlpha',
    '* ViewmodelRenderPolicy.blendAlpha(animationDt, 9)',
    'self.aimBlend += (aimTarget - self.aimBlend) * poseAlpha',
    'local poseAlpha = ViewmodelRenderPolicy.blendAlpha(animationDt, 13)',
    'local swayAlpha = ViewmodelRenderPolicy.blendAlpha(deltaTime, 14)',
    'self:_getAnimationCFrame(animationDt, camera, self.stepBlend, reloadPose)',
):
    assert update in visuals, f"Frame-hitch-safe animation integration missing: {update}"
# A confirmed, current-epoch Ammo reload exits ADS exactly once; speculative
# requests cannot force unscoping and other-weapon snapshots cannot interfere.
aim_reload = get("src/shared/WeaponAimReloadPolicy.luau")
for needle in (
    "function P.canEnterAim(ammo)",
    "function P.releaseOnConfirmedReload(equippedWeapon, updatedWeapon, reloading, scoped)",
    "and reloading == true and scoped == true",
):
    assert needle in aim_reload
for needle in (
    'WaitForChild("WeaponAimReloadPolicy")',
    'not WeaponAimReloadPolicy.canEnterAim(ammoByWeapon[currentWeaponId])',
    'WeaponAimReloadPolicy.releaseOnConfirmedReload(currentWeaponId,',
    'message.weaponId, message.reloading, scoped)',
):
    assert needle in client, f"ADS/reload coherence missing: {needle}"
assert 'FireServer' not in aim_reload and 'Instance.new' not in aim_reload
confirmed = client.index("WeaponAimReloadPolicy.releaseOnConfirmedReload(currentWeaponId,")
assert client.index("if not FireEpochPolicy.acceptAmmo(", 0, confirmed) < confirmed
assert client.index("ammoByWeapon[message.weaponId] = {", 0, confirmed) < confirmed
assert confirmed < client.index("visuals:setReloading(message.weaponId, message.reloading == true,", confirmed)
request_body = client[client.index("local function requestReload()"):client.index("local function fireWeapon(")]
assert "setScoped(false)" not in request_body, (
    "Rejected reload must not un-scope before server confirmation")
# No speculative reload animation: the server-validated Ammo delta must
# confirm a real refill before the PBR slide/charging handle or sniper bolt racks.
rack_policy = get("src/shared/WeaponReloadFinishPolicy.luau")
for needle in (
    "function P.confirmed(weaponId, wasReloading, nowReloading, previousLoaded, loaded, capacity)",
    'or weaponId == "Sniper")',
    "function P.sample(weaponId, age, reloading)",
    "return smooth((age - 0.025) / 0.125)",
):
    assert needle in rack_policy
for needle in (
    'WaitForChild("WeaponReloadFinishPolicy")',
    "WeaponReloadFinishPolicy.confirmed(weaponId, wasReloading,",
    "self.reloadFinishedAt = os.clock()",
    "WeaponReloadFinishPolicy.sample(self.currentWeaponId,",
    "actionTravel = math.max(actionTravel, rack)",
    "self.lastAmmoLoaded = loaded",
):
    assert needle in visuals, f"Reload cycle missing {needle}"
assert "visuals:setReloading(message.weaponId, message.reloading == true," in client
assert "visuals:setReloading(weaponId, ammunition.reloading," in client
assert '"lastAmmoLoaded", "reloadFinishedAt"' in swap_state
assert 'FireServer' not in rack_policy and 'Instance.new' not in rack_policy
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1
# Detachable PBR/Part magazines have a subtle, mechanically coherent
# extraction tilt on the SAME authoritative reload timeline. Fixed legacy
# PBR pistol magazines must never animate independently.
magazine_pose = get("src/shared/WeaponMagazinePose.luau")
for needle in (
    "function Pose.sample(weaponId, dip, travel, imported, hasMagazine)",
    'weaponId == "Pistol"',
    "hasMagazine ~= true",
    "math.clamp(dip, 0, 1)",
):
    assert needle in magazine_pose
for needle in (
    'WaitForChild("WeaponMagazinePose")',
    "local magX, magY, magZ, magRoll = WeaponMagazinePose.sample(",
    "CFrame.Angles(0, 0, magRoll)",
):
    assert needle in visuals, f"Detachable magazine pose missing: {needle}"

# Reload support hands must follow authored mechanical PBR pieces, not
# restart or teleport after a deferred asset upgrade or server cancel.
reload_hand = get("src/shared/WeaponReloadHandPlan.luau")
for needle in (
    "function Plan.sample(weaponId, progress, active, dip, handTravel, preset, imported, hasMagazine, shellPhase)",
    'weaponId == "AssaultRifle"',
    'weaponId == "Shotgun"',
    "smooth(0.27, 0.74, p)",
    'preset == "ECO"',
    "return 0, 0, 0",
    'weaponId == "Pistol"',
    "function Plan.pistolVisibility(progress, active)",
    "function Plan.boltGrip(weaponId, boltPull, boltLift, reloading, scoped)",
):
    assert needle in reload_hand, f"Reload hand choreography missing: {needle}"
for needle in (
    'WaitForChild("WeaponReloadHandPlan")',
    "WeaponReloadHandPlan.sample(",
    "local handAlpha = ViewmodelRenderPolicy.blendAlpha(animationDt, 14)",
    "self.magazineDipBlend += (magazineTarget - self.magazineDipBlend) * handAlpha",
    "self.pistolOffhandAlpha += (pistolHandTarget - self.pistolOffhandAlpha) * handAlpha",
    "if opacity >= 1 then continue end",
    "self.reloadHandX += (handX - self.reloadHandX) * handAlpha",
    "self.reloadHandY += (handY - self.reloadHandY) * handAlpha",
    "self.reloadHandZ += (handZ - self.reloadHandZ) * handAlpha",
    "local workingHand = CFrame.new(self.reloadHandX, self.reloadHandY, self.reloadHandZ)",
    "localOffset = localOffset * workingHand * supportMotion",
    "WeaponReloadHandPlan.pistolVisibility(progress, self.reloadActive)",
    "WeaponReloadHandPlan.boltGrip(",
    "localOffset = localOffset * boltHand",
    "1 - pistolHandVisibility",
    "and CFrame.new(0, 0, actionTravel * feel.actionTravel * 0.72)",
):
    assert needle in visuals, f"Client support hand motion not wired: {needle}"
for needle in (
    '"reloadHandX", "reloadHandY", "reloadHandZ"',
    "WeaponMeshSwapState.capture(self)",
    "WeaponMeshSwapState.restore(self, previousPose)",
):
    assert needle in swap_state or needle in visuals, f"Reload pose not safely preserved: {needle}"
# The second pistol hand may never leak into the ordinary hip-fire stance.
assert 'target = 1' in visuals and '1 - pistolHandVisibility' in visuals
assert 'function Policy.blendAlpha(dt, rate)' in get("src/shared/ViewmodelRenderPolicy.luau")
assert '"magazineDipBlend", "pistolOffhandAlpha"' in swap_state
assert visuals.index('if opacity >= 1 then continue end') < (
    visuals.index('localOffset = localOffset * workingHand * supportMotion'))
assert visuals.count('RunService:BindToRenderStep("IronYardWeaponViewmodel",') == 1
assert visuals.count('CFrame.new(-0.27, -0.54, 0.08)') == 2, (
    "PBR and procedural pistol must share the same support-hand origin")
# Ensure authentic Blender pistol magazine survives validated owner-only
# loading, reaches first-person PBR, and follows physical Part reload timing.
assert '"IRONYARD_Pistol_Magazine"' in weapon_forge
assert '"pistol":{"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide","IRONYARD_Pistol_Magazine"}' in weapon_validator
assert 'P.Optional={Pistol={"IRONYARD_Pistol_Magazine"}}' in mesh_policy
assert 'IRONYARD_Pistol_Magazine="Magazine"' in mesh_policy
assert 'MeshPolicy.Optional[weaponId]' in asset_loader
assert 'WeaponMeshPolicy.Optional[weapon]' in studio_importer
assert 'WeaponMeshPolicy.Optional[weaponId]' in visuals
assert 'self.currentWeaponHasPbrMagazine = weaponId == "Pistol"' in visuals
assert 'selected.IRONYARD_Pistol_Magazine ~= nil' in visuals
assert 'self.currentWeaponImported, self.currentWeaponHasPbrMagazine' in visuals
assert 'if imported == true and hasMagazine ~= true then' in reload_hand
# The actual sniper bolt geometry and glove share the exact ejection
# phase: unlock -> pull -> casing at max pull -> return -> relock.
sniper_bolt = get("src/shared/SniperBoltCycle.luau")
assert 'Cycle.PULL_END = 0.43' in sniper_bolt
assert 'delay = 0.43' in ejection
for needle in (
    "function Cycle.sample(shotAge, reloading)",
    "Cycle.UNLOCK_START", "Cycle.UNLOCK_END",
    "Cycle.RETURN_END", "Cycle.LOCK_END",
    "Cycle.RELOAD_DURATION = Cycle.LOCK_END - Cycle.UNLOCK_START",
    "function Cycle.sampleReload(confirmedAge, reloading)",
    "function Cycle.present(shotAge, confirmedAge, reloading)",
):
    assert needle in sniper_bolt, f"Sniper bolt timing missing: {needle}"
for needle in (
    'WaitForChild("SniperBoltCycle")',
    'boltLift, boltPull = SniperBoltCycle.present(',
    'shotAge, now - self.reloadFinishedAt, self.reloadActive)',
    "self.currentWeaponId, boltPull, boltLift, self.reloadActive, self.scoped",
    "feel.actionTravel * boltPull",
    "math.rad(32 * boltLift)",
):
    assert needle in visuals, f"Sniper bolt/hand geometry not synchronized: {needle}"
assert "FireServer" not in sniper_bolt and "Instance.new" not in sniper_bolt
assert "Instance.new" not in reload_hand and "FireServer" not in reload_hand
assert "targetHumanoid:TakeDamage(damage)" in server
assert "fireCooldown = 0.115" in config, "Server/weapon cadence not rewritten"
print("IRON YARD five original viewmodels and bounded spatial audio wiring: OK")
