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
    client = source("src/client/init.client.luau")
    viewmodel = source("src/client/WeaponVisuals.luau")
    hud = source("src/client/HudController.luau")
    match = source("src/server/MatchService.luau")
    bot = source("src/server/BotService.luau")

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

    has(network, 'ReloadWeapon = "RemoteEvent"', "Network ammo remote")
    for needle in (
        "local function randomSpread(direction, spreadDegrees)",
        "local function firePelletWeapon(player, weaponId, config, direction)",
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
        "for _, lookahead in ipairs({ 7, 14, 22, 30 }) do",
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
    require(viewmodel.count("TweenService:Create(") == 2,
            "Only confirmed hit glints may still use TweenService; transient Parts are pooled")
    require("Debris:AddItem(tracer," not in viewmodel
            and "Debris:AddItem(chip," not in viewmodel
            and "Debris:AddItem(core," not in viewmodel
            and "Debris:AddItem(fin," not in viewmodel
            and "Debris:AddItem(dot," not in viewmodel,
            "Transient FX must not schedule per-shot debris cleanup")
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
    for key in ("BotMotionProfile.interval(distance)",
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
    for needle in ('humanoid.Died:Connect(function()', "floor.Normal.Y < 0.65",
                   "puff.CanQuery = false", "Debris:AddItem(puff,"):
        has(death_fx, needle, "Local-only, grounded and bounded defeat dust")
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
