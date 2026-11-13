#!/usr/bin/env bash
# Single, owner-approved batch: publish the already audited 12 original
# world PBR images as Roblox Image assets. This never publishes a game place.
set -euo pipefail
: "${GH_TOKEN:?GitHub Actions token is required}"
: "${GITHUB_SHA:?Pinned authorization commit is required}"
: "${GITHUB_REPOSITORY:?GitHub repository is required}"
command -v gh >/dev/null
command -v jq >/dev/null

[[ "$GITHUB_REF" == "refs/heads/main" ]] || { echo "Not main" >&2; exit 1; }
[[ "$GITHUB_REPOSITORY" == "dbrckk/Roblox-shooter" ]] || {
  echo "Unexpected repository" >&2; exit 1;
}
marker=".github/authorized-world-pbr-v1.txt"
[[ "$(git diff --name-status HEAD^ HEAD -- "$marker")" == "A"$'\t'"$marker" ]] || {
  echo "Not the first addition of the owner-approved marker" >&2; exit 1;
}
grep -Fxq 'ownerUserId=9774173158' "$marker"
grep -Fxq 'assetFamily=WORLD_12_IMAGES' "$marker"
grep -Fxq 'publication=NO_PUBLIC_ROBLOX_RELEASE' "$marker"
grep -Fxq 'assetSourceRunId=43389183645' "$marker"
grep -Fxq 'assetSourceCommit=903deaafacc29011972b86cbea117bd52d211b76' "$marker"
[[ "${ROBLOX_ASSETS_KEY_AVAILABLE:-false}" == "true" ]] || {
  echo "Owner's Open Cloud Assets key not configured; no upload attempted" >&2; exit 1;
}

python3 - <<'PY'
import sys
sys.path.insert(0, "scripts")
import asset_acceptance_matrix as assets
operators, _ = assets.palettes()
world, _ = assets.world()
assert len(operators) == 4 and all(row["ids"][0] > 0 for row in operators), (
    "All four owner-verified VANGUARD IDs must be installed first")
assert len(world) == 3 and all(identifier == 0
    for row in world for identifier in row["ids"]), (
    "World PBR registry must be entirely empty to avoid repeat uploads")
print("Verified: 4 VANGUARD model IDs present; 12 world images not yet uploaded")
PY

source_id=43389183645
source_sha=903deaafacc29011972b86cbea117bd52d211b76
gh api "repos/$GITHUB_REPOSITORY/actions/runs/$source_id" |
  jq -e --arg sha "$source_sha" '
    .conclusion == "success" and
    .head_sha == $sha and
    .event == "workflow_dispatch" and
    .path == ".github/workflows/world-pbr-assets.yml" and
    .repository.full_name == "dbrckk/Roblox-shooter"
  ' >/dev/null || { echo "Source archive provenance could not be verified" >&2; exit 1; }

# A separate marker commit is reviewed and must pass the exact same build.
# Main must not change while the authorized upload is dispatched.
status=""
for _ in $(seq 1 60); do
  status="$(gh run list --workflow rojo-build.yml --event push --limit 60 \
    --json databaseId,headSha,status,conclusion |
    jq -r --arg sha "$GITHUB_SHA"       '[.[] | select(.headSha == $sha)] | sort_by(.databaseId) | last |
        (.conclusion // "pending")')"
  [[ "$status" == "success" ]] && break
  if [[ "$status" == "failure" || "$status" == "cancelled" ]]; then
    echo "Authorized main Rojo build failed: $status" >&2; exit 1
  fi
  sleep 5
done
[[ "$status" == "success" ]] || { echo "No green authorized main CI" >&2; exit 1; }
[[ "$(gh api "repos/$GITHUB_REPOSITORY/commits/main" --jq .sha)" == "$GITHUB_SHA" ]] || {
  echo "Main changed since authorization: refusing stale upload" >&2; exit 1;
}

# Refuse automated reruns after ANY previous dispatch from this exact
# authorization SHA: a failed upload could contain partially created assets.
previous="$(gh run list --workflow upload-world-pbr-opencloud.yml \
  --event workflow_dispatch --limit 100 --json databaseId,headSha |
  jq -r --arg sha "$GITHUB_SHA" '[.[] | select(.headSha == $sha)] | length')"
[[ "$previous" == "0" ]] || {
  echo "A prior upload already ran from this marker; use resume_run_id for recovery" >&2
  exit 1
}

started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gh workflow run upload-world-pbr-opencloud.yml --ref main \
  --field "asset_run_id=$source_id" \
  --field "creator_user_id=9774173158" \
  --field "publish_assets=true"
upload_id=""
for _ in $(seq 1 60); do
  upload_id="$(gh run list --workflow upload-world-pbr-opencloud.yml \
    --event workflow_dispatch --limit 40 \
    --json databaseId,headSha,createdAt |
    jq -r --arg sha "$GITHUB_SHA" --arg started "$started"       '[.[] | select(.headSha == $sha and .createdAt >= $started)] |
        sort_by(.databaseId) | last | .databaseId // empty')"
  [[ "$upload_id" =~ ^[0-9]+$ ]] && break
  sleep 5
done
[[ "$upload_id" =~ ^[0-9]+$ ]] || {
  echo "Upload dispatched but cannot confirm run ID; do not retry blindly" >&2
  exit 1
}
echo "Verifying owner upload run $upload_id"
echo "- Owner upload: https://github.com/$GITHUB_REPOSITORY/actions/runs/$upload_id" \
  >> "$GITHUB_STEP_SUMMARY"
gh run watch "$upload_id" --interval 20 --exit-status
[[ "$(gh run view "$upload_id" --json conclusion --jq .conclusion)" == "success" ]] || {
  echo "Open Cloud Image upload incomplete" >&2; exit 1;
}

# Registered IDs must be all nonzero, unique, owner/source scoped and on main.
git fetch origin main
python3 - <<'PY'
import re
import subprocess
module = subprocess.check_output(
    ["git", "show", "origin/main:src/shared/WorldPbrAssetIds.luau"], text=True)
assert "ownerUserId = 9774173158" in module
assert 'sourceCommit = "903deaafacc29011972b86cbea117bd52d211b76"' in module
found = re.findall(
    r"(?:ColorMap|NormalMap|RoughnessMap|MetalnessMap)\s*=\s*(\d+)", module)
ids = [int(value) for value in found]
assert len(ids) == 12 and all(value > 0 for value in ids)
assert len(ids) == len(set(ids)), "Duplicated world PBR Image ID"
print("Confirmed: all twelve world PBR Image IDs are committed to main")
PY
echo "- All 12 Image IDs confirmed; no PUBLIC Roblox place publication requested." \
  >> "$GITHUB_STEP_SUMMARY"
