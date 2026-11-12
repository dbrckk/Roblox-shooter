#!/usr/bin/env python3
"""Static wiring checks for the LOT C2 first-minute UX contract.

The Luau suite owns the journey, the surface matrix and the geometry. This
contract guarantees that the plan still describes the clients that actually
ship: if a panel changes its visibility rule, the copy stops matching the
server, or the private profiler loses a gate, CI fails here.
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
    plan = source("src/shared/HudSurfacePlan.luau")
    suite = source("scripts/test_first_minute.luau")
    workflow = source(".github/workflows/rojo-build.yml")
    briefing = source("src/client/Briefing.client.luau")
    results = source("src/client/RoundResults.client.luau")
    defeat_screen = source("src/client/DefeatScreen.client.luau")
    progression = source("src/client/ProgressionHud.client.luau")
    tactical = source("src/client/TacticalHud.client.luau")
    kill_feed = source("src/client/KillFeed.client.luau")
    profiler = source("src/client/PerfOverlay.client.luau")
    guide = source("src/shared/FirstMatchGuide.luau")
    defeat_policy = source("src/shared/DefeatPresentation.luau")
    career = source("src/shared/CareerReadout.luau")
    layout = source("src/shared/TouchLayout.luau")
    controller = source("src/client/HudController.luau")
    match = source("src/server/MatchService.luau")
    spawn = source("src/server/SpawnService.luau")
    bot = source("src/server/BotService.luau")
    match_hud = source("src/client/MatchHud.client.luau")

    # 1. The plan is a pure contract, not an engine wrapper.
    for forbidden in ("game:GetService", "require(", "workspace.", ":WaitForChild",
                      "Instance.new", "os.clock", "RunService", "math.random"):
        require(forbidden not in plan,
                f"HudSurfacePlan must stay pure: found `{forbidden}`")
    for signature in (
        "function Plan.briefingVisible(",
        "function Plan.tacticalVisible(",
        "function Plan.killFeedVisible(",
        "function Plan.defeatVisible(",
        "function Plan.resultsVisible(",
        "function Plan.progressionVisible(",
        "function Plan.privatePerfVisible(",
        "function Plan.expected(",
        "function Plan.audit(",
        "function Plan.reached(",
        "function Plan.missing(",
    ):
        has(plan, signature, "HudSurfacePlan public API")
    has(plan, "Plan.STEPS = {", "the first-minute steps must be declared")
    has(plan, "Plan.SURFACES = {", "the audited surfaces must be declared")

    # 2. The plan must describe the clients that actually ship.
    has(briefing, "Guide.objective(", "briefing must keep using the shared objective")
    has(briefing, "panel.Visible = false", "the briefing card starts hidden")
    has(results, 'if Workspace:GetAttribute("NeonMatchPhase") ~= "RESULTS" then',
        "the round result owns the RESULTS phase")
    has(results, "root.Visible = true", "the round result still shows itself")
    has(defeat_screen, "local show = dead and activeCharacter == player.Character",
        "the defeat card is bound to the current character's death")
    has(defeat_screen, '(phase == "LIVE" or (mode == "DUEL" and phase == "DUEL_BREAK"))',
        "the defeat card is bound to LIVE or a duel break")
    has(progression, 'panel.Visible = phase ~= "RESULTS"',
        "the career panel steps aside for the round result")
    has(progression, 'playerGui:GetAttribute("IronYardBriefingOpen") ~= true',
        "the career panel steps aside for the briefing")
    has(tactical, 'local visible = Workspace:GetAttribute("NeonMatchPhase") ~= "WAITING"',
        "the tactical board stays hidden in the lobby")
    has(kill_feed, 'Workspace:GetAttribute("NeonMatchPhase") == "LIVE"',
        "the kill feed belongs to LIVE")
    for gate in ("RunService:IsStudio()", "player.UserId == game.CreatorId",
                 "IronYardPrivatePerfActive"):
        has(profiler, gate, "the private profiler keeps its gates")

    # 3. Copy that must agree with the server, not with an older build.
    require(re.search(r"ELIMINATIONS_TO_WIN = 15", match) is not None,
            "MatchService must keep the 15-elimination FFA objective")
    has(guide, "math.floor(limit) or 15", "the guide fallback must match 15 eliminations")
    require(re.search(r"SPAWN_SHIELD_SECONDS = 2\.5", spawn) is not None,
            "SpawnService must keep the 2.5 s spawn shield")
    has(defeat_policy, 'SPAWN SHIELD 2.5s', "the defeat copy must state the real shield")

    # 4. Honest bots: a bot is never counted as a connected human.
    has(bot, 'model:SetAttribute("IsArenaBot", true)', "bots must be marked as arena bots")
    has(match_hud, 'Workspace:GetAttribute("NeonBotCount")',
        "the match HUD must show the bot count it is given")
    require("IsArenaBot" not in match_hud,
            "the match HUD must not relabel bots as human players")

    # 5. The career panel never invents a confirmed save.
    for status in ('status == "ONLINE"', 'status == "STUDIO"', 'status == "LOCKED"'):
        has(career, status, "CareerReadout must keep its explicit statuses")
    require('"CAREER / SAVED"' in career,
            "an acknowledged save must stay the only SAVED label")

    # 6. Touch geometry: the reserve, the minimum target and the settings access.
    has(layout, "r.w < 28 or r.h < 28", "touch targets must stay at least 28 pixels")
    has(layout, "r.y < 78", "controls must stay below the top HUD band")
    has(layout, "if intersects(r, settings) then",
        "touch controls must never cover the settings access")
    has(controller, "TouchLayout.SETTINGS_BUTTON",
        "the live HUD must place its settings button from the shared geometry")
    has(suite, "Layout.compute(screen.w, screen.h, preset)",
        "the suite must measure the shipped geometry")

    # 7. The suite must exercise the documented journey and the small screens.
    for module in ("HudSurfacePlan", "FirstMatchGuide", "CareerReadout",
                   "DefeatPresentation", "TouchLayout"):
        has(suite, f'require("../src/shared/{module}")', "first-minute coverage")
    for screen in ('16:9 small', '16:9 notch', '20:9', '20:9 notch'):
        has(suite, screen, "the suite must cover small and tall phone screens")
    for step in ("JOIN", "OBJECTIVE", "AIM", "FIRE", "RELOAD", "DEATH",
                 "RESPAWN", "RESULT", "PROGRESSION"):
        has(plan, step, "the plan must declare the documented step")
    has(suite, "Plan.STEPS", "the suite must walk the declared steps")
    require("FrameWindow" not in suite and "GetFPS" not in suite
            and "Heartbeat" not in suite,
            "the first-minute suite must not measure frames")

    # 8. CI must run the suite and this contract.
    has(workflow, "./luau scripts/test_first_minute.luau",
        "rojo-build.yml first-minute suite step")
    has(workflow, "python3 scripts/check_first_minute_contract.py",
        "rojo-build.yml first-minute contract step")

    # 9. The document must state what it proves and what it does not.
    doc = source("docs/FIRST_MINUTE_UX.md")
    for heading in ("## 1. Parcours verrouillé", "## 2. Surfaces HUD",
                    "## 3. Contrôles tactiles", "## 4. Bots et humains",
                    "## 5. Limites"):
        has(doc, heading, "docs/FIRST_MINUTE_UX.md section")
    has(doc, "aucune preuve visuelle", "the document must refuse a visual claim")

    print("IRON YARD first-minute contract (pure plan, live clients, 15 layouts, "
          "honest bots, honest saves, CI wiring): OK")


if __name__ == "__main__":
    main()
