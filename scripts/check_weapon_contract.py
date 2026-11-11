#!/usr/bin/env python3
"""Static source-contract checks for IRON YARD weapon integration.

Checks cross-module wiring that syntax compilation alone cannot detect.
Does NOT test Roblox physics, latency, game balance or touch behavior.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition, description):
    if not condition:
        raise AssertionError(description)


def has(src, text, label):
    require(text in src, f"{label}: missing `{text}`")


def main():
    config = source("src/shared/WeaponConfig.luau")
    network = source("src/shared/PrecisionNet.luau")
    server = source("src/server/WeaponService.luau")
    shot_input = source("src/shared/ShotInputPolicy.luau")
    spread_policy = source("src/shared/WeaponSpreadPolicy.luau")
    aim_policy = source("src/shared/AimStancePolicy.luau")
    movement_service = source("src/server/MovementService.luau")
    rate_policy = source("src/shared/RemoteRatePolicy.luau")
    client = source("src/client/init.client.luau")
    gamepad_policy = source("src/shared/GamepadCombatPolicy.luau")
    briefing = source("src/client/Briefing.client.luau")
    guide = source("src/shared/FirstMatchGuide.luau")
    for token in (
        'ButtonR2 = "FIRE"',
        'ButtonL2 = "AIM"',
        'ButtonX = "RELOAD"',
        'ButtonY = "NEXT_WEAPON"',
        'ButtonR1 = "THROW_KNIFE"',
        'ButtonB = "SLIDE"',
        'ButtonL3 = "SPRINT"',
        'ButtonA = "JUMP"',
        'ButtonStart = "SETTINGS"',
        "function Policy.isGamepad(inputTypeName)",
        "function Policy.cycle(order, current, direction)",
    ):
        has(gamepad_policy, token, "Complete native controller binding policy")
    for token in (
        'WaitForChild("GamepadCombatPolicy")',
        "local function onGamepadPressed(input, gameProcessed)",
        "GamepadCombatPolicy.isGamepad(input.UserInputType.Name)",
        "GamepadCombatPolicy.action(input.KeyCode.Name)",
        "GamepadCombatPolicy.cycle(WeaponConfig.Order,",
        "if onGamepadPressed(input, gameProcessed) then return end",
        "local function beginHeldFire(gamepad)",
        "local primaryFireTaskActive = false",
        "UserInputService.GamepadDisconnected:Connect(releaseControllerInputs)",
        "UserInputService.WindowFocusReleased:Connect(clearHeldCombatInput)",
        "if isOpen and clearHeldCombatInput then clearHeldCombatInput() end",
        "or gamepadJumpHeld)",
        "if native and native.Magnitude >= 0.15 then",
        "UserInputService.LastInputTypeChanged:Connect(updateTouchVisibility)",
        "local enabled = playable and not controllerActive",
        'if newPhase ~= "LIVE" and newPhase ~= "COUNTDOWN" then',
        "clearHeldCombatInput()",
        'elseif scoped and newPhase == "LIVE" then',
    ):
        has(client, token, "Controller input, safe release, camera and mobile UX")
    assert client.index("local primaryFireTaskActive = false") < (
        client.index("UserInputService.InputBegan:Connect(function(input, gameProcessed)")
    ), "Only one automatic-fire task shared by mouse and gamepad"
    assert client.index("if onGamepadPressed(input, gameProcessed) then return end") < (
        client.index("if gameProcessed then", client.index(
            "UserInputService.InputBegan:Connect(function(input, gameProcessed)")
        )
    ), "Gamepad dispatch must precede keyboard event processing"
    assert client.index("if not playable then", client.index(
        "updateTouchVisibility = function()")) > client.index(
        "local enabled = playable and not controllerActive"
    ), "Hiding touch UI for Bluetooth pad must not un-aim a live controller"
    for token in (
        'WaitForChild("GamepadCombatPolicy")',
        "local function controllerActive()",
        "Guide.hint(UserInputService.TouchEnabled, 1,",
        "controllerActive() and",
    ):
        has(briefing, token, "Player-facing controller onboarding")
    has(guide, 'if gamepad == true then', "Controller-specific first match tips")
    # The first-person client predicts ammo immediately before FireServer;
    # on a server-rejected but otherwise valid shot, authoritative ammo MUST
    # be resent. Without this the HUD can remain at zero until respawn.
    assert 'ammo.loaded = math.max(0, ammo.loaded - 1)' in client
    assert 'remotes.FireWeapon:FireServer({' in client
    assert client.index('ammo.loaded = math.max(0, ammo.loaded - 1)') < (
        client.index('remotes.FireWeapon:FireServer({')
    )
    assert 'function WeaponService.start()' in server
    rejection = server.split(
        "local function rejectFireWithAmmo(player, weaponId)", 1
    )[1].split("local function acceptedAimReady(", 1)[0]
    assert "sendAmmo(player, weaponId)\n    return false" in rejection
    assert rejection.count("return rejectFireWithAmmo(player, weaponId)") == 4
    assert rejection.index("return rejectFireWithAmmo(player, weaponId)") < (
        rejection.index("state.magazines[weaponId] = loaded - 1")
    ), "Rejected cooldown / equip / reload shots must not consume server ammo"
    blocked_reload = server.split("local function reloadWeapon(player, weaponId)", 1)[1]
    blocked_reload = blocked_reload.split("local function rejectFireWithAmmo", 1)[0]
    assert 'RemoteGuard.allow(player, "ReloadWeapon")' in blocked_reload
    assert 'if loaded >= config.magazineSize or (state.reloadUntil[weaponId] or 0) > os.clock() then' in blocked_reload
    assert blocked_reload.index('sendAmmo(player, weaponId)\n        return') > (
        blocked_reload.index("if loaded >= config.magazineSize")
    ), "Full / already-active reloads must correct a stale predicted client HUD"
    assert 'if not RemoteGuard.allow(player, "FireWeapon") then return end' in server
    assert server.index('if not RemoteGuard.allow(player, "FireWeapon") then return end') < (
        server.index("if not canFire(player, weaponId, config) then")
    ), "Only rate-admitted valid shots may trigger ammo resynchronization"

    viewmodel = source("src/client/WeaponVisuals.luau")
    hud = source("src/client/HudController.luau")
    match = source("src/server/MatchService.luau")
    bot = source("src/server/BotService.luau")
    score_service = source("src/server/ScoreService.luau")
    death_life = source("src/shared/PlayerDeathLifecycle.luau")
    for needle in (
        "function Lifecycle.new()",
        "function Lifecycle.bind(state, character)",
        "function Lifecycle.retire(state, character)",
        "function Lifecycle.bindHumanoid(state, token, character, humanoid, currentCharacter)",
        "function Lifecycle.recordDeath(state, token, character, humanoid, currentCharacter, live)",
        "state.recorded = true",
        "or state.humanoid ~= humanoid or currentCharacter ~= character",
    ):
        has(death_life, needle, "Server-owned one-life, one-death score policy")
    for needle in (
        'WaitForChild("PlayerDeathLifecycle")',
        "local playerBindings = {}",
        "local function retireCharacter(state, character)",
        "state.deathConnection:Disconnect()",
        "local function releasePlayer(player)",
        "state.characterAdded:Disconnect()",
        "state.characterRemoving:Disconnect()",
        "playerBindings[player] = nil",
        "local generation = Life.bind(state.life, character)",
        "or not Life.bindHumanoid(state.life, generation, character,",
        "state.deathConnection = humanoid.Died:Connect(onDeath)",
        "if not Life.recordDeath(state.life, generation, character,",
        'Workspace:GetAttribute("NeonMatchPhase") == "LIVE"',
        'local currentStats = player:FindFirstChild("leaderstats")',
        "CombatAwards.recordDeath(player)",
        "Players.PlayerRemoving:Connect(releasePlayer)",
    ):
        has(score_service, needle, "Server must reject stale or replayed death events")
    require("player.CharacterAdded:Connect(watchCharacter)" in score_service,
            "New respawns must rebind a single active Humanoid event")
    require('humanoid.Died:Connect(function()' not in score_service,
            "Death events must be guarded by the active life generation")
    has(server, 'or player.Parent ~= Players',
        "In-flight player projectiles must stop after PlayerRemoving")

    # Hot path: only the thrown knife needs its own mutable RaycastParams,
    # because that projectile also excludes its own Part. Hitscan/pellet
    # weapons must reuse a read-only filter for the current character.
    for needle in (
        'WaitForChild("ShotInputPolicy")',
        "if not ShotInputPolicy.validDirection(",
        "direction.X, direction.Y, direction.Z) then return nil end",
        "local function shotRaycastParams(player, character)",
        "if state.shotRayCharacter ~= character or not state.shotRayParams then",
        "state.shotRayParams = makeRaycastParams({ character })",
        "state.shotRayCharacter = character",
        "return state.shotRayParams",
        "state.shotRayParams = nil",
        "state.shotRayCharacter = nil",
        "player.CharacterRemoving:Connect(function(character)",
    ):
        has(server, needle, "Allocation-free server fire hot path")
    for needle in (
        "local function convergeCameraAim(player, payload, direction, config, character, head)",
        'if typeof(cameraOrigin) ~= "Vector3" then return direction end',
        "ShotInputPolicy.validCameraOffset(offset.X, offset.Y, offset.Z)",
        "workspace:Raycast(head.Position, offset, params)",
        "workspace:Raycast(cameraOrigin, direction * config.range, params)",
        "local fromHead = aimPoint - head.Position",
        "fromHead:Dot(direction) <= 0",
        "return fromHead.Unit",
        "direction = convergeCameraAim(player, payload, direction, config,",
        "if not canFire(player, weaponId, config) then",
        "local origin = head.Position",
    ):
        has(server, needle, "Server-side sight convergence without camera-origin damage")
    for needle in (
        "Policy.MAX_CONVERGENCE_OFFSET = 4.5",
        "function Policy.validCameraOffset(dx, dy, dz)",
        "validNumber(dx) and validNumber(dy) and validNumber(dz)",
    ):
        has(shot_input, needle, "Bounded camera aim origin; fallback under high latency")
    require(server.index("if not canFire(player, weaponId, config) then") <
            server.index("direction = convergeCameraAim(") <
            server.index("SpawnService.clearProtection(player.Character)"),
            "Only admitted shots may spend convergence raycasts")
    require(server.count("local origin = head.Position") == 2,
            "Rifle and shotgun must keep server-owned Head origins")
    require("local start = head.Position" in server,
            "Knife must keep its server-owned Head origin")
    require(server.count("workspace:Raycast(cameraOrigin, direction * config.range, params)") == 1,
            "Only one camera sight ray for each accepted converged aim")
    require(server.count("local params = shotRaycastParams(player, character)") == 3,
            "Convergence reuses the existing character raycast filter")
    require(server.count("makeRaycastParams({ character })") == 2,
            "Only one cached hitscan filter and one mutable knife filter permitted")
    # Existing hot-path shot filters must still be used by hitscan & pellets.
    # Their cached instance is shared with optional convergence.
    # The check below replaces the previous two-use assertion.
    # Remainder of weapon regression remains unchanged.
    require(server.count("local params = shotRaycastParams(player, character)") == 3,
            "Rifle/sniper/pistol and shotgun must reuse character raycast filters")
    require(server.count("makeRaycastParams({ character })") == 2,
            "Only one cached hitscan filter and one mutable knife filter permitted")
    require("ipairs({ direction.X, direction.Y, direction.Z })" not in server,
            "Client aim validation must never allocate per-shot coordinate arrays")
    for needle in (
        "function Policy.validDirection(x, y, z)",
        "return validNumber(x) and validNumber(y) and validNumber(z)",
        "x * x + y * y + z * z >= 0.000001",
        "n >= -1000000",
        "n <= 1000000",
    ):
        has(shot_input, needle, "Nonfinite and tiny client shot vectors must be rejected")

    # A successful hitscan/shotgun/bot shot needs ONE WeaponFx broadcast,
    # not a separate FireSound broadcast followed by a tracer broadcast.
    # Thrown knives do not send PlayerTracer and keep FireSound on its own.
    for needle in (
        "local function broadcastFireFx(player, weaponId, origin, soundOnly)",
        "BotHearingService.record(player.Character, weaponId, origin)",
        "if soundOnly then",
        'kind = "FireSound"',
        'kind = "PlayerTracer"',
        "broadcastTrace(player, weaponId, origin, shotDirection, config.range, result)",
        "broadcastFireFx(player, weaponId, start, true)",
        "broadcastFireFx(player, weaponId, origin, true)",
    ):
        has(server, needle, "Consolidated hitscan audio / knife-only audio")
    require(server.count("broadcastFireFx(player, weaponId, origin)") == 2,
            "Raycast and shotgun shots must emit sound using their tracer packet")
    require(server.count("broadcastFireFx(player, weaponId, origin, true)") == 1,
            "Only in-flight knife launch needs its separate audio packet")
    require(server.count("CombatFxRelay.send(remotes.WeaponFx, {") == 2,
            "PlayerTracer and knife-only FireSound must use filtered server routing")
    require("remotes.WeaponFx:FireAllClients({" not in server,
            "Never broadcast player shot FX to an entire distant lobby")
    require(bot.count("CombatFxRelay.send(remotes.WeaponFx, {") == 1
            and 'kind = "BotTracer"' in bot
            and 'weaponId = "AssaultRifle"' in bot
            and 'kind = "FireSound"' not in bot
            and 'BotHearingService.record(bot.model, "AssaultRifle", origin)' in bot
            and "remotes.WeaponFx:FireAllClients({" not in bot,
            "Bot audio and tracer must share one filtered server packet")
    audience = source("src/shared/CombatFxAudience.luau")
    relay = source("src/server/CombatFxRelay.luau")
    for needle in (
        "Audience.MAX_DISTANCE = 256",
        "Audience.MAX_DISTANCE_SQUARED = Audience.MAX_DISTANCE * Audience.MAX_DISTANCE",
        "function Audience.wants(origin, listener, isShooter, isActive)",
        "if isShooter == true or isActive ~= true then return true end",
        "if not validPosition(origin) or not validPosition(listener) then",
        "return dx * dx + dy * dy + dz * dz <= Audience.MAX_DISTANCE_SQUARED",
        "function Audience.deliveryMode(included, total)",
        "Audience.ROSTER_REFRESH_SECONDS = 0.15",
        "function Audience.needsRosterRefresh(now, previous, dirty)",
    ):
        has(audience, needle, "Conservative visual-only recipient policy")
    for needle in (
        'WaitForChild("CombatFxAudience")',
        "local function invalidateRoster()",
        "Players.PlayerAdded:Connect(invalidateRoster)",
        "Players.PlayerRemoving:Connect(invalidateRoster)",
        "local function refreshRoster()",
        "Audience.needsRosterRefresh(now, rosterAt, rosterDirty)",
        "for _, viewer in ipairs(Players:GetPlayers()) do",
        'character:FindFirstChildOfClass("Humanoid")',
        'character:FindFirstChild("HumanoidRootPart")',
        "local function observerPosition(entry)",
        "if viewer.Character ~= character then",
        "rosterDirty = true",
        "if humanoid.Health <= 0 then return nil, false end",
        "return root.Position, true",
        "function Relay.send(remote, payload, origin, shooter)",
        "local players = refreshRoster()",
        "Audience.wants(origin, position, viewer == shooter, active)",
        "Audience.deliveryMode(#recipients, #players)",
        'if mode == "ALL" then',
        'remote:FireAllClients(payload)',
        'elseif mode == "SOME" then',
        'remote:FireClient(viewer, payload)',
        'if viewer.Parent == Players then',
    ):
        has(relay, needle, "Route only cosmetic packets and retain crowded-lobby broadcast")
    for name, content in (("WeaponService", server), ("BotService", bot)):
        has(content, 'require(script.Parent:WaitForChild("CombatFxRelay"))',
            "All accepted shots use the server-only recipient router: " + name)
    require("CombatFxRelay.send(" not in client,
            "Clients may not choose the recipient list or send combat authority")
    require("remotes.KillFeed:FireAllClients({" in server
            and "remotes.KillFeed:FireAllClients({" in bot,
            "Authoritative global elimination feed must remain broadcast")

    player_audio = client.index('elseif message.kind == "PlayerTracer"')
    player_budget = client.index("local remoteAccepted = not ownShot and RemoteCombatFxBudget.allow(")
    bot_audio = client.index('elseif message.kind == "BotTracer"')
    bot_budget = client.index("local botFxBudget = CombatVfxProfile.budget(")
    require(player_audio < client.index("visuals:playFireSound(message.weaponId, message.origin)",
                                        player_audio) < player_budget,
            "Remote player audio must play even when the tracer budget is exhausted")
    require(bot_audio < client.index("visuals:playFireSound(message.weaponId, message.origin)",
                                     bot_audio) < bot_budget,
            "Bot audio must remain independent of the cosmetic tracer budget")
    has(client, "if message.shooterUserId ~= player.UserId then",
        "Locally predicted shot audio must not play twice")
    has(client, 'message.kind == "FireSound"', "Knife-only audio packet remains supported")


    order = re.search(r"WeaponConfig.Order\s*=\s*\{([^}]+)\}", config)
    require(order is not None, "Weapon order missing")
    names = re.findall(r'"([A-Za-z]+)"', order.group(1))
    require(names == ["AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife"],
            f"Five-slot order mismatch: {names}")
    require(config.count("magazineSize =") == 4, "Four firearms need magazine sizes")
    require(config.count("reloadSeconds =") == 4, "Four firearms need reload times")
    has(config, 'kind = "Pellet"', "Shotgun definition")
    has(config, "pellets = 8", "Shotgun pellet cap")
    has(config, "automatic = true", "Rifle automatic configuration")
    for key in ("AssaultRifle", "Shotgun", "Sniper", "Pistol"):
        has(config, "aimFov" if key != "Sniper" else "zoomFieldOfView",
            f"ADS support {key}")

    # Competitive first-shot accuracy is server-only. This policy cannot
    # trust a client spread claim or advance after a rejected shot.
    for needle in (
        "function Policy.next(weaponId, previousAt, previousBurst, now, maxDegrees)",
        "Policy.RESET_SECONDS = 0.38",
        "Policy.FIRST_SHOT_DEGREES = 0.17",
        "Policy.STEP_DEGREES = 0.23",
        'weaponId ~= "AssaultRifle"',
    ):
        has(spread_policy, needle, "Pure authoritative burst profile")
    for needle in (
        'WaitForChild("WeaponSpreadPolicy")',
        "lastSpreadAt = {}", "spreadCount = {}",
        "local function acceptedRaycastSpread(player, weaponId, config)",
        "WeaponSpreadPolicy.next(weaponId,",
        "state.lastSpreadAt[weaponId] = now",
        "state.spreadCount[weaponId] = count",
        "local function fireRaycastWeapon(player, weaponId, config, direction, coneDegrees)",
        "randomSpread(direction, coneDegrees)",
        "local coneDegrees = acceptedRaycastSpread(player, weaponId, config)",
        "fireRaycastWeapon(player, weaponId, config, direction, coneDegrees)",
        "state.lastSpreadAt = {}",
        "state.spreadCount = {}",
    ):
        has(server, needle, "Accepted-only burst cone and respawn reset")
    require(server.index("if not canFire(player, weaponId, config) then") <
            server.index("local coneDegrees = acceptedRaycastSpread(player, weaponId, config)"),
            "Rejected shots must not grow the server burst")
    require(server.count("state.lastSpreadAt = {}") == 2
            and server.count("state.spreadCount = {}") == 2,
            "Both round reset and character respawn must reset server burst")
    require("spreadDegrees = " not in source("src/client/init.client.luau"),
            "Client should never send/choose weapon dispersion")

    for needle in (
        "function Aim.ready(aimSince, now, movementAllowed, grounded, planarSpeed)",
        "function Aim.cone(weaponId, baseDegrees, ready)",
        "Aim.SETTLE_SECONDS = 0.14", "Aim.MAX_AIM_WALK_SPEED = 23",
    ):
        has(aim_policy, needle, "Pure ADS policy")
    for needle in (
        'WaitForChild("AimStancePolicy")',
        'local function onSetAiming(player, enabled)',
        'RemoteGuard.allow(player, "SetAiming")',
        'typeof(enabled) ~= "boolean"',
        'state.aimSince = os.clock()',
        'state.aimCharacter == character and state.aimWeaponId == weaponId',
        'local function acceptedAimReady(player, weaponId, character, humanoid, root)',
        'MovementService.aimMovementAllowed(player)',
        'humanoid.FloorMaterial ~= Enum.Material.Air',
        'AimStancePolicy.ready(state.aimSince, os.clock(),',
        'AimStancePolicy.cone(weaponId, coneDegrees, aimed)',
        'AimStancePolicy.cone(weaponId, config.spreadDegrees, aimed)',
        'remotes.SetAiming.OnServerEvent:Connect(onSetAiming)',
    ):
        has(server, needle, "Validated server aiming")
    has(network, 'SetAiming = "RemoteEvent"', "ADS transport")
    has(rate_policy, 'SetAiming = { rate = 10, burst = 8 }', "ADS flood budget")
    has(movement_service, "function MovementService.aimMovementAllowed(player)",
        "Server movement admission for ADS")
    require(server.count("state.aimSince = nil") == 4,
        "ADS must reset on scope release, equip, round and respawn")
    for needle in (
        "remotes.SetAiming:FireServer(scoped)",
        "cancelAimForMobility = function()",
        "if enabled and cancelAimForMobility then",
        'workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(function()',
        'remotes.SetAiming:FireServer(true)',
    ):
        has(client, needle, "ADS transition to server")
    require("payload.scoped" not in server and "payload.aiming" not in server,
        "Per-shot client requests cannot grant their own ADS buff")
    require(server.index("if not canFire(player, weaponId, config) then") <
        server.index("local aimed = acceptedAimReady(player, weaponId,"),
        "ADS only evaluated on admitted shots")

    duel_rules = source("src/shared/DuelRules.luau")
    duel_gate = source("src/server/DuelCombatState.luau")
    duel_readout = source("src/shared/DuelReadout.luau")
    match_hud = source("src/client/MatchHud.client.luau")
    duel_spawn = source("src/server/SpawnService.luau")
    duel_spawn_plan = source("src/shared/DuelSpawnPlan.luau")
    duel_supply = source("src/server/SupplyService.luau")
    for token in (
        "function Duel.canStart(players, readyA, readyB)",
        "function Duel.sameParticipants(players, first, second)",
        "function Duel.forfeitSide(activePlayers, first, second)",
        "function Duel.boutWinner(healthA, maximumA, healthB, maximumB, expired)",
        "function Duel.healthForBout(expectedCharacter, actualCharacter, health, maxHealth)",
        "function Duel.advance(scoreA, scoreB, bouts, result)",
        "function Duel.canFight(mode, userId, a, b, playerCount)",
        "function Duel.recoveryExpired(since, now)",
        "function Duel.prepValid(expectedA, actualA, readyA, expectedB, actualB, readyB)",
    ):
        has(duel_rules, token, "Pure first-to-five duel rules")
    for token in (
        'SetDuelReady = "RemoteEvent"',
    ):
        has(network, token, "Duel ready event")
    for token in (
        'remotes.SetDuelReady.OnServerEvent:Connect(function(player, enabled)',
        'RemoteGuard.allow(player, "SetDuelReady")',
        'local function startDuelSeries(players)',
        'local function startDuelBout()',
        'if not duel and mode == "FFA" then',
        'local candidates = readyPlayers()',
        'local function finishDuelBout(result)',
        'local function endDuel(reason, winningSide)',
        'DuelRules.boutWinner(ah,am,bh,bm,remaining<=0)',
        'BotService.reconcileNow()',
        'SpawnService.placeDuelPair(a,b,duel.bouts+1)',
        'WeaponService.resetRound()',
        'Workspace:SetAttribute("IronYardMatchMode", mode)',
        'transition("DUEL_BREAK", DUEL_BREAK_SECONDS)',
        'DuelRules.recoveryExpired(duel and duel.waitSince, os.clock())',
        'endDuel("SPAWN_TIMEOUT", nil)',
        'players[1]:SetAttribute("IronYardDuelReady", false)',
        'players[2]:SetAttribute("IronYardDuelReady", false)',
        'duel.waitSince = nil',
        'duel.waitSince = duel.waitSince or os.clock()',
        'DuelRules.sameParticipants(Players:GetPlayers(), a, b)',
        'aPlayer=players[1], bPlayer=players[2]',
        'duel.waitSince = os.clock()',
        'local function releaseDuelPrep()',
        'local function startLiveDuelBout()',
        'phase == "DUEL_PREP" and remaining <= 0',
        'transition("DUEL_PREP", DuelRules.PREP_SECONDS)',
        'SpawnService.clearProtection(a.Character)',
        'SpawnService.clearProtection(b.Character)',
        'duel.liveCharacterA = a.Character',
        'duel.liveCharacterB = b.Character',
        'DuelRules.healthForBout(expectedCharacter, c,',
        'local ah,am=health(a, duel.liveCharacterA)',
        'local bh,bm=health(b, duel.liveCharacterB)',
        'MovementService.resetDuelMovement(a)',
        'MovementService.resetDuelMovement(b)',
    ):
        has(match, token, "Duel lifecycle without FFA regression")
    has(duel_spawn, 'if Workspace:GetAttribute("IronYardMatchMode") == "DUEL" then',
        "No delayed FFA placement during duel preparation")
    for token in (
        'function SpawnService.placeDuelPair(a, b, bout)',
        'clearAt(position, aChar, bChar)',
        'DuelSpawnPlan.select(clear, bout)',
        'SpawnService.place(a, aChar, first, second, bChar)',
        'SpawnService.place(b, bChar, second, first, aChar)',
    ):
        has(duel_spawn, token, "Collision-safe opposite duel spawns")
    for token in (
        'function Plan.select(clear, bout)',
        'Plan.PAIRS = {{1,4}, {2,3}, {5,8}, {6,7}, {9,10}, {11,12}}',
    ):
        has(duel_spawn_plan, token, "Validated opposing spawn pad policy")
    for token in (
        'prompt.Enabled = ready and not duelActive',
        'if Workspace:GetAttribute("IronYardMatchMode") == "DUEL" then return false end',
        'Workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(function()',
    ):
        has(duel_supply, token, "Fair-play medical disable in duel")
    has(match, 'if winningPlayer and winningPlayer.Parent == Players',
        "Only present combatants can receive duel victories")
    for token in (
        "local side = DuelRules.forfeitSide(Players:GetPlayers(), a, b)",
        'endDuel(side and "FORFEIT" or "LOBBY_CHANGED", side)',
        'local forfeitChampion = reason == "FORFEIT"',
        "RoundStandings.build(duelRows(), round, forfeitChampion)",
        'snapshot.winnerUserId = winningSide == "A" and duel.aId',
    ):
        has(match, token, "Survivor-only duel forfeit and consistent podium")
    require('and (a and "A" or b and "B" or nil)' not in match,
            "Stale saved Player references cannot select the duel winner")
    for token in (
        "function RoundStandings.build(rawEntries, roundNumber, championUserId)",
        "if a == championRow then return true end",
        "entry.rank = championRow and index or lastRank",
    ):
        has(source("src/server/RoundStandings.luau"), token,
            "Forfeit result podium prioritizes verified survivor without fake wins")

    has(match, 'and reason == "SCORE_LIMIT" then',
        "Forfeits and spawn failures must not farm progression awards")
    has(match, '(duel ~= nil and phase ~= "RESULTS")',
        "No forced duel ready state during active competition")
    for token in (
        'DuelCombatState.canFire(player,',
        'DuelCombatState.canDamage(attacker, targetPlayer, targetCharacter,',
        'if not duelCanDamage(attacker, targetPlayer, targetCharacter) then return false end',
        'if not duelCanFire(player) then return end',
        'if duelCanDamage(player, opponent, model)',
        'elseif duelCanDamage(player, opponent, model)',
        'duelCanDamage(player, entry.player, entry.model)',
        'or not duelCanFire(player)',
    ):
        has(server, token, "All duel hit paths bound to original rigs")
    for token in (
        "local function validId(id)",
        "function Gate.begin(a, b)",
        "function Gate.clear()",
        "function Gate.canFire(player, phase, mode, playerCount)",
        "function Gate.canDamage(attacker, target, model, phase, mode, playerCount)",
    ):
        has(duel_gate, token, "Per-bout real Character gate")
    for token in ("DuelCombatState.begin(a, b)", "DuelCombatState.clear()"):
        has(match, token, "Lifecycle opens and closes combat ownership")
    for token in (
        'function Readout.scores(userId, aId, bId, aWins, bWins)',
        'function Readout.boutLabel(result, userId, aId, bId)',
    ):
        has(duel_readout, token, "Safe verified duel readout")
    for token in (
        'Workspace:SetAttribute("IronYardDuelLastResult", result)',
        'Workspace:SetAttribute("IronYardDuelLastResult", "")',
    ):
        has(match, token, "Server-published round outcome and reset")
    for token in (
        'function BotService.reconcileNow()',
        'if Workspace:GetAttribute("IronYardMatchMode") == "DUEL" then',
    ):
        has(bot, token, "Immediate bot removal in duel")
    for token in (
        'DuelReadout.scores(player.UserId,',
        'DuelReadout.boutLabel(lastDuelResult,',
        '"IronYardDuelLastResult"',
        'remotes.SetDuelReady:FireServer',
        'duelToggle.Activated:Connect(function()',
        '"IronYardDuelScoreA"', '"IronYardDuelScoreB"',
        '"DUEL_BREAK"', '"IronYardDuelReadyCount"',
        '"DUEL_PREP"', 'updateIntro(phase, seconds, matchMode)',
        'local function updateDuelProgress(mode, phase, myWins, rivalWins)',
        'updateDuelProgress(matchMode, phase, myWins, rivalWins)',
        'duelProgress.Name = "DuelProgress"',
        'local myRoundBars, rivalRoundBars = {}, {}',
        'for i = 1, 5 do',
        'duelToggle.Visible = humans <= 2',
    ):
        has(match_hud, token, "Real opt-in duel HUD")
    has(client, 'if workspace:GetAttribute("IronYardMatchMode") == "DUEL" then',
        "Client spectator fire prediction suppression")
    require(server.index('if not duelCanFire(player) then return end')
        < server.index('if not canFire(player, weaponId, config) then'),
        "Duel spectator shot must not consume server ammo")

    has(network, 'ReloadWeapon = "RemoteEvent"', "Network ammo remote")
    for needle in (
        "local function randomSpread(direction, spreadDegrees)",
        "local function firePelletWeapon(player, weaponId, config, direction, coneDegrees)",
        "for _ = 1, config.pellets do",
        "state.magazines[weaponId] = loaded - 1",
        "state.reloadUntil[weaponId] = os.clock() + config.reloadSeconds",
        "state.reloadTokens[weaponId] ~= token",
        "player.Character ~= character",
        'remotes.ReloadWeapon.OnServerEvent:Connect(reloadWeapon)',
        "function WeaponService.resetRound()",
        "SpawnService.isProtected(entry.model)",
    ):
        has(server, needle, "Server authority")
    require(server.index("local function randomSpread") < server.index("local function fireRaycastWeapon"),
            "Local spread helper must precede raycast closure")
    for needle in ("hitPosition = raycastResult.Position",
                   "hitPosition = entry.hitPosition",
                   "pelletImpacts = pelletImpacts",
                   "#extraWorldImpacts < 3",
                   "if humanoid.Health < oldHealth then"):
        has(server, needle, "Server-confirmed hit and bounded shotgun pellet VFX")
    has(match, "WeaponService.resetRound()", "Per-round magazine reset")
    for token in ('nextGlobalFireAt = 0', 'if now < (state.nextGlobalFireAt or 0)',
                  'state.nextGlobalFireAt = WeaponConfig.nextGlobalFireAt(weaponId, now)'):
        has(server, token, "Server-only inter-weapon firing gate")
    for token in ('nextLocalGlobalFireAt = 0', 'or now < nextLocalGlobalFireAt',
                  'nextLocalGlobalFireAt = WeaponConfig.nextGlobalFireAt(weaponId, now)',
                  'now - (lastLocalFire.Knife or -math.huge)'):
        has(client, token, "Predicted cadence and quick-knife feedback")
    has(config, "function WeaponConfig.nextGlobalFireAt(weaponId, firedAt)",
        "One cadence model for all five weapons")

    for id in names:
        has(client, f'equipWeapon("{id}")', f"Weapon selector {id}")
        has(viewmodel, id, f"Viewmodel {id}")
    for name in ("_createAssaultRifle", "_createShotgun", "_createPistol", "_createSniper", "_createKnife"):
        has(viewmodel, name, "Original first-person weapon")
    for name in ("Enum.KeyCode.One", "Enum.KeyCode.Two", "Enum.KeyCode.Three",
                 "Enum.KeyCode.Four", "Enum.KeyCode.Five", "Enum.KeyCode.R"):
        has(client, name, "Desktop controls")
    for name in ('button("Reload", "RLD"', 'button("AssaultRifle"', 'button("Shotgun"'):
        has(client, name, "Android controls")
    for name in ("requestReload()", "remotes.ReloadWeapon:FireServer",
                 "message.kind == \"Ammo\"", "ammoByWeapon", "refreshTouchSelection"):
        has(client, name, "Client ammo/UI")
    for name in ("function HudController:setAmmo", "function HudController:_buildDamagePulse",
                 'elimination.Name = "EliminationConfirmation"',
                 "self.scopeOverlay.Visible = scoped and isOptical"):
        has(hud, name, "HUD accessibility")

    navigation = source("src/server/BotNavigation.luau")
    has(navigation, "if directRouteClear(bot, goal, params) then", "Capsule collision probe")
    has(navigation, 'requestMove(bot, bot.root.Position, now, bot.navMode ~= "WAIT")',
        "Bots must not walk into a confirmed obstructed direct route")
    require("bot.humanoid:MoveTo(goal)" in navigation,
            "Unobstructed bot routes must still move directly")
    has(navigation, "task.spawn(function()", "Asynchronous path computation")
    for key in (
        "local function releaseActivePath(bot)",
        "bot.pathBlockedConnection:Disconnect()",
        "computedPath.Blocked:Connect(function(blockedIndex)",
        "bot.activePath == computedPath",
        "Planner.blockedAhead(blockedIndex, bot.waypointIndex)",
        "abandonWaypoints(bot)",
        "Planner.targetChanged((goal - bot.pathGoal).Magnitude, GOAL_REPATH_DISTANCE)",
        "Planner.reusePath(bot.waypoints ~= nil,",
        "bot.pathAcceptedAt = os.clock()",
    ):
        has(navigation, key, "Active path obstruction handling")
    tactics = source("src/server/BotTactics.luau")
    for key in (
        "local function coverApproachClear(bot, destination, params)",
        "and coverApproachClear(bot, candidate, params) then",
        "BotCoverPlan.rejected(bot.failedCoverGoal",
        "if now < (bot.coverGoalUntil or 0) then",
        "BotCombatResponse.shouldTakeCover(healthRatio,",
    ):
        has(tactics, key, "Reachable defensive cover and bounded resampling")
    for needle in (
        "local function chooseDetour(bot, goal, params)",
        "local function walkableCandidate(bot, raw, params)",
        "Capsule clearance does not imply the FLOOR exists",
        "local GROUND_PROBE_DISTANCES = { 7, 14, 22, 30 }",
        "for _, lookahead in ipairs(GROUND_PROBE_DISTANCES) do",
        "local function capsuleRayBlocked(origin, offset, flat, params)",
        "capsuleRayBlocked(origin, LOW_CAPSULE_OFFSET, flat, params)",
        "capsuleRayBlocked(origin, HIGH_CAPSULE_OFFSET - side, flat, params)",
        "floor.Normal.Y < 0.68",
        "Planner.offsets(bot.strafeSign, attempt)",
        "directRouteClear(bot, grounded, params)",
        'setMode(bot, "AVOID")',
        'setMode(bot, "WAIT")',
        "PATH_COMPUTE_TIMEOUT = 5.0",
        "Planner.retryDelay(bot.pathFailures)",
        'bot.model:SetAttribute("IronYardNavMode", mode)',
    ):
        has(navigation, needle, "Ground-checked detours and bounded path retries")
    # Five capsule checks + four forward ground checks must remain.
    # Inline table literals in these loops previously allocated a new
    # sequence for every 0.2s decision; no checks have been dropped.
    require(navigation.count("capsuleRayBlocked(origin,") == 6,
            "All five route-capsule rays must remain (plus helper definition)")
    require("ipairs({ low, low + side, low - side, high + side, high - side })"
            not in navigation and "ipairs({ 7, 14, 22, 30 })" not in navigation,
            "No per-route capsule or floor distance table allocations")
    for needle in (
        "local COVER_PROBE_FRACTIONS = { 0.25, 0.5, 0.75 }",
        "for _, fraction in ipairs(COVER_PROBE_FRACTIONS) do",
        "for index = 1, 3 do",
        "index == 2 and side or -side",
        'BotPerfService.count("tacticsRay")',
    ):
        has(tactics, needle, "Keep three cover lanes and floor probes without new tables")
    require("ipairs({ Vector3.zero, side, -side })" not in tactics
            and "ipairs({ 0.25, 0.5, 0.75 })" not in tactics,
            "No per-candidate cover/ground-table allocations")
    for needle in (
        "local function rayParams(ignore)",
        "combatRaycastParams = rayParams(model)",
        "local params = bot.combatRaycastParams",
        "local shotParams = bot.combatRaycastParams",
        "BotPerfService.count(\"targetRay\")",
        "BotPerfService.count(\"shotRay\")",
    ):
        has(bot, needle, "Bot lifetime must share immutable LOS + shot raycast filter")
    require(bot.count("RaycastParams.new()") == 1
            and "local shotParams = rayParams(bot.model)" not in bot,
            "Bot shots and tactical decisions cannot allocate ray filters per tick")
    require(bot.index("local function rayParams(ignore)")
            < bot.index("local function getTargetModel(bot, limit)"),
            "Cached bot raycast creation must precede the targeting function")
    has(bot, "bot.pathFailures = 0", "Reset failure backoff on changed enemy")
    selection = source("src/shared/BotTargetSelection.luau")
    for needle in ("local distance = visible and entry.distance or entry.memoryDistance",
                   "if visible and entry.threatMatch == true then"):
        has(selection, needle, "No hidden live-distance scoring and visible-only retaliation")
    for needle in ("bot.targetSwitchedAt = now",
                   "bot.shotsSinceReposition += 1",
                   "BotTactics.requestBurstReposition(bot, now)",
                   "BotEngagementPlan.shouldReposition("):
        has(bot, needle, "Bounded combat lane switching after accepted shots")
    for needle in ("Selection.TARGET_COMMIT_SECONDS = 1.35",
                   "highest < previousScore + advantage",
                   "urgentVisibleAttacker = bestThreat and not previousThreat"):
        has(selection, needle, "Combat target lock with urgent visible-threat bypass")
    for needle in ("memoryDistance = (bot.lastKnownTargetPosition - bot.root.Position).Magnitude",
                   "now - (bot.lastConfirmedThreatAt or -math.huge) <= 2.8",
                   "threatMatch = recentThreat"):
        has(bot, needle, "Attacker response uses only server-confirmed visible evidence")
    for needle in ("BotMovementProgress.step(",
                   "bot.navSteeringGoal", "bot.stuckMonitorGoal",
                   'oldMode == "DIRECT" and bot.stuckRecoveries % 3 == 0'):
        has(bot, needle, "Actual waypoint progress and bounded stuck recovery")
    for needle in ("bot.navSteeringGoal = point.Position",
                   "bot.navSteeringGoal = detour",
                   "bot.navSteeringGoal = candidate",
                   "bot.navSteeringGoal = goal"):
        has(navigation, needle, "Active navigation goal feeds physics recovery")
    for needle in ("local function observeRecentHit(bot, now)",
                   "BotCombatResponse.reaction(localDirection.X, -localDirection.Z,",
                   "bot.recentThreatOrigin and now < (bot.suppressedUntil or 0)",
                   "observeRecentHit(bot, now)"):
        has(bot, needle, "Incoming fire triggers AI flinch and safe cover retreat")
    for needle in ("if targetHumanoid.Health < healthBefore then",
                   "if humanoid.Health < oldHealth then"):
        has(server, needle, "Human and AI hit origins derive from confirmed damage")
    has(client, "(cameraNow.CFrame.Position - message.origin).Magnitude < 195",
        "Distant bot tracers must not allocate unnecessary parts")
    has(bot, "config.MagazineSize", "Bot finite ammunition")
    has(bot, "config.ReloadSeconds", "Bot reloading")
    for key in ("CombatVfxProfile.tracer(range)",
                "function WeaponVisuals:_trackImpactMark(now, duration, cap)",
                "function WeaponVisuals:drawLocalMuzzleFlash()",
                "CombatVfxProfile.surface(materialName)",
                "CombatVfxProfile.budget(preset, touch, distance)",
                "self:_trackImpactMark(now, budget.markSeconds, budget.marks)",
                "ImpactMarkPool.claim(self.impactMarks, now, duration, cap)",
                "ImpactMarkPool.alpha(slot, now, i <= allowed)",
                "self:_updateImpactMarks(clock)",
                "for i = 1, budget.muzzleFins do",
                "if budget.muzzleLight then",
                "TransientFxPool.claim(self.transientParts,",
                "TransientFxPool.progress(slot, now, index <= cap)",
                "self:_updateTransientFx(clock)",
                "self:_spawnTransient({"):
        has(viewmodel, key, "Material-aware client-only combat effects")
    for needle in (
        "self.activeTransientIndices = {}",
        "if next(self.activeTransientIndices) then",
        "local slot, index = TransientFxPool.claim(self.transientParts,",
        "self.activeTransientIndices[index] = true",
        "for index in pairs(self.activeTransientIndices) do",
        "self.activeTransientIndices[index] = nil",
    ):
        has(viewmodel, needle, "Only active transient Parts may animate each frame")
    require("for index, slot in ipairs(self.transientParts)" not in viewmodel,
            "An inactive but allocated FX pool must not be scanned each frame")
    for needle in (
        'WaitForChild("ViewmodelRenderPolicy")',
        "self.lastViewmodelHidden = nil",
        "function WeaponVisuals:_syncScopeVisibility()",
        "ViewmodelRenderPolicy.needsUpdate(",
        "ViewmodelRenderPolicy.transparency(",
        "self:_syncScopeVisibility()",
        "local actionTravel = WeaponFeel.mechanism(self.currentWeaponId, shotAge)",
    ):
        has(viewmodel, needle, "Weapon opacity must change only on scope/equip")
    require("entry.part.Transparency = hideForScope and 1 or entry.baseTransparency"
            not in viewmodel, "No full viewmodel transparency writes every frame")
    for weapon in ("Pistol", "AssaultRifle", "Shotgun", "Sniper"):
        require(f'WeaponFeel.mechanism("{weapon}", shotAge)' not in viewmodel,
                "Do not evaluate inactive weapon mechanisms each frame")
    for needle in (
        "CombatVfxProfile.fragmentMotion(materialName)",
        "gravityDrop = motion.gravity * self.random:NextNumber(0.65, 1)",
        "spinAngle = motion.spin * self.random:NextNumber(-1, 1)",
        "slot.gravityDrop = spec.gravityDrop or 0",
        "slot.flicker = spec.flicker or 0",
        "if slot.gravityDrop > 0 then",
        "slot.flicker * (1 - baseAlpha)",
        'name = "IronYardEliminationRing"',
        "if settings.eliminationRing then",
    ):
        has(viewmodel, needle, "Material-specific pooled impact dynamics and fatal ring")
    # Confirmed local damage now shares the prioritized reusable FX pool.
    # No gunfire event should allocate temporary Parts, Tweens or Debris
    # timers; the only remaining Debris lifetime is spatial audio.
    require("TweenService:Create(" not in viewmodel
            and "TweenService = " not in viewmodel,
            "All combat glints must use pooled Quad.Out render updates")
    require(viewmodel.count("Debris:AddItem(") == 1
            and "Debris:AddItem(emitter, mix.lifetime)" in viewmodel,
            "Only spatial audio may schedule Debris cleanup")
    confirmed = viewmodel.split("function WeaponVisuals:drawConfirmedHit(", 1)[1].split(
        "function WeaponVisuals:drawPelletImpacts(", 1)[0]
    for needle in (
        "CombatVfxProfile.hitPriority(headshot == true, killed == true)",
        "CombatVfxProfile.shouldDisplayHit(now,",
        'name = "IronYardConfirmedHit"',
        'name = "IronYardHitSpark"',
        "shape = Enum.PartType.Ball",
        "priority = 4,",
        "priority = 3,",
        "duration = settings.duration",
        "self:_spawnTransient({",
    ):
        require(needle in confirmed, "Server-confirmed hit pool must preserve " + needle)
    require("Instance.new(" not in confirmed
            and "Debris:AddItem(" not in confirmed
            and "TweenService:Create(" not in confirmed,
            "Confirmed hits must not create or schedule transient Instances")
    has(viewmodel, "self:drawMuzzleFlash(entry.part.Position + direction * 0.25, nil, direction, true)",
        "Own muzzle flash must keep priority over remote debris")
    for key in ("CombatVfxProfile.hitPriority(headshot == true, killed == true)",
                "CombatVfxProfile.shouldDisplayHit(now,"):
        has(viewmodel, key, "Fatal confirmation overrides ordinary hit VFX cooldown")
    for key in ("function WeaponVisuals:drawConfirmedHit(",
                "function WeaponVisuals:drawPelletImpacts(",
                "CombatVfxProfile.hitFeedback(",
                "CombatVfxProfile.pelletVisualCount("):
        has(viewmodel, key, "Client-only confirmed damage and shotgun glints")
    for key in ("visuals:drawConfirmedHit(message.hitPosition, message.headshot, message.killed)",
                "visuals:drawPelletImpacts(message.pelletImpacts)",
                "local ownShot = message.shooterUserId == player.UserId",
                "if remoteAccepted then",
                '(ownShot or remoteAccepted) and typeof(message.pelletImpacts) == "table"'):
        has(client, key, "Server-authored hit UI, no local duplicate or skipped pellet feedback")
    for key in ("visuals:drawLocalMuzzleFlash()",
                "visuals:drawMuzzleFlash(message.origin, nil, direction.Unit)",
                "visuals:drawMuzzleFlash(message.origin, accent, message.direction.Unit)"):
        has(client, key, "Local and remote gun flashes use shot direction")
    has(client, "visibleRigParts", "Cached first-person rig visibility")
    for needle in (
        'WaitForChild("FirstPersonBodyCache")',
        "FirstPersonBodyCache.add(visibleRigParts, part, hide and 1 or 0)",
        "FirstPersonBodyCache.remove(visibleRigParts, item)",
        "FirstPersonBodyCache.clear(visibleRigParts)",
        "character.DescendantRemoving:Connect(untrackFirstPersonItem)",
        "for _, entry in ipairs(visibleRigParts.list) do",
        "if part:IsDescendantOf(character)",
    ):
        has(client, needle, "Streamed first-person body cache must release removed Parts")
    # Confirm a reload effect is driven by authoritative server ammo state,
    # and weapon bob uses character ground/velocity rather than a ticking clock.
    has(viewmodel, "function WeaponVisuals:setReloading(weaponId, active)", "Reload animation API")
    has(client, "visuals:setReloading(message.weaponId, message.reloading == true)",
        "Server-confirmed reload animation")
    has(client, "visuals:setReloading(weaponId, ammunition.reloading)",
        "Weapon switch restores reload state")
    for key in ("humanoid.FloorMaterial ~= Enum.Material.Air",
                "rootPart.AssemblyLinearVelocity", "self.stepPhase",
                'string.sub(partName, 1, 4) == "Left"', 'partName == "Magazine"',
                'partName == "Slide"', 'partName == "PumpAction"', 'partName == "Bolt"'):
        has(viewmodel, key, "Grounded movement and animated reload visual")
    finishes = source("src/shared/OperatorFinishes.luau")
    for needle in ('level = 1, name = "FIELD ISSUE"',
                   'level = 3, name = "DESERT PATROL"',
                   'level = 6, name = "COLD STEEL"',
                   'level = 10, name = "FOUNDRY"',
                   'level = 15, name = "BLACK GRADE"'):
        has(finishes, needle, "Earned career weapon finish")
    has(viewmodel, "function WeaponVisuals:_applyCareerFinish()", "Career cosmetics")
    has(viewmodel, "self:_applyCareerFinish()", "Career cosmetic activation")
    botTactics = source("src/server/BotTactics.luau")
    for needle in ("SEARCH_MEMORY_SECONDS = 9",
                   "BotTactics.investigateGoal(bot, bot.lastKnownTargetPosition",
                   "bot.lastKnownTargetPosition = nil"):
        has(bot, needle, "Last-sighting investigation")
    for needle in ("function BotTactics.investigateGoal(",
                   "groundedGoal(bot, lastSeen, params)", "elapsed >= 9"):
        has(botTactics, needle, "Grounded, finite-duration search")
    botAnimation = source("src/server/BotAnimation.luau")
    for key in ("bot.wasAirborne", "bot.landedAt", "bot.lastDamageAt",
                "bot.defensiveBlend", "strafeLean",
                "local hitRoll = (hit - rebound) * hitSide * 0.20",
                "local hitPitch = (hit - rebound) * hitFront * 0.14",
                "Motion.coverPose(bot.coverGoal ~= nil,",
                "Motion.hitImpulse(now - (bot.lastDamageAt or -100))",
                "Motion.weights(planar.X, planar.Z,",
                "Motion.smooth(bot.forwardBlend or 0, forward",
                "Motion.smooth(bot.lateralBlend or 0, lateral",
                "Motion.gaitPhase(", "local sideStep =", "local braking =",
                "Motion.turnSignal(previousFacing.X, previousFacing.Z,",
                "Motion.reversalSignal(previousVelocity.X, previousVelocity.Z,",
                "local pivot = (bot.turnBlend or 0)"):
        has(botAnimation, key, "Directional R6 bot combat poses")
    for key in ("bot.lastAnimationFacing = bot.root.CFrame.LookVector",
                "bot.lastAnimationVelocity = bot.root.AssemblyLinearVelocity",
                "bot.turnBlend = 0", "bot.reversalBlend = 0",
                "bot.coverApproachBlend = 0", "bot.coverBraceBlend = 0"):
        has(bot, key, "Respawn clears local turn and braking pose inertia")
    for key in ("BotMotionProfile.nextPoseAt(\n                        now, nearestSquared, bot.slot)",
                "BotAnimation.step(bot, now, bot.isAiming == true)",
                "task.wait(1 / 30)", "BotDeathAnimation.play(bot)"):
        has(bot, key, "Decoupled 15Hz pose clock and staged defeat")
    death = source("src/server/BotDeathAnimation.luau")
    death_plan = source("src/shared/BotDeathPlan.luau")
    death_fx = source("src/client/BotDeathFx.client.luau")
    for needle in ("function BotDeathAnimation.play(bot)", "bot.root.Anchored = true",
                   "identity.Enabled = false", "task.delay(elapsed, animateStage)"):
        has(death, needle, "Bounded non-physics bot defeat stages")
    for needle in ("function Plan.sequence(", "function Plan.duration(",
                   "function Plan.dustBudget("):
        has(death_plan, needle, "Pure deterministic fall pose and graphics budgets")
    dust_pool = source("src/shared/BotDeathDustPool.luau")
    for needle in (
        'humanoid.Died:Connect(function()',
        "floor.Normal.Y < 0.65",
        "puff.CanQuery = false",
        "puff.CanCollide = false",
        "puff.CanTouch = false",
        'shared:WaitForChild("BotDeathDustPool")',
        "DustPool.cap(",
        "DustPool.claim(dustSlots, now,",
        "DustPool.ease(slot, now, index <= cap)",
        "if not next(activeDustIndices) then return end",
        "nextAnimationAt = now + 1 / 30",
        "activeDustIndices[slotIndex] = true",
        "activeDustIndices[index] = nil",
        "if puff and puff.Parent then puff.Parent = nil end",
        "script.Destroying:Connect(function()",
    ):
        has(death_fx, needle, "Local-only, pooled and grounded defeat dust")
    require("TweenService" not in death_fx and "Debris" not in death_fx,
            "Bot death dust must not create per-kill Tween/Debris jobs")
    require(death_fx.count('Instance.new("Part")') == 1,
            "Dust geometry is allocated lazily only when a new pool slot is needed")
    death_lifecycle = source("src/shared/BotDeathFxLifecycle.luau")
    for needle in (
        "function Lifecycle.track(state, model, container)",
        "function Lifecycle.active(state, model, entry, container)",
        "function Lifecycle.retire(state, model)",
        "state.byModel[model] = nil",
        "entry.active = false",
    ):
        has(death_lifecycle, needle, "Streaming-safe bot death binding policy")
    for needle in (
        'shared:WaitForChild("BotDeathFxLifecycle")',
        "local lifecycle = Lifecycle.new()",
        "local pendingAttributes = {}",
        'model:GetAttributeChangedSignal("IsArenaBot"):Connect(function()',
        "folder.ChildAdded:Connect(bind)",
        "folder.ChildRemoved:Connect(retireBot)",
        "Lifecycle.retire(lifecycle, model)",
        "entry.connection:Disconnect()",
        "if not humanoid or humanoid.Parent ~= model",
        "Lifecycle.active(lifecycle, model, entry, folder)",
        "or entry.deathQueued then return end",
        "and humanoid.Parent == model and humanoid.Health <= 0 then",
        "for model in pairs(lifecycle.byModel) do retireBot(model) end",
        "if folderAddedConnection then folderAddedConnection:Disconnect() end",
    ):
        has(death_fx, needle, "Streaming/respawn cleanup for bot defeat visuals")
    require('local bound = setmetatable({}, { __mode = "k" })' not in death_fx,
            "Weak-key bound table cannot safely manage event connections")
    require(death_fx.count("task.delay(0.64, function()") == 1,
            "Confirmed death dust remains delayed exactly once per model")
    for needle in ("Pool.MAX_BOTS = 4", "Pool.MAX_PARTS = 16",
                   "function Pool.cap(", "function Pool.claim(",
                   "function Pool.ease(", "return 1 - (1 - t) * (1 - t)"):
        has(dust_pool, needle, "Bounded 4-bot recycled defeat-dust policy")
    require(bot.index("component.CanQuery = false") < bot.index("BotDeathAnimation.play(bot)"),
            "Dead bot hitboxes must be removed before posing its body")
    require("playDeathStagger(bot)" not in bot,
            "Retired single-pose death tween must no longer run")
    awards = source("src/server/CombatAwards.luau")
    awards_ui = source("src/client/CombatAwards.client.luau")
    score = source("src/server/ScoreService.luau")
    for needle in ("function CombatAwards.recordElimination", "function CombatAwards.recordDeath",
                   "function CombatAwards.resetRound", 'kind = "CombatAward"'):
        has(awards, needle, "Server-owned combat medal")
    require(server.count("CombatAwards.recordElimination(") == 2,
            "Both server-verified firearm elimination paths must award XP")
    has(score, "CombatAwards.recordDeath(player)", "Death resets kill streak")
    has(match, "CombatAwards.resetRound()", "Round transition resets combat streak")
    has(awards_ui, "remotes.WeaponFeedback.OnClientEvent:Connect(notify)",
        "Client-only medal presentation")

    roundResults = source("src/client/RoundResults.client.luau")
    for needle in ("IronYardWinnerUserId", 'winnerUserId = winningUserId or 0',
                   'finalResult.winnerUserId', 'IronYardFinalStandings',
                   'finalResult = currentStandings()',
                   'RoundStandings.build(entries, round)'):
        has(match, needle, "Frozen server-authored results and winner ID")
    for needle in ('NeonMatchPhase") ~= "RESULTS"',
                   'owner == player.UserId', 'IronYardStandings',
                   'IronYardFinalStandings', 'myStanding.rank',
                   'IronYardRoundXP', 'IronYardProgressLevel',
                   'leaderboard[i].Text'):
        has(roundResults, needle, "Server-authored end-round recap")

    touchLayout = source("src/shared/TouchLayout.luau")
    killFeed = source("src/client/KillFeed.client.luau")
    tacticalHud = source("src/client/TacticalHud.client.luau")
    progressionHud = source("src/client/ProgressionHud.client.luau")
    for needle in ("function Layout.compute(width, height, preset)", "function Layout.check(width, height, buttons)",
                   "Overlapping touch buttons", "Invalid/hidden touch button"):
        has(touchLayout, needle, "Android layout geometry and guards")
    for needle in ('touchGui.IgnoreGuiInset = false', "TouchLayout.compute(viewport.X, viewport.Y, preset)",
                   'touchRoot:GetPropertyChangedSignal("AbsoluteSize")',
                   'updateTouchVisibility = function()', 'touchGui.Enabled = enabled',
                   'heldFireInput = nil -- stops any running automatic-fire loop'):
        has(client, needle, "Responsive safe-area touch and results gating")
    for needle in ('local MAX_ENTRIES = touch and 2 or 4', 'frame.Visible = viewport.X >= 360',
                   'IronYardBriefingOpen'):
        has(killFeed, needle, "Mobile kill-feed space management")
    has(tacticalHud, "board.Visible = false", "Hide duplicate top-3 HUD on small touch screens")
    has(progressionHud, "local compact = UserInputService.TouchEnabled", "Compact mobile rank display")
    has(progressionHud, "panel.Size = UDim2.fromOffset(205, compact and 27 or 96)",
        "Player rank must not obstruct the virtual joystick")

    print("IRON YARD weapon, ammo, ADS and control source contracts: OK")
    print("NOTE: Studio/Android playtests are still required.")


if __name__ == "__main__":
    main()
