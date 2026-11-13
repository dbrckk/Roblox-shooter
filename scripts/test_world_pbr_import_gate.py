#!/usr/bin/env python3
"""Offline safety checks for the one-time owner-only world PBR import."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / "scripts/launch_world_pbr_import.sh").read_text()
workflow = (ROOT / ".github/workflows/owner-world-pbr-import.yml").read_text()

def must(source, pieces):
    for piece in pieces:
        assert piece in source, f"Missing owner import control: {piece}"

must(script, (
    'GITHUB_REF', 'refs/heads/main', 'GITHUB_REPOSITORY',
    'dbrckk/Roblox-shooter', 'git diff --name-status HEAD^ HEAD',
    '.github/authorized-world-pbr-v1.txt',
    'ownerUserId=9774173158', 'assetFamily=WORLD_12_IMAGES',
    'publication=NO_PUBLIC_ROBLOX_RELEASE',
    'assetSourceRunId=43389183645',
    'assetSourceCommit=903deaafacc29011972b86cbea117bd52d211b76',
    'ROBLOX_ASSETS_KEY_AVAILABLE',
    'all(identifier == 0', 'all(row["ids"][0] > 0',
    '.conclusion == "success"', 'workflow_dispatch',
    'world-pbr-assets.yml', 'rojo-build.yml',
    'gh workflow run upload-world-pbr-opencloud.yml',
    '--field "publish_assets=true"', 'gh run watch', 'gh run view',
    'previous', 'resume_run_id', 'git fetch origin main',
    'len(ids) == 12', 'len(ids) == len(set(ids))',
    'no PUBLIC Roblox place publication',
))
must(workflow, (
    'on:', 'push:', 'branches: [main]', '.github/authorized-world-pbr-v1.txt',
    'actions: write', 'contents: read', 'cancel-in-progress: false',
    'fetch-depth: 2', 'bash -n scripts/launch_world_pbr_import.sh',
    'python3 scripts/test_world_pbr_import_gate.py',
    'python3 scripts/test_asset_activation_pipeline.py',
    'scripts/launch_world_pbr_import.sh',
))
assert 'pull_request:' not in workflow
marker = ROOT / ".github/authorized-world-pbr-v1.txt"
if marker.exists():
    content = marker.read_text(encoding="utf-8")
    must(content, (
        'ownerUserId=9774173158',
        'assetFamily=WORLD_12_IMAGES',
        'publication=NO_PUBLIC_ROBLOX_RELEASE',
        'assetSourceRunId=43389183645',
        'assetSourceCommit=903deaafacc29011972b86cbea117bd52d211b76',
    ))
print("IRON YARD one-time owner world PBR upload safety gate: OK")
