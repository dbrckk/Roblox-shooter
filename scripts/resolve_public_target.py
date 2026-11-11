#!/usr/bin/env python3
"""Resolve only the owner's uniquely named PUBLIC IRON YARD experience.

Repository variables are preferred. If both are missing, discover a unique
public experience under the pinned Roblox creator ID. The existing Open Cloud
publisher independently verifies creator, title, PUBLIC status and root place.
No public-place POST is performed by this script.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

import publish_public_roblox as P

USER_ID = "9774173158"
ALLOWED = frozenset(("ironyard", "ironyardcompetitiverobloxfps"))
MAX_PAGES = 20


def require_id(value, label):
    value = str(value)
    P.require_id(value, label)
    return value


def get_public_json(url):
    request = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "IRON-YARD-public-target-discovery/1.0",
    })
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            return json.loads(response.read())
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError):
        raise P.PublishError("Roblox public games lookup failed") from None


def discover(fetch=get_public_json):
    matches = {}
    cursor = ""
    seen_cursors = set()
    for _ in range(MAX_PAGES):
        query = {
            "accessFilter": "Public", "limit": "50", "sortOrder": "Asc",
        }
        if cursor:
            query["cursor"] = cursor
        url = "https://games.roblox.com/v2/users/" + USER_ID + "/games?" + (
            urllib.parse.urlencode(query))
        response = fetch(url)
        if not isinstance(response, dict) or not isinstance(response.get("data"), list):
            raise P.PublishError("Roblox public games lookup returned invalid data")
        for game in response["data"]:
            if not isinstance(game, dict):
                raise P.PublishError("Invalid public game entry")
            normalized = re.sub(r"[^a-z0-9]", "", str(game.get("name", "")).lower())
            if normalized not in ALLOWED:
                continue
            root = game.get("rootPlace")
            if not isinstance(root, dict):
                raise P.PublishError("Matching public game has no rootPlace object")
            universe = require_id(game.get("id"), "Universe ID")
            place = require_id(root.get("id"), "Place ID")
            matches[universe] = (universe, place)
        next_cursor = response.get("nextPageCursor")
        if next_cursor is None or next_cursor == "":
            break
        if not isinstance(next_cursor, str) or len(next_cursor) > 512:
            raise P.PublishError("Malformed Roblox games pagination")
        if next_cursor in seen_cursors:
            raise P.PublishError("Repeated Roblox games pagination cursor")
        seen_cursors.add(next_cursor)
        cursor = next_cursor
    else:
        raise P.PublishError("Too many public experiences to resolve safely")
    if len(matches) != 1:
        raise P.PublishError(
            "Cannot uniquely identify one PUBLIC IRON YARD owned by the expected user"
        )
    return next(iter(matches.values()))


def resolve(universe, place, key, fetch=get_public_json,
            verify=P.verify_target):
    universe = str(universe or "").strip()
    place = str(place or "").strip()
    if bool(universe) != bool(place):
        raise P.PublishError("Configure both Universe and Place IDs, or neither")
    if universe:
        require_id(universe, "Universe ID")
        require_id(place, "Place ID")
    else:
        universe, place = discover(fetch)
    if not key:
        raise P.PublishError("Missing ROBLOX_OPEN_CLOUD_API_KEY GitHub secret")
    # This is the same fail-closed production target guard as publication.
    verify(universe, place, key)
    return universe, place


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--github-env", required=True)
    args = parser.parse_args(argv)
    universe, place = resolve(
        os.environ.get("CONFIGURED_UNIVERSE_ID", ""),
        os.environ.get("CONFIGURED_PLACE_ID", ""),
        os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip(),
    )
    target = Path(args.github_env)
    with target.open("a", encoding="utf-8") as output:
        output.write(f"IRON_YARD_UNIVERSE_ID={universe}\n")
        output.write(f"IRON_YARD_PLACE_ID={place}\n")
    print("Verified uniquely authorized PUBLIC IRON YARD destination.")
    print("Both public destination IDs exported to subsequent workflow steps.")


if __name__ == "__main__":
    try:
        main()
    except P.PublishError as exc:
        print(f"PUBLIC TARGET DISCOVERY BLOCKED: {exc}", file=sys.stderr)
        sys.exit(1)
