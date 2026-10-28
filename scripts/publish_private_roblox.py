#!/usr/bin/env python3
"""Fail-closed publisher for an EXISTING private IRON YARD Roblox experience.

Never creates a public experience, changes visibility or accepts an arbitrary target.
GitHub Actions passes a narrowly scoped Roblox Open Cloud API key via a secret.
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
MAX_SIZE = 104_857_600


class PublishError(Exception):
    pass


def request(method: str, url: str, api_key: str, body: bytes | None = None):
    headers = {
        "x-api-key": api_key,
        "Accept": "application/json",
        "User-Agent": "IRON-YARD-private-place-publisher/1.0",
    }
    if body is not None:
        headers["Content-Type"] = "application/xml"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as err:
        # Never print request headers, API keys or bearer credentials.
        detail = err.read(2048).decode("utf-8", "replace")
        raise PublishError(f"Roblox {method} returned HTTP {err.code}: {detail}") from None
    except urllib.error.URLError as err:
        raise PublishError(f"Roblox {method} connection failed: {err.reason}") from None
    except json.JSONDecodeError as err:
        raise PublishError(f"Roblox {method} returned invalid JSON: {err}") from None


def get_private_universe(universe_id: str, key: str):
    info = request("GET", f"{API_HOST}/cloud/v2/universes/{universe_id}", key)
    if not isinstance(info, dict):
        raise PublishError("Universe lookup returned an unexpected structure")
    name = info.get("displayName") or info.get("display_name") or info.get("name")
    normalized = re.sub(r"[^a-z0-9]", "", str(name).lower())
    if not normalized.startswith("ironyard"):
        raise PublishError(
            "Wrong target: the experience must be named IRON YARD. "
            "Refusing to overwrite another Roblox game."
        )
    visibility = str(info.get("visibility", "")).upper()
    if visibility != "PRIVATE":
        raise PublishError(
            f"Publication refused: IRON YARD visibility is {visibility or 'UNKNOWN'}, "
            "not PRIVATE. Make it private in Creator Dashboard first."
        )
    return info


def verify_place(universe_id: str, place_id: str, key: str):
    place = request(
        "GET",
        f"{API_HOST}/cloud/v2/universes/{universe_id}/places/{place_id}",
        key,
    )
    if not isinstance(place, dict) or not place:
        raise PublishError("Place lookup failed; refusing to publish to unverified place")
    # Access through the universe-scoped path validates their relationship.
    return place


def main():
    parser = argparse.ArgumentParser(description="Publish IRON YARD to an existing PRIVATE Roblox place")
    parser.add_argument("--universe-id", required=True)
    parser.add_argument("--place-id", required=True)
    parser.add_argument("--place-file", default="iron-yard.rbxlx")
    parser.add_argument("--dry-run", action="store_true",
                        help="Check key, ownership scope, game name, place and privacy without uploading")
    args = parser.parse_args()

    if not re.fullmatch(r"[1-9][0-9]{0,19}", args.universe_id):
        raise PublishError("Universe ID must be a positive integer")
    if not re.fullmatch(r"[1-9][0-9]{0,19}", args.place_id):
        raise PublishError("Place ID must be a positive integer")
    key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
    if not key:
        raise PublishError(
            "Missing GitHub Actions secret ROBLOX_OPEN_CLOUD_API_KEY. "
            "Do not put the key in workflow inputs, source files or chat."
        )

    place_file = Path(args.place_file)
    if not args.dry_run:
        if place_file.suffix != ".rbxlx" or not place_file.is_file():
            raise PublishError("Expected a real .rbxlx file created by Rojo")
        size = place_file.stat().st_size
        if size < 4096 or size > MAX_SIZE:
            raise PublishError(f"Unexpected Roblox place size ({size} bytes)")

    before = get_private_universe(args.universe_id, key)
    verify_place(args.universe_id, args.place_id, key)
    print(f"Verified private IRON YARD: {before.get('displayName', 'IRON YARD')}.")
    print(f"Universe {args.universe_id}, Place {args.place_id}.")
    if args.dry_run:
        print("Verification complete; no file uploaded.")
        return

    endpoint = (
        f"{API_HOST}/universes/v1/{args.universe_id}/places/{args.place_id}"
        "/versions?versionType=Published"
    )
    data = request("POST", endpoint, key, place_file.read_bytes())
    version = data.get("versionNumber") if isinstance(data, dict) else None
    if not isinstance(version, int) or version < 1:
        raise PublishError(f"Roblox response lacks a valid place version number: {data!r}")
    after = get_private_universe(args.universe_id, key)
    verify_place(args.universe_id, args.place_id, key)
    print(f"IRON YARD place version {version} uploaded and confirmed PRIVATE.")
    private_url = f"https://www.roblox.com/games/{args.place_id}/"
    print(f"Private experience: {private_url}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(chr(10).join([
                "## IRON YARD — private Roblox publication verified",
                "",
                f"- Universe: `{args.universe_id}`",
                f"- Place: `{args.place_id}`",
                f"- Place version: `{version}`",
                "- Visibility checked before and after: **PRIVATE**",
                f"- Experience: {private_url}",
                "",
            ]))


if __name__ == "__main__":
    try:
        main()
    except PublishError as error:
        print(f"PRIVATE PUBLISH BLOCKED: {error}", file=sys.stderr)
        sys.exit(1)
