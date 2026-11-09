#!/usr/bin/env python3
"""Publish a validated IRON YARD release to an ALREADY PUBLIC Roblox experience.

Never creates experiences, changes visibility or targets another game.
The workflow is manual and requires explicit user confirmation on every upload.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

API_HOST = "https://apis.roblox.com"
OWNER_PATH = "users/9774173158"
MAX_SIZE = 104_857_600


class PublishError(Exception):
    pass


def request(method: str, url: str, api_key: str, body: bytes | None = None):
    headers = {
        "x-api-key": api_key,
        "Accept": "application/json",
        "User-Agent": "IRON-YARD-public-release/1.0",
    }
    if body is not None:
        headers["Content-Type"] = "application/xml"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as err:
        # Keep server response bodies (which can echo request metadata) out of logs.
        raise PublishError(f"Roblox {method} failed: HTTP {err.code}") from None
    except urllib.error.URLError as err:
        raise PublishError(f"Roblox {method} connection failed: {err.reason}") from None
    except json.JSONDecodeError:
        raise PublishError(f"Roblox {method} returned malformed JSON") from None


def require_id(value: str, label: str):
    if not re.fullmatch(r"[1-9][0-9]{0,19}", value):
        raise PublishError(f"{label} must be a positive integer")


def verify_universe(info: object, place_id: str):
    if not isinstance(info, dict):
        raise PublishError("Universe lookup returned invalid data")
    name = info.get("displayName") or info.get("display_name") or info.get("name")
    normalized = re.sub(r"[^a-z0-9]", "", str(name).lower())
    if not normalized.startswith("ironyard"):
        raise PublishError("Wrong destination: refusing to overwrite a non-IRON YARD game")
    owner = info.get("user")
    if isinstance(owner, dict):
        owner = owner.get("path")
    if str(owner).strip("/") != OWNER_PATH:
        raise PublishError("Wrong owner: target is not the intended Roblox creator")
    if str(info.get("visibility", "")).upper() != "PUBLIC":
        raise PublishError("Target is not PUBLIC. Set visibility on Creator Dashboard; no upload occurred")
    root = info.get("rootPlace")
    if isinstance(root, dict):
        root = root.get("path")
    if not isinstance(root, str) or root.strip("/").split("/")[-1] != place_id:
        raise PublishError("Root place does not match the configured IRON YARD place ID")
    return info


def verify_target(universe_id: str, place_id: str, key: str):
    universe = request("GET", f"{API_HOST}/cloud/v2/universes/{universe_id}", key)
    verify_universe(universe, place_id)
    place = request("GET",
                    f"{API_HOST}/cloud/v2/universes/{universe_id}/places/{place_id}",
                    key)
    if not isinstance(place, dict) or not place:
        raise PublishError("Place is absent from the expected universe")
    return universe


def validate_place_file(path: Path, source_commit: str):
    if path.suffix.lower() != ".rbxlx" or not path.is_file():
        raise PublishError("Expected a Rojo-built .rbxlx file")
    size = path.stat().st_size
    if not 4096 <= size <= MAX_SIZE:
        raise PublishError(f"Unexpected place size: {size} bytes")
    if source_commit.encode("ascii") not in path.read_bytes():
        raise PublishError("Built place lacks the exact approved source commit; release blocked")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Manually publish IRON YARD to an existing PUBLIC Roblox experience")
    parser.add_argument("--universe-id", required=True)
    parser.add_argument("--place-id", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--place-file", default="iron-yard.rbxlx")
    parser.add_argument("--dry-run", action="store_true", help="Verify only: no upload")
    parser.add_argument("--confirm-public", action="store_true", help="Explicit consent to update a live public game")
    args = parser.parse_args(argv)

    require_id(args.universe_id, "Universe ID")
    require_id(args.place_id, "Place ID")
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_commit):
        raise PublishError("Source commit must be a full lowercase Git SHA-1")
    if not args.dry_run and not args.confirm_public:
        raise PublishError("Live publication requires --confirm-public")
    key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
    if not key:
        raise PublishError("Missing ROBLOX_OPEN_CLOUD_API_KEY GitHub Actions secret")

    if not args.dry_run:
        validate_place_file(Path(args.place_file), args.source_commit)
    before = verify_target(args.universe_id, args.place_id, key)
    print(f"Verified existing PUBLIC IRON YARD: {before.get('displayName')}.")
    print(f"Universe {args.universe_id} / Place {args.place_id} / Commit {args.source_commit}.")
    if args.dry_run:
        print("PUBLIC target preflight successful: NO UPLOAD.")
        return

    endpoint = (
        f"{API_HOST}/universes/v1/{args.universe_id}/places/{args.place_id}"
        "/versions?versionType=Published"
    )
    result = request("POST", endpoint, key, Path(args.place_file).read_bytes())
    version = result.get("versionNumber") if isinstance(result, dict) else None
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        raise PublishError("Upload response did not confirm a valid place version")
    verify_target(args.universe_id, args.place_id, key)
    public_url = f"https://www.roblox.com/games/{args.place_id}/"
    print(f"Published PUBLIC IRON YARD version {version} from {args.source_commit}.")
    print(f"Experience: {public_url}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as out:
            out.write("\n".join([
                "## IRON YARD — live public release", "",
                f"- Source commit: \u0060{args.source_commit}\u0060",
                f"- Universe / place: \u0060{args.universe_id}\u0060 / \u0060{args.place_id}\u0060",
                f"- Roblox place version: \u0060{version}\u0060",
                "- PUBLIC verified before and after upload",
                f"- Experience: {public_url}",
                "- Existing live servers may need to restart to receive the update.", "",
            ]))


if __name__ == "__main__":
    try:
        main()
    except PublishError as exc:
        print(f"PUBLIC RELEASE BLOCKED: {exc}", file=sys.stderr)
        sys.exit(1)
