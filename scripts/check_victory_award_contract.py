"""Prevent repeated result callbacks from granting duplicate progression."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
awards = (root / "src/server/CombatAwards.luau").read_text()
policy = (root / "src/shared/VictoryAwardPolicy.luau").read_text()
workflow = (root / ".github/workflows/rojo-build.yml").read_text()

assert 'local VictoryAwardPolicy = require(' in awards
assert 'WaitForChild("VictoryAwardPolicy")' in awards
assert "function Policy.claim(state)" in policy
assert "function Policy.reset(state)" in policy
assert 'scripts/test_victory_award_policy.luau' in workflow
assert 'scripts/check_victory_award_contract.py' in workflow
victory = awards.split("function CombatAwards.recordVictory(player)", 1)[1].split(
    "\nfunction CombatAwards.recordDeath(", 1)[0]
assert 'Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE"' in victory
assert "if not VictoryAwardPolicy.claim(state) then return end" in victory
assert victory.index("VictoryAwardPolicy.claim(state)") < victory.index(
    "ProgressionService.recordVictory(player)")
assert victory.index("VictoryAwardPolicy.claim(state)") < victory.index(
    'remotes.WeaponFeedback:FireClient(player, {')
reset = awards.split("function CombatAwards.resetRound()", 1)[1].split(
    "\nfunction CombatAwards.start()", 1)[0]
assert "VictoryAwardPolicy.reset(state)" in reset
assert "victoryGranted = false" in awards
print("IRON YARD victory rewards: one claim before progression, reset per round: OK")
