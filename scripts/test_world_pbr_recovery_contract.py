#!/usr/bin/env python3
"""Recovery must use prior approved IDs, never initiate a fresh image batch."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/"scripts/recover_world_pbr.sh").read_text()
w=(ROOT/".github/workflows/owner-world-pbr-recovery.yml").read_text()
for piece in (
    "refs/heads/main", "git diff --name-status HEAD^ HEAD",
    "authorized-world-pbr-recovery-v1.txt", "priorUploadRunId=43412637168",
    "assetSourceRunId=43389183645",
    "assetSourceCommit=903deaafacc29011972b86cbea117bd52d211b76",
    "publication=NO_PUBLIC_ROBLOX_RELEASE", "world-pbr-upload-checkpoint",
    "world-pbr-textures-1k", "verify_world_pbr_checkpoint.py",
    "rojo-build.yml", "resume_run_id=43412637168",
    'gh workflow run upload-world-pbr-opencloud.yml',
    'gh run watch', "len(ids) == 12", "no PUBLIC Roblox place publication",
):
    assert piece in s, piece
for piece in ("branches: [main]", "authorized-world-pbr-recovery-v1.txt",
              "cancel-in-progress: false", "actions: write",
              "contents: read", "fetch-depth: 2",
              "test_world_pbr_checkpoint.py", "scripts/recover_world_pbr.sh"):
    assert piece in w, piece
marker=ROOT/".github/authorized-world-pbr-recovery-v1.txt"
if marker.exists():
    content=marker.read_text()
    for piece in ("ownerUserId=9774173158", "assetFamily=WORLD_12_IMAGES",
                  "priorUploadRunId=43412637168",
                  "assetSourceRunId=43389183645",
                  "assetSourceCommit=903deaafacc29011972b86cbea117bd52d211b76",
                  "publication=NO_PUBLIC_ROBLOX_RELEASE"):
        assert piece in content, piece
print("IRON YARD one-time owner Image ID recovery guard: OK")
