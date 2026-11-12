#!/usr/bin/env python3
"""Source-to-matrix contract for the IRON YARD FFA/duel round transitions (A1).

The executable Luau suite proves decision outcomes. This contract proves the
documented matrix still matches the transitions MatchService really emits,
branch by branch: every documented edge must own a real source branch, and no
source branch may emit an undocumented phase. It never simulates Roblox
replication, physics or latency, and it never asserts a balance target.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PHASES = ["WAITING", "COUNTDOWN", "LIVE", "DUEL_PREP", "DUEL_BREAK", "RESULTS"]
PHASE_SET = set(PHASES)

# Universal empty-roster reset: MatchLobbyPolicy may publish WAITING from any
# phase, so it is a target in every function that owns an exit path.
UNIVERSAL_TARGET = "WAITING"

# One entry per documented edge. `func` must contain `needle`; `also` adds the
# contextual branch (caller guard or delegate) that makes the edge reachable.
# `delegates` means the target transition is emitted by a helper, not here.
BRANCHES = [
    dict(frm="WAITING", to="COUNTDOWN", func="tick",
         needle='if phase == "WAITING" then\n        transition("COUNTDOWN"'),
    dict(frm="COUNTDOWN", to="LIVE", func="startRound",
         needle='transition("LIVE", ROUND_SECONDS)'),
    dict(frm="COUNTDOWN", to="DUEL_PREP", func="startDuelBout",
         needle='transition("DUEL_PREP", DuelRules.PREP_SECONDS)',
         also=[("startRound", "startDuelSeries(candidates)")]),
    dict(frm="COUNTDOWN", to="DUEL_BREAK", func="startDuelSeries",
         needle='if not startDuelBout() then transition("DUEL_BREAK", 2)'),
    dict(frm="LIVE", to="RESULTS", func="endRound",
         needle='transition("RESULTS", RESULTS_SECONDS,',
         also=[("tick", 'if topScore >= ELIMINATIONS_TO_WIN or remaining <= 0 then')]),
    dict(frm="LIVE", to="DUEL_PREP", func="tick", delegates=True,
         needle='if not duel and mode == "FFA" then',
         also=[("startDuelBout", 'transition("DUEL_PREP", DuelRules.PREP_SECONDS)')]),
    dict(frm="LIVE", to="DUEL_BREAK", func="finishDuelBout",
         needle='transition("DUEL_BREAK", DUEL_BREAK_SECONDS)'),
    dict(frm="DUEL_PREP", to="LIVE", func="startLiveDuelBout",
         needle='transition("LIVE", DUEL_BOUT_SECONDS)'),
    dict(frm="DUEL_PREP", to="DUEL_BREAK", func="retryInterruptedDuelPrep",
         needle='transition("DUEL_BREAK", DUEL_BREAK_SECONDS)'),
    dict(frm="DUEL_PREP", to="RESULTS", func="endDuel",
         needle='transition("RESULTS", RESULTS_SECONDS,',
         also=[("tick", 'if duel and phase ~= "RESULTS" and not duelPlayersIntact() then')]),
    dict(frm="DUEL_BREAK", to="DUEL_PREP", func="tick", delegates=True,
         needle='elseif not startDuelBout() then',
         also=[("startDuelBout", 'transition("DUEL_PREP", DuelRules.PREP_SECONDS)')]),
    dict(frm="DUEL_BREAK", to="DUEL_BREAK", func="tick",
         needle='transition("DUEL_BREAK", 1)'),
    dict(frm="DUEL_BREAK", to="RESULTS", func="tick", delegates=True,
         needle='endDuel("SPAWN_TIMEOUT", nil)',
         also=[("endDuel", 'transition("RESULTS", RESULTS_SECONDS,')]),
    dict(frm="RESULTS", to="COUNTDOWN", func="tick",
         needle='elseif phase == "RESULTS" and remaining <= 0 then'),
]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition, description):
    if not condition:
        raise AssertionError(description)


def functions(src):
    """Split MatchService into named function bodies (best effort, no parser)."""
    marks = [(m.start(), m.group(1)) for m in re.finditer(
        r"(?:^local function |^function MatchService\.)(\w+)", src, re.M)]
    out = {}
    for index, (start, name) in enumerate(marks):
        end = marks[index + 1][0] if index + 1 < len(marks) else len(src)
        out[name] = src[start:end]
    return out


def documented_pairs(tests):
    pairs = set()
    for frm, to, mode in re.findall(
            r'\{ from = "([A-Z_]+)", to = "([A-Z_]+)", mode = "([A-Z]+)" \}',
            tests):
        require(frm in PHASE_SET and to in PHASE_SET,
                f"Declared edge uses an undeclared phase: {frm} -> {to}")
        require(mode in ("FFA", "DUEL"), f"Declared edge has an unknown mode: {mode}")
        pairs.add((frm, to))
    return pairs


def matrix_cells(doc):
    """Parse the documented transition table into (from, to) -> cell text."""
    section = doc.split("## 3. Matrice des transitions légales", 1)[1].split("## 4.", 1)[0]
    cells = {}
    for line in section.splitlines():
        if not line.startswith("| `"):
            continue
        columns = [part.strip() for part in line.strip("|").split("|")]
        frm = columns[0].strip("`")
        if frm not in PHASE_SET:
            continue
        for index, target in enumerate(PHASES):
            cells[(frm, target)] = columns[1 + index]
    return cells


def main():
    server = source("src/server/MatchService.luau")
    doc = source("docs/MATCH_TRANSITIONS.md")
    tests = source("scripts/test_match_transitions.luau")
    workflow = source(".github/workflows/rojo-build.yml")
    bodies = functions(server)

    # 1. Every phase the server publishes is a declared phase of the matrix.
    emitted = set(re.findall(r'transition\("([A-Z_]+)"', server))
    require(emitted == PHASE_SET,
            f"MatchService phases {sorted(emitted)} differ from the matrix {sorted(PHASE_SET)}")

    # 2. No other module may rely on an undeclared phase string.
    for path in (ROOT / "src").rglob("*.luau"):
        text = path.read_text(encoding="utf-8")
        for line in text.splitlines():
            if "NeonMatchPhase" not in line:
                continue
            for literal in re.findall(r'"([A-Z_]+)"', line):
                require(literal in PHASE_SET,
                        f"{path.relative_to(ROOT)} reads undeclared phase `{literal}`")

    # 3. Phase durations stay the ones documented in the matrix.
    durations = {
        "COUNTDOWN_SECONDS": 6,
        "ROUND_SECONDS": 240,
        "RESULTS_SECONDS": 12,
        "DUEL_BOUT_SECONDS": 80,
        "DUEL_BREAK_SECONDS": 7,
    }
    for name, value in durations.items():
        match = re.search(rf"local {name} = (\d+)", server)
        require(match is not None, f"Missing phase duration `{name}`")
        require(int(match.group(1)) == value,
                f"`{name}` changed to {match.group(1)}: update docs/MATCH_TRANSITIONS.md")

    # 4. Branch-by-branch verification of every documented edge.
    require(len(BRANCHES) == 14, "The edge inventory must list every documented pair")
    for branch in BRANCHES:
        name = branch["func"]
        require(name in bodies, f"MatchService no longer defines `{name}`")
        require(branch["needle"] in bodies[name],
                f"Edge {branch['frm']} -> {branch['to']} lost its branch in {name}")
        if not branch.get("delegates"):
            require(f'transition("{branch["to"]}"' in bodies[name],
                    f"Edge {branch['frm']} -> {branch['to']} no longer emits {branch['to']} in {name}")
        for context_name, context_needle in branch.get("also", ()):
            require(context_name in bodies,
                    f"Edge {branch['frm']} -> {branch['to']} references missing `{context_name}`")
            require(context_needle in bodies[context_name],
                    f"Edge {branch['frm']} -> {branch['to']} lost its context in {context_name}")

    # 5. The declared matrix, the documented table and the source must agree.
    declared = documented_pairs(tests)
    branch_pairs = {(branch["frm"], branch["to"]) for branch in BRANCHES}
    require(declared == branch_pairs,
            "Declared edges differ from the source branch inventory: "
            f"tests-only={sorted(declared - branch_pairs)}, "
            f"source-only={sorted(branch_pairs - declared)}")

    cells = matrix_cells(doc)
    require(len(cells) == 36, f"Documented matrix is incomplete: {len(cells)} cells")
    for frm, to in sorted(declared):
        require("oui" in cells[(frm, to)].lower(),
                f"docs/MATCH_TRANSITIONS.md marks {frm} -> {to} as illegal")
    for frm in PHASES:
        for to in PHASES:
            if to == UNIVERSAL_TARGET or (frm, to) in declared:
                continue
            require("oui" not in cells[(frm, to)].lower(),
                    f"docs/MATCH_TRANSITIONS.md documents an undeclared edge {frm} -> {to}")

    # 6. No function may emit a target its documented branches do not own.
    for name, body in bodies.items():
        owned = {branch["to"] for branch in BRANCHES if branch["func"] == name}
        owned.add(UNIVERSAL_TARGET)
        for target in set(re.findall(r'transition\("([A-Z_]+)"', body)):
            require(target in PHASE_SET,
                    f"{name} emits undeclared phase {target}")
            require(target in owned,
                    f"{name} emits {target} without a documented branch")

    # 7. The decision rules the matrix documents must still be wired.
    for needle, label in (
        ("MatchLobbyPolicy.shouldReset", "empty-roster reset"),
        ("DuelRules.forfeitSide", "forfeit winner"),
        ("DuelRules.recoveryExpired", "bounded spawn recovery"),
        ("DuelRules.sameParticipants", "participant identity"),
        ("DuelRules.prepState", "preparation identity"),
        ("DuelRules.advance", "series adjudication"),
        ("ELIMINATIONS_TO_WIN", "FFA score limit"),
        ("CombatAwards.recordVictory", "victory credit"),
    ):
        require(needle in server or needle in source("src/server/WeaponService.luau"),
                f"Matrix rule lost its wiring: {label} ({needle})")

    require('#Players:GetPlayers() == 0' in bodies["startRound"],
            "startRound must not publish WAITING without an empty roster")
    require('if phase == "WAITING" then\n        transition("COUNTDOWN"' in server,
            "WAITING must go through COUNTDOWN")
    require('transition("WAITING", 0)' in server,
            "The empty-roster reset must publish WAITING")
    require('elseif phase == "RESULTS" and remaining <= 0 then' in server,
            "RESULTS must be the only path back to COUNTDOWN")

    # 8. Documented coverage: every matrix case exists in code and in tests.
    for index in range(1, 12):
        case = f"T{index}"
        require(case in doc, f"docs/MATCH_TRANSITIONS.md is missing {case}")
        require(case in tests, f"scripts/test_match_transitions.luau is missing {case}")
    for phase in PHASES:
        require(phase in doc, f"docs/MATCH_TRANSITIONS.md is missing phase {phase}")
    require("défaut de transition démontré" in doc,
            "The matrix must state the audit outcome honestly")

    # 9. CI must run both artefacts.
    require("./luau scripts/test_match_transitions.luau" in workflow,
            "rojo-build.yml does not run the transition suite")
    require("python3 scripts/check_match_transition_contract.py" in workflow,
            "rojo-build.yml does not run the transition contract")

    print("IRON YARD FFA/duel transition contract (phases, durations, 14 edge branches, "
          "doc matrix, CI wiring): OK")


if __name__ == "__main__":
    main()
