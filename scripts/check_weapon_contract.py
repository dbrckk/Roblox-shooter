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
    has(match, "WeaponService.resetRound()", "Per-round magazine reset")

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
                 "self.scopeOverlay.Visible = scoped and isOptical"):
        has(hud, name, "HUD accessibility")

    has(bot, "config.MagazineSize", "Bot finite ammunition")
    has(bot, "config.ReloadSeconds", "Bot reloading")
    has(client, "visibleRigParts", "Cached first-person rig visibility")
    print("IRON YARD weapon, ammo, ADS and control source contracts: OK")
    print("NOTE: Studio/Android playtests are still required.")


if __name__ == "__main__":
    main()
