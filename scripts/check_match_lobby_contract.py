"""Server integration contract: last participant exit cannot leak duel/FFA state.

The pure Luau policy has executable edge-case coverage; this check ensures
the actual Roblox MatchService applies it BEFORE duel-forfeit handling and
clears every replicated attribute on the empty-roster transition.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
match = (root / "src/server/MatchService.luau").read_text(encoding="utf-8")
policy = (root / "src/shared/MatchLobbyPolicy.luau").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/rojo-build.yml").read_text(encoding="utf-8")

assert 'function Policy.shouldReset(rosterCount, phase, mode, hasDuel)' in policy
assert 'local MatchLobbyPolicy = require(' in match
assert 'WaitForChild("MatchLobbyPolicy")' in match
assert 'scripts/test_match_lobby_policy.luau' in workflow

tick = match.split("local function tick()", 1)[1].split(
    "\nfunction MatchService.start()", 1)[0]
reset_guard = 'if MatchLobbyPolicy.shouldReset(#players, phase, mode, duel ~= nil) then'
forfeit_guard = 'if duel and phase ~= "RESULTS" and not duelPlayersIntact() then'
assert reset_guard in tick
assert forfeit_guard in tick
assert tick.index(reset_guard) < tick.index(forfeit_guard), (
    "Empty lobby must bypass forfeit/RESULTS before new players arrive")
reset = tick.split(reset_guard, 1)[1].split(
    "if #players == 0 then return end", 1)[0]
for needle in (
    "DuelCombatState.clear()",
    "releaseDuelPrep()",
    "duel = nil",
    'mode = "FFA"',
    "finalResult = nil",
    'Workspace:SetAttribute("IronYardMatchMode", mode)',
    'Workspace:SetAttribute("IronYardDuelLastResult", "")',
    'Workspace:SetAttribute("IronYardFinalStandings", "")',
    "publishDuelScores()",
    'transition("WAITING", 0)',
    "return",
):
    assert needle in reset, f"Empty lobby reset must include {needle}"
assert 'if #players == 0 then return end' in tick
assert "DuelRules.forfeitSide(Players:GetPlayers(), a, b)" in tick
print("IRON YARD server empty-lobby transition: resets duel identity, mode, result and podium: OK")
