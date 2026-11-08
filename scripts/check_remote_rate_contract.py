#!/usr/bin/env python3
"""Verify server-owned per-user quotas on all client->server gameplay remotes.

Pure Luau regressions test token-bucket behavior. These checks ensure that
real production handlers check admission BEFORE expensive state/physics work.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
policy = read("src/shared/RemoteRatePolicy.luau")
guard = read("src/server/RemoteGuard.luau")
weapon = read("src/server/WeaponService.luau")
movement = read("src/server/MovementService.luau")
diagnostics = read("src/server/BotPerfService.luau")
net = read("src/shared/PrecisionNet.luau")

for key in (
    "EquipWeapon", "FireWeapon", "ReloadWeapon", "SetSprinting",
    "MovementAction", "MovementUpdate", "MovementStop", "Diagnostics",
):
    assert key in policy, f"Missing bounded category: {key}"
for needle in (
    "function Policy.allow(bucket, channel, now)",
    "function Policy.channelForAction(action)",
    'if action == "BoostStop" or action == "StopWallRun" then',
    'if action == "BoostUpdate" or action == "WallRunUpdate" then',
    "state.tokens = math.min(profile.burst, state.tokens + delta * profile.rate)",
    "if state.tokens < 1 then return false end",
):
    assert needle in policy, f"Token bucket or movement priority missing: {needle}"
for needle in (
    "local buckets = setmetatable({}, { __mode = \"k\" })",
    "if not player or player.Parent ~= Players then return false end",
    "return Policy.allow(state, channel, os.clock())",
    'if special == "MovementStop" then',
    'if not Guard.allow(player, "MovementAction") then return false end',
    'if special == "MovementUpdate" then',
    "Players.PlayerRemoving:Connect(",
    "buckets[player] = nil",
):
    assert needle in guard, f"Server-only user limiter contract missing: {needle}"

def in_handler(body, signature, end_signature, ordered):
    assert body.count(signature) == 1, signature
    scope = body.split(signature, 1)[1].split(end_signature, 1)[0]
    indexes = [scope.index(fragment) for fragment in ordered]
    assert indexes == sorted(indexes), f"Admission must occur before handler mutations: {signature}"

in_handler(weapon, "local function reloadWeapon(player, weaponId)",
           "\nlocal function canFire(", (
               'RemoteGuard.allow(player, "ReloadWeapon")',
               'typeof(weaponId) ~= "string"',
               'getState(player)',
           ))
in_handler(weapon, "local function onEquipWeapon(player, weaponId)",
           "\nlocal function onFireWeapon(", (
               'RemoteGuard.allow(player, "EquipWeapon")',
               "WeaponConfig.isValid(weaponId)",
               "getState(player)",
           ))
in_handler(weapon, "local function onFireWeapon(player, payload)",
           "\nfunction WeaponService.resetRound(", (
               'RemoteGuard.allow(player, "FireWeapon")',
               'workspace:GetAttribute("NeonMatchPhase") ~= "LIVE"',
               'getAimDirection(payload)',
               'getLiveCharacter(player)',
               "canFire(player, weaponId, config)",
           ))
in_handler(movement, "local function onSprintingChanged(player, isSprinting)",
           "\nlocal function onMovementAction(", (
               'RemoteGuard.allow(player, "SetSprinting")',
               'typeof(isSprinting) ~= "boolean"',
               'getCharacterParts(player)',
               'state.sprinting == isSprinting',
               'sendMovementState(player, state)',
           ))
in_handler(movement, "local function onMovementAction(player, payload)",
           "\nfunction MovementService.start()", (
               "local action = typeof(payload)",
               "RemoteGuard.movement(player, action)",
               "#action > 24",
               'if action == "Slide" then',
           ))
assert 'RemoteGuard.allow(player, "Diagnostics")' in diagnostics
assert "if not authorized(player)" in diagnostics
for key in ("EquipWeapon", "ReloadWeapon", "FireWeapon", "SetSprinting",
            "MovementAction", "PerformanceDiagnostics"):
    assert key + ' = "RemoteEvent"' in net, f"Unbound server remote: {key}"
assert "remotes.EquipWeapon.OnServerEvent:Connect(onEquipWeapon)" in weapon
assert "remotes.ReloadWeapon.OnServerEvent:Connect(reloadWeapon)" in weapon
assert "remotes.FireWeapon.OnServerEvent:Connect(onFireWeapon)" in weapon
assert "remotes.SetSprinting.OnServerEvent:Connect(onSprintingChanged)" in movement
assert "remotes.MovementAction.OnServerEvent:Connect(onMovementAction)" in movement
print("IRON YARD server remote admission / sprint idempotence / stop priority: OK")
