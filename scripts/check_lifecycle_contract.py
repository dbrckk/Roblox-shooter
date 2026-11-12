#!/usr/bin/env python3
"""Static wiring checks for the LOT C1 lifecycle audit.

The executable suite owns the counts. This contract guarantees the audit stays
pure and deterministic, that it never claims a frame rate, that the private
profiler remains opt-in, and that CI runs both files.
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
    ledger = source("src/shared/LifecycleLedger.luau")
    suite = source("scripts/test_lifecycle_stress.luau")
    workflow = source(".github/workflows/rojo-build.yml")
    profiler = source("src/client/PerfOverlay.client.luau")

    # 1. The ledger is an audit tool, not an engine wrapper.
    for forbidden in ("game:GetService", "require(", "workspace.", ":WaitForChild",
                      "Instance.new", "math.random"):
        require(forbidden not in ledger,
                f"LifecycleLedger must stay pure: found `{forbidden}`")
    for signature in (
        "function LifecycleLedger.new(",
        "function LifecycleLedger.acquire(",
        "function LifecycleLedger.release(",
        "function LifecycleLedger.releaseKind(",
        "function LifecycleLedger.leaks(",
        "function LifecycleLedger.report(",
    ):
        has(ledger, signature, "LifecycleLedger public API")
    # Bounded memory: the audit must not become the leak it looks for.
    has(ledger, "LifecycleLedger.MAX_PER_KIND", "per-kind bound")
    has(ledger, "state.overflow = state.overflow + 1", "overflow must be counted")
    has(ledger, "state.duplicates = state.duplicates + 1",
        "double registration must be counted")

    # 2. The stress suite must exercise the documented scenario, not a token one.
    for module in ("LifecycleLedger", "BotPathBudget", "TransientFxPool",
                   "ImpactMarkPool", "MatchLobbyPolicy"):
        has(suite, f'require("../src/shared/{module}")', "stress suite coverage")
    for constant in ("local ROUNDS = 20", "local BOTS = 4", "local HUMANS = 2",
                     'local PRESETS = { "ECO", "BALANCED", "QUALITY" }'):
        has(suite, constant, "stress suite scenario")
    has(suite, "LifecycleLedger.report(ledger).duplicates == 0",
        "twenty rounds must prove no double registration")

    # 3. No frame-rate claim: the suite measures counts, never time.
    for forbidden in ("FrameWindow", "Stats", "os.clock", "fps", "FPS",
                      "GetFPS", "Heartbeat", "RenderStepped"):
        require(forbidden not in suite,
                f"the stress suite must not measure frames: found `{forbidden}`")
    require("never" in suite.lower() or "jamais" in suite.lower(),
            "the suite must say out loud that it measures no frame rate")

    # 4. The private profiler stays opt-in: Studio or the place owner only.
    has(profiler, "RunService:IsStudio()", "profiler must stay Studio-gated")
    has(profiler, "player.UserId == game.CreatorId",
        "profiler must stay owner-gated")
    has(profiler, 'panel.Visible = false', "the profiler panel starts hidden")
    require("panel.Visible = true" not in profiler,
            "the profiler panel must never be shown unconditionally")
    require("for player in" not in profiler and "GetPlayers()" not in profiler,
            "the profiler must never be enabled for every player")

    # 5. The ledger must serve in game, not only in the suite.
    service = source("src/server/LifecycleService.luau")
    match = source("src/server/MatchService.luau")
    weapon = source("src/server/WeaponService.luau")
    bootstrap = source("src/server/init.server.luau")
    for required in (
        'require(Shared:WaitForChild("LifecycleLedger"))',
        "Players.PlayerAdded:Connect(onPlayerAdded)",
        "Players.PlayerRemoving:Connect(onPlayerRemoving)",
        'player:GetAttributeChangedSignal("IronYardEquippedWeapon")',
        'Workspace:GetAttributeChangedSignal("IronYardRoundPhase")',
        'Workspace:SetAttribute("IronYardAuditLive"',
        'Workspace:SetAttribute("IronYardAuditLeaks"',
        'Workspace:SetAttribute("IronYardAuditDuplicates"',
        "pcall(LifecycleLedger.acquire",
        "pcall(LifecycleLedger.report",
    ):
        has(service, required, "LifecycleService wiring")
    service_code = re.sub(r"--[^\n]*", "", service)
    for forbidden in ("Kick(", "FireClient", "FireServer", "RemoteEvent",
                      "RemoteFunction", ":LoadCharacter", "CharacterAdded",
                      "TeleportAsync"):
        require(forbidden not in service_code,
                f"LifecycleService must not {forbidden}")
    # The audit reads two mirrors and must not become a gameplay input.
    has(match, 'Workspace:SetAttribute("IronYardRoundPhase", nextPhase)',
        "MatchService must mirror the phase for the audit")
    has(weapon, 'player:SetAttribute("IronYardEquippedWeapon", weaponId)',
        "WeaponService must mirror the equipped weapon for the audit")
    require("IronYardRoundPhase" not in match.replace(
                'Workspace:SetAttribute("IronYardRoundPhase", nextPhase)', ""),
            "MatchService must not read the audit mirror back")
    require("IronYardEquippedWeapon" not in weapon.replace(
                'player:SetAttribute("IronYardEquippedWeapon", weaponId)', ""),
            "WeaponService must not read the audit mirror back")
    # The mirror write is deduplicated from server state, never by reading the
    # attribute back: a repeated equip request must not replicate again.
    has(weapon, "state.mirroredWeaponId ~= weaponId",
        "the equip mirror must be deduplicated")
    has(weapon, "state.mirroredWeaponId = weaponId",
        "the dedupe must remember the last mirrored weapon")
    require(weapon.count('player:SetAttribute("IronYardEquippedWeapon"') == 1,
            "the equip mirror must have exactly one write site")
    start_at = bootstrap.find("LifecycleService.start()")
    match_at = bootstrap.find("MatchService.start()")
    require(start_at != -1, "init.server.luau must start LifecycleService")
    require(match_at != -1, "MatchService.start must stay in place")
    require(start_at < match_at,
            "LifecycleService must start before the round it observes")

    # 6. CI must run the suite and this contract.
    has(workflow, "./luau scripts/test_lifecycle_stress.luau",
        "rojo-build.yml lifecycle suite step")
    has(workflow, "python3 scripts/check_lifecycle_contract.py",
        "rojo-build.yml lifecycle contract step")

    # 7. The audit document must state what it proves and what it does not.
    doc = source("docs/LIFECYCLE_AUDIT.md")
    for heading in ("## 1. Périmètre audité", "## 2. Registre de cycle de vie",
                    "## 3. Scénario de stress", "## 4. Budget d'IA à quatre bots",
                    "## 5. Profiler privé", "## 6. Limites"):
        has(doc, heading, "docs/LIFECYCLE_AUDIT.md section")
    has(doc, "20 manches", "the stress scenario must be written down")

    print("IRON YARD lifecycle contract (pure ledger, bounded audit, 20 rounds, "
          "opt-in profiler, CI wiring): OK")


if __name__ == "__main__":
    main()
