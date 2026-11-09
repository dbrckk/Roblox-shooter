#!/usr/bin/env python3
"""Stamp the exact Git commit into the ReplicatedStorage build metadata."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "src/shared/BuildInfo.luau"


def render(sha: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Expected a full lowercase Git SHA-1")
    return ("-- IRON YARD / source provenance, generated before the Rojo build.\n"
            "-- The release pipeline never uses manually asserted version strings.\n"
            'return { sourceSha = "' + sha + '", short = "' + sha[:9] + '" }\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    TARGET.write_text(render(args.sha), encoding="utf-8")
    print(f"Stamped IRON YARD source {args.sha} into {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
