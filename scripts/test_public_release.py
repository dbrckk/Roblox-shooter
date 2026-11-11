#!/usr/bin/env python3
"""Offline public-release contract and fail-closed safety checks."""
from contextlib import redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_fail(fn, label):
    try:
        fn()
    except Exception:
        return
    raise AssertionError(label)


def main():
    publisher = load("publisher", "scripts/publish_public_roblox.py")
    stamp = load("stamp", "scripts/stamp_build.py")
    sha = "a" * 40
    assert stamp.render(sha).count(sha) == 1
    assert 'short = "aaaaaaaaa"' in stamp.render(sha)
    check_fail(lambda: stamp.render("invalid"), "Invalid source SHA accepted")

    universe = {
        "displayName": "IRON YARD | Competitive Roblox FPS",
        "user": "users/9774173158",
        "visibility": "PUBLIC",
        "rootPlace": "universes/123/places/456",
    }
    publisher.verify_universe(universe, "456")
    publisher.verify_universe(dict(universe, displayName="IRON YARD"), "456")
    for impostor in ("IRON YARD Racing", "IRON YARD DEV",
                     "IRON YARD | Other Experience"):
        check_fail(
            lambda name=impostor: publisher.verify_universe(
                dict(universe, displayName=name), "456"),
            "Publisher must reject sibling IRON YARD games",
        )
    for field, bad in (
        ("displayName", "Chaos Survival"),
        ("user", "users/1"),
        ("visibility", "PRIVATE"),
        ("rootPlace", "universes/123/places/789"),
        ("rootPlace", None),
    ):
        damaged = dict(universe, **{field: bad})
        check_fail(lambda x=damaged: publisher.verify_universe(x, "456"),
                   f"Unsafe target accepted: {field}")
    check_fail(lambda: publisher.require_id("0", "Universe"), "Zero ID accepted")
    check_fail(lambda: publisher.require_id("../123", "Universe"), "Bad ID accepted")

    with tempfile.TemporaryDirectory() as folder:
        place = Path(folder) / "iron-yard.rbxlx"
        place.write_bytes(b'<roblox>' + sha.encode() + b"x" * 5000 + b"</roblox>")
        publisher.validate_place_file(place, sha)
        check_fail(lambda: publisher.validate_place_file(place, "b" * 40),
                   "Mismatched build stamp accepted")
        seen = []

        def fake_request(method, url, key, body=None):
            assert key == "offline-test-key"
            seen.append(method)
            if "cloud/v2/universes/123/places/456" in url:
                return {"name": "universes/123/places/456", "root": True}
            if "cloud/v2/universes/123" in url:
                return universe
            if method == "POST" and "versions?versionType=Published" in url:
                return {"versionNumber": 21}
            raise AssertionError("Unexpected API path " + url)

        publisher.request = fake_request
        opts = ["--universe-id", "123", "--place-id", "456",
                "--source-commit", sha, "--place-file", str(place)]
        with patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_API_KEY": "offline-test-key"}):
            with redirect_stdout(io.StringIO()):
                publisher.main(opts + ["--dry-run"])
            assert seen == ["GET", "GET"], seen
            check_fail(lambda: publisher.main(opts), "Missing release confirmation accepted")
            assert "POST" not in seen
            with redirect_stdout(io.StringIO()):
                publisher.main(opts + ["--confirm-public"])
            assert seen.count("POST") == 1
            assert seen[-2:] == ["GET", "GET"], seen
            seen.clear()
            with patch.dict(universe, {"visibility": "PRIVATE"}):
                check_fail(lambda: publisher.main(opts + ["--confirm-public"]),
                           "Private destination accepted")
            assert "POST" not in seen
    workflow = (ROOT / ".github/workflows/publish-roblox-public.yml").read_text()
    assert "workflow_dispatch:" in workflow
    assert "on:\n  push:" not in workflow
    assert "Require successful CI for exact source commit" in workflow
    assert "confirm-public" in workflow
    assert "check_only" in workflow
    assert not (ROOT / ".github/workflows/publish-roblox-private.yml").exists()
    print("IRON YARD public release / version provenance offline gates: OK")


if __name__ == "__main__":
    main()
