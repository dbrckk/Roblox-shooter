#!/usr/bin/env python3
"""Offline regression checks for the existing PUBLIC Roblox place publisher.

All Roblox HTTP calls are mocked. These tests must never make a network
request, publish a place, require a real key or disclose credentials.
"""
import contextlib
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import publish_public_roblox as P  # noqa: E402

SHA = "a" * 40
OWNER = "users/9774173158"
UNIVERSE_ID = "1234567"
PLACE_ID = "9876543"
KEY = "offline-mock-key"


def universe(**changes):
    value = {
        "displayName": "IRON YARD",
        "user": OWNER,
        "visibility": "PUBLIC",
        "rootPlace": "places/" + PLACE_ID,
    }
    value.update(changes)
    return value


def place(**changes):
    value = {
        "path": f"universes/{UNIVERSE_ID}/places/{PLACE_ID}",
        "displayName": "IRON YARD",
        "root": True,
    }
    value.update(changes)
    return value


def flags(*extra):
    return [
        "--universe-id", UNIVERSE_ID,
        "--place-id", PLACE_ID,
        "--source-commit", SHA,
        *extra,
    ]


class PublicReleaseTests(unittest.TestCase):
    def test_verified_name_owner_root_and_visibility(self):
        P.verify_universe(universe(), PLACE_ID)
        P.verify_universe(universe(user={"path": OWNER}), PLACE_ID)
        P.verify_universe(universe(displayName="Iron Yard"), PLACE_ID)
        P.verify_universe(universe(visibility="public"), PLACE_ID)
        with mock.patch.object(P, "request", side_effect=[universe(), place()]) as calls:
            self.assertEqual(
                P.verify_target(UNIVERSE_ID, PLACE_ID, KEY)["displayName"],
                "IRON YARD",
            )
            self.assertEqual(calls.call_count, 2)
            self.assertEqual(calls.call_args_list[0].args, (
                "GET", f"{P.API_HOST}/cloud/v2/universes/{UNIVERSE_ID}", KEY))
            self.assertEqual(calls.call_args_list[1].args, (
                "GET",
                f"{P.API_HOST}/cloud/v2/universes/{UNIVERSE_ID}/places/{PLACE_ID}",
                KEY))

    def test_other_games_with_same_prefix_never_pass(self):
        for name in ("IRON YARD RACING", "Iron Yard Beta",
                     "IRONYARD-DEV", "IRON YARD 2", "Other Game", "", None):
            with self.subTest(name=name):
                with self.assertRaisesRegex(P.PublishError,
                                            "named exactly IRON YARD"):
                    P.verify_universe(universe(displayName=name), PLACE_ID)

    def test_wrong_owner_visibility_and_root_rejected(self):
        invalid = [
            ({"user": "users/987"}, "Wrong owner"),
            ({"user": None}, "Wrong owner"),
            ({"user": "groups/9774173158"}, "Wrong owner"),
            ({"visibility": "PRIVATE"}, "not PUBLIC"),
            ({"visibility": None}, "not PUBLIC"),
            ({"rootPlace": "places/111"}, "Root place"),
            ({"rootPlace": None}, "Root place"),
        ]
        for changes, reason in invalid:
            with self.subTest(changes=changes):
                with self.assertRaisesRegex(P.PublishError, reason):
                    P.verify_universe(universe(**changes), PLACE_ID)
        for value in ({}, {"root": False}, {"root": None}, {"root": "true"}, None):
            with self.subTest(place=value):
                with mock.patch.object(
                    P, "request", side_effect=[universe(), value]
                ) as calls:
                    with self.assertRaisesRegex(P.PublishError,
                                                "confirmed root place"):
                        P.verify_target(UNIVERSE_ID, PLACE_ID, KEY)
                    self.assertEqual(calls.call_count, 2)

    def test_missing_or_malformed_credentials_never_touch_network(self):
        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_API_KEY": ""},
                             clear=True), mock.patch.object(
                                 P, "request", side_effect=AssertionError(
                                     "No network without credentials")):
            with self.assertRaisesRegex(P.PublishError, "Missing ROBLOX"):
                P.main(flags("--dry-run"))
            with self.assertRaisesRegex(P.PublishError, "requires --confirm-public"):
                P.main(flags())
            for bad in ("", "0", "-2", "1.2", "12A", "0" + PLACE_ID):
                with self.subTest(place_id=bad):
                    argv = ["--universe-id", UNIVERSE_ID,
                            "--place-id", bad, "--source-commit", SHA,
                            "--dry-run"]
                    with self.assertRaises(P.PublishError):
                        P.main(argv)
            with self.assertRaisesRegex(P.PublishError, "SHA-1"):
                P.main(["--universe-id", UNIVERSE_ID,
                        "--place-id", PLACE_ID,
                        "--source-commit", "z" * 40, "--dry-run"])

    def test_check_only_never_posts_even_if_file_missing(self):
        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_API_KEY": KEY}):
            with mock.patch.object(P, "request",
                                   side_effect=[universe(), place()]) as calls:
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    P.main(flags("--dry-run", "--place-file",
                                 "/nonexistent/invalid.rbxlx"))
                self.assertIn("NO UPLOAD", output.getvalue())
                self.assertEqual(calls.call_count, 2)
                self.assertTrue(all(call.args[0] == "GET"
                                    for call in calls.call_args_list))

    def test_place_file_must_match_exact_source_commit(self):
        with tempfile.TemporaryDirectory() as folder:
            good = Path(folder) / "game.rbxlx"
            good.write_bytes(b"<roblox>" + SHA.encode() + b"x" * 4200)
            P.validate_place_file(good, SHA)
            with self.assertRaisesRegex(P.PublishError, "exact approved source"):
                P.validate_place_file(good, "b" * 40)
            with self.assertRaisesRegex(P.PublishError, "Unexpected place size"):
                good.write_bytes(SHA.encode())
                P.validate_place_file(good, SHA)
            good = Path(folder) / "game.rbxl"
            good.write_bytes(b"<roblox>" + SHA.encode() + b"x" * 4200)
            with self.assertRaisesRegex(P.PublishError, "Expected a Rojo-built"):
                P.validate_place_file(good, SHA)

    def test_successful_live_publication_sends_one_binary_body(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "game.rbxlx"
            content = b"<roblox>" + SHA.encode() + b"X" * 4200
            path.write_bytes(content)
            summary = Path(folder) / "summary.md"
            with mock.patch.dict(os.environ, {
                "ROBLOX_OPEN_CLOUD_API_KEY": KEY,
                "GITHUB_STEP_SUMMARY": str(summary),
            }), mock.patch.object(P, "request", side_effect=[
                universe(), place(), {"versionNumber": 17},
                universe(), place(),
            ]) as calls:
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    P.main(flags("--confirm-public", "--place-file", str(path)))
                self.assertIn("version 17", output.getvalue())
                self.assertIn("PUBLIC verified before and after upload",
                              summary.read_text("utf-8"))
                self.assertEqual(calls.call_count, 5)
                self.assertEqual(
                    [call.args[0] for call in calls.call_args_list],
                    ["GET", "GET", "POST", "GET", "GET"])
                self.assertEqual(calls.call_args_list[2].args, (
                    "POST",
                    f"{P.API_HOST}/universes/v1/{UNIVERSE_ID}/places/"
                    f"{PLACE_ID}/versions?versionType=Published",
                    KEY, content))

    def test_post_success_followed_by_failed_get_is_not_failed_upload(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "game.rbxlx"
            path.write_bytes(b"<roblox>" + SHA.encode() + b"X" * 4200)
            with mock.patch.dict(os.environ, {
                "ROBLOX_OPEN_CLOUD_API_KEY": KEY,
            }), mock.patch.object(P, "request", side_effect=[
                universe(), place(), {"versionNumber": 21},
                P.PublishError("Roblox GET connection failed: transient"),
            ]) as calls:
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    with self.assertRaisesRegex(
                        P.PublishError, "version 21 was ALREADY PUBLISHED"
                    ) as raised:
                        P.main(flags("--confirm-public", "--place-file", str(path)))
                self.assertIn("version 21", output.getvalue())
                self.assertIn("Inspect Creator Dashboard",
                              str(raised.exception))
                self.assertEqual(
                    [call.args[0] for call in calls.call_args_list],
                    ["GET", "GET", "POST", "GET"])

    def test_missing_version_number_never_claims_success(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "game.rbxlx"
            path.write_bytes(b"<roblox>" + SHA.encode() + b"X" * 4200)
            for bad in ({"versionNumber": True}, {"versionNumber": "17"},
                        {"versionNumber": 0}, {}, [], None):
                with self.subTest(response=bad):
                    with mock.patch.dict(os.environ, {
                        "ROBLOX_OPEN_CLOUD_API_KEY": KEY,
                    }), mock.patch.object(P, "request", side_effect=[
                        universe(), place(), bad,
                    ]) as calls:
                        with self.assertRaisesRegex(
                            P.PublishError, "valid place version"
                        ):
                            P.main(flags("--confirm-public",
                                         "--place-file", str(path)))
                        self.assertEqual(calls.call_count, 3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
