#!/usr/bin/env python3
"""Offline contract for the one-shot user-authorized 3D/PBR rollout."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")

def must(haystack, fragment, label):
    assert fragment in haystack, f"{label}: missing {fragment}"

script = read("scripts/launch_owner_pbr_rollout.sh")
workflow = read(".github/workflows/owner-pbr-rollout.yml")
for item in ("if [[", "GH_TOKEN", "GITHUB_REF", "refs/heads/main",
             "dbrckk/Roblox-shooter", "git diff --name-status HEAD^ HEAD",
             "ownerUserId=9774173158", "assetFamilies=VANGUARD_4_MODELS,WORLD_12_IMAGES",
             "publication=NO_PUBLIC_ROBLOX_RELEASE",
             "ROBLOX_ASSETS_KEY_AVAILABLE", "asset_acceptance_matrix",
             'identifier == 0', 'find_run rojo-build.yml push "$GITHUB_SHA"',
             "dispatch_and_watch assetforge.yml",
             "dispatch_and_watch world-pbr-assets.yml",
             "dispatch_and_watch upload-vanguard-opencloud.yml",
             "dispatch_and_watch upload-world-pbr-opencloud.yml",
             '--field "publish_assets=true"', "gh run watch",
             "No public Roblox game publication"):
    must(script, item, "owner rollout integrity")
for item in ("branches: [main]", ".github/authorized-pbr-rollout-v1.txt",
             "actions: write", "contents: read", "cancel-in-progress: false",
             "fetch-depth: 2", "python3 scripts/test_owner_pbr_rollout.py",
             "python3 scripts/test_asset_activation_pipeline.py",
             "scripts/launch_owner_pbr_rollout.sh"):
    must(workflow, item, "GitHub workflow gate")
assert "github.event_name == 'pull_request'" not in workflow
marker = ROOT / ".github/authorized-pbr-rollout-v1.txt"
if marker.exists():
    # This suite also runs on the future *authorized* main commit. The marker
    # must remain legal once added, otherwise the CI prerequisite deadlocks.
    content = marker.read_text(encoding="utf-8")
    for item in ("ownerUserId=9774173158",
                 "assetFamilies=VANGUARD_4_MODELS,WORLD_12_IMAGES",
                 "publication=NO_PUBLIC_ROBLOX_RELEASE"):
        must(content, item, "owner marker")
print("IRON YARD owner authorized one-shot PBR rollout: contract OK")
