#!/usr/bin/env bash
# One-shot, GitHub-initiated owner rollout. This script never receives an API key;
# it dispatches existing owner-gated import workflows and verifies their outcomes.
set -euo pipefail
: "${GH_TOKEN:?GitHub Actions token is required}"
: "${GITHUB_REPOSITORY:?GitHub repository is required}"
: "${GITHUB_SHA:?Pinned owner authorization commit is required}"
command -v gh >/dev/null
command -v jq >/dev/null

workflow_run_id() {
  local workflow="$1" event="$2" head_sha="$3" since="${4:-}"
  gh run list --workflow "$workflow" --event "$event" --limit 60 \
    --json databaseId,headSha,createdAt,event |
    jq -r --arg sha "$head_sha" --arg since "$since" \
      '[.[] | select(.headSha == $sha and .createdAt >= $since)] | sort_by(.createdAt) | last | .databaseId // empty'
}

watch_success() {
  local label="$1" id="$2"
  [[ "$id" =~ ^[0-9]+$ ]] || { echo "Missing run ID for $label" >&2; return 1; }
  echo "Checking $label via GitHub Actions run $id"
  gh run watch "$id" --interval 20 --exit-status
  local conclusion
  conclusion="$(gh run view "$id" --json conclusion --jq .conclusion)"
  [[ "$conclusion" == success ]] || { echo "$label was not successful ($conclusion)" >&2; return 1; }
  echo "- $label: successful run $id" >> "$GITHUB_STEP_SUMMARY"
}

find_run() {
  local workflow="$1" event="$2" head_sha="$3" since="${4:-}"
  local id=""
  for _ in $(seq 1 36); do
    id="$(workflow_run_id "$workflow" "$event" "$head_sha" "$since")"
    if [[ "$id" =~ ^[0-9]+$ ]]; then echo "$id"; return 0; fi
    sleep 5
  done
  echo "No matching GitHub Actions run for $workflow @ $head_sha" >&2
  return 1
}

dispatch_and_watch() {
  local workflow="$1"
  shift
  local sha started id
  sha="$(gh api "repos/$GITHUB_REPOSITORY/commits/main" --jq .sha)"
  [[ "$sha" =~ ^[a-f0-9]{40}$ ]] || { echo "Cannot pin main SHA" >&2; return 1; }
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gh workflow run "$workflow" --ref main "$@"
  id="$(find_run "$workflow" workflow_dispatch "$sha" "$started")"
  watch_success "$workflow" "$id"
  LAST_RUN_ID="$id"
}

# The owner added a unique marker file in an actual main commit. Editing it
# later cannot retrigger uploads; CI checks this workflow only on addition.
[[ "$GITHUB_REF" == refs/heads/main ]] || { echo "Not main" >&2; exit 1; }
[[ "$GITHUB_REPOSITORY" == dbrckk/Roblox-shooter ]] || { echo "Unexpected repository" >&2; exit 1; }
marker=".github/authorized-pbr-rollout-v1.txt"
# Require an added marker, not a changed marker, for this one-shot action.
[[ "$(git diff --name-status HEAD^ HEAD -- "$marker")" == "A"$'\t'"$marker" ]] || {
  echo "This is not the dedicated, first-time owner marker addition" >&2; exit 1;
}
grep -Fxq 'ownerUserId=9774173158' "$marker"
grep -Fxq 'assetFamilies=VANGUARD_4_MODELS,WORLD_12_IMAGES' "$marker"
grep -Fxq 'publication=NO_PUBLIC_ROBLOX_RELEASE' "$marker"
[[ "${ROBLOX_ASSETS_KEY_AVAILABLE:-false}" == true ]] || {
  echo "Roblox Open Cloud Assets key is not configured; no upload attempted" >&2; exit 1;
}

# No uploads or publication on partial/already activated registries.
python3 - <<'PY'
import sys
sys.path.insert(0, "scripts")
import asset_acceptance_matrix as asset
palette, _ = asset.palettes()
world, _ = asset.world()
assert len(palette) == 4 and len(world) == 3
assert all(identifier == 0 for row in palette + world for identifier in row["ids"]), (
    "Owner rollout requires two entirely empty asset registries")
print("Confirmed: four operators and twelve world map IDs currently unpopulated")
PY

# Important step: require the authorized commit to have a green Rojo CI, not
# merely to parse locally, before any permanent asset creation on Roblox.
main_ci="$(find_run rojo-build.yml push "$GITHUB_SHA")"
watch_success "Authorized main Rojo build" "$main_ci"

# Always produce fresh provenance-pinned original assets. GH Actions artifacts
# have finite retention, and the previous archive might have expired.
dispatch_and_watch assetforge.yml
vanguard_source="$LAST_RUN_ID"
dispatch_and_watch world-pbr-assets.yml
world_source="$LAST_RUN_ID"

# Existing upload workflows do all GLB/PNG integrity, ownership, moderation,
# checkpointing and atomic ID/acceptance-matrix commits. Never bypass them.
dispatch_and_watch upload-vanguard-opencloud.yml \
  --field "asset_run_id=$vanguard_source" \
  --field "creator_user_id=9774173158" \
  --field "publish_assets=true"
dispatch_and_watch upload-world-pbr-opencloud.yml \
  --field "asset_run_id=$world_source" \
  --field "creator_user_id=9774173158" \
  --field "publish_assets=true"

# Both importers push their verified IDs to main. Do not activate a public
# Roblox place blindly; visual quality and permissions still require runtime QA.
echo "### Owner PBR rollout" >> "$GITHUB_STEP_SUMMARY"
echo "Roblox upload workflows completed; check the resulting main CI, 4 Model IDs and 12 Image IDs." >> "$GITHUB_STEP_SUMMARY"
echo "**No public Roblox game publication was requested.**" >> "$GITHUB_STEP_SUMMARY"
