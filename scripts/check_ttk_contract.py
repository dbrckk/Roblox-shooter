#!/usr/bin/env python3
"""Static wiring checks for the IRON YARD TTK balance harness (LOT 0a).

The executable Luau suite owns the numbers; this contract only guarantees the
harness stays a pure model of WeaponConfig and that CI actually runs it.
It never asserts a balance target and never measures engine performance.
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
    model = source("src/shared/TtkModel.luau")
    tests = source("scripts/test_ttk_model.luau")
    config = source("src/shared/WeaponConfig.luau")
    workflow = source(".github/workflows/rojo-build.yml")

    # 1. The harness must remain pure: no engine access, no dependency graph.
    for forbidden in ("game:GetService", "require(", "workspace.", ":WaitForChild"):
        require(forbidden not in model,
                f"TtkModel must stay a pure module: found `{forbidden}`")
    require("math.random" not in model,
            "TtkModel must stay deterministic: no random sampling")

    # 2. The model exposes the three documented entry points.
    for signature in (
        "function TtkModel.shotsToKill(",
        "function TtkModel.damagePerShot(",
        "function TtkModel.reachesRange(",
        "function TtkModel.timeToKill(",
    ):
        has(model, signature, "TtkModel public API")

    # 3. Damage stays authored in WeaponConfig: the model reads it, never owns it.
    # A numeric literal here would create a second source of truth; reading
    # `local damage = weapon[field]` from WeaponConfig is the intended flow.
    require(re.search(r"\b(?:damage|headshotDamage)\s*=\s*\d", model) is None,
            "TtkModel must not author a numeric damage value")
    require("weapon[field]" in model,
            "TtkModel must read the zone damage field from the weapon")
    require("weapon.fireCooldown" in model,
            "TtkModel must read cadence from the weapon")
    # Indentation is mixed (spaces and tabs) across the file, so accept any
    # leading whitespace and only require the five authored weapon keys.
    weapon_defs = re.findall(r"^[ \t]*(\w+)\s*=\s*\{", config, flags=re.MULTILINE)
    require(all(name in weapon_defs for name in
                ("AssaultRifle", "Shotgun", "Pistol", "Sniper", "Knife")),
            "WeaponConfig must keep the five authored weapon definitions")
    require(len(re.findall(r"damage\s*=\s*\d+", config)) >= 5,
            "WeaponConfig must remain the single source of base damage")

    # 4. The executable baseline must exercise both modules and be non-empty.
    has(tests, 'require("../src/shared/TtkModel")', "TTK baseline suite")
    has(tests, 'require("../src/shared/WeaponConfig")', "TTK baseline suite")
    has(tests, "local BASELINE = {", "TTK baseline suite")
    require(len(tests.splitlines()) > 100,
            "TTK baseline suite is suspiciously short")

    # 5. CI must actually run the suite and this contract.
    has(workflow, "./luau scripts/test_ttk_model.luau",
        "rojo-build.yml TTK suite step")
    has(workflow, "python3 scripts/check_ttk_contract.py",
        "rojo-build.yml TTK contract step")

    print("IRON YARD TTK harness wiring contract (pure model, authored damage, CI wiring): OK")


if __name__ == "__main__":
    main()
