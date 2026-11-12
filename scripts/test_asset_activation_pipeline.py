#!/usr/bin/env python3
"""Regression of atomic PBR activation and generated acceptance matrix workflow."""
from pathlib import Path
import importlib.util
import re

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "asset_matrix", ROOT / "scripts/asset_acceptance_matrix.py")
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def main():
    original_source = matrix.source
    require(matrix.build() == matrix.DOC.read_text(encoding="utf-8"),
            "Current asset acceptance document is stale")

    for kind, registry in (("vanguard", "VanguardAssetIds"),
                           ("world-pbr", "WorldPbrAssetIds")):
        workflow = (ROOT / ".github/workflows"
                    / f"upload-{kind}-opencloud.yml").read_text(encoding="utf-8")
        require("group: iron-yard-owner-pbr-registry" in workflow,
                "Concurrent asset uploads can overwrite the same acceptance document")
        require("git add src/shared/" + registry
                + ".luau docs/ASSET_ACCEPTANCE_MATRIX.md" in workflow,
                "Uploaded IDs and audited matrix must share one commit")
        before, after = workflow.split("git rebase origin/main", 1)
        require("--write" in before and "--write" in after,
                "Matrix must be regenerated before and after rebase")
        require(before.index("asset_acceptance_matrix.py --write")
                < before.index("git add src/shared/" + registry),
                "Matrix must be generated before committing approved IDs")

    palette = original_source(matrix.PALETTES).replace(
        'sourceCommit = ""', 'sourceCommit = "' + "b" * 40 + '"')
    for i, name in enumerate(("olive", "sand", "slate", "rust")):
        palette = palette.replace(name + " = 0,", name + f" = {90001 + i},")
    world = original_source(matrix.WORLD).replace(
        'sourceCommit = ""', 'sourceCommit = "' + "c" * 40 + '"')
    counter = iter(range(91001, 91013))
    world, amount = re.subn(
        r"(ColorMap|NormalMap|RoughnessMap|MetalnessMap) = 0",
        lambda m: m.group(1) + " = " + str(next(counter)), world)
    require(amount == 12, "Expected 12 map channels")

    def build_with(overrides):
        matrix.source = lambda path: (overrides[path] if path in overrides
                                      else original_source(path))
        try:
            return matrix.build()
        finally:
            matrix.source = original_source

    result = build_with({matrix.PALETTES: palette, matrix.WORLD: world})
    require("Opérateurs VANGUARD — 4 prêts hors moteur, 0 bloqués" in result,
            "Uploaded operators incorrectly labeled blocked")
    require("Matériaux du monde — 3 prêts hors moteur, 0 bloqués" in result,
            "Uploaded maps incorrectly labeled blocked")
    require("aucun ID n'est" not in result
            and "Aucun upload Open Cloud" not in result,
            "False no-upload claim after approved batch")

    for label, overrides in (
        ("partial", {matrix.PALETTES: palette.replace("olive = 90001", "olive = 0"),
                     matrix.WORLD: world}),
        ("duplicate", {matrix.PALETTES: palette,
                       matrix.WORLD: world.replace("NormalMap = 91002",
                                                  "NormalMap = 91001")}),
    ):
        try:
            build_with(overrides)
        except AssertionError as err:
            require(("entirely empty or complete" if label == "partial"
                     else "reuses an ID") in str(err),
                    "Rejected batch for wrong reason: " + str(err))
        else:
            raise AssertionError("Asset acceptance allowed " + label + " batch")

    print("IRON YARD PBR atomic batch, workflow and dynamic matrix: OK")


if __name__ == "__main__":
    main()
