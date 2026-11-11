#!/usr/bin/env python3
"""Offline fail-closed tests for public Roblox target discovery."""
import sys
from pathlib import Path
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import publish_public_roblox as P
import resolve_public_target as R


def page(games, cursor=None):
    return {"data": games, "nextPageCursor": cursor}


def game(name, universe, place):
    return {"name": name, "id": universe, "rootPlace": {"id": place}}


class TargetResolverTests(unittest.TestCase):
    def test_explicit_ids_are_always_checked_against_cloud(self):
        fetch = Mock(side_effect=AssertionError("Explicit IDs must not search"))
        verify = Mock(return_value=True)
        self.assertEqual(R.resolve("123", "456", "secret", fetch, verify),
                         ("123", "456"))
        verify.assert_called_once_with("123", "456", "secret")
        with self.assertRaises(P.PublishError):
            R.resolve("123", "", "secret", fetch, verify)
        with self.assertRaises(P.PublishError):
            R.resolve("", "456", "secret", fetch, verify)
        with self.assertRaises(P.PublishError):
            R.resolve("0", "456", "secret", fetch, verify)
        with self.assertRaises(P.PublishError):
            R.resolve("123", "abc", "secret", fetch, verify)
        self.assertEqual(fetch.call_count, 0)

    def test_unique_exact_public_game_and_pagination(self):
        entries = [
            page([game("Another game", 11, 12)], "next-cursor"),
            page([game("IRON YARD | Competitive Roblox FPS", 222, 333)]),
        ]
        fetch = Mock(side_effect=entries)
        verify = Mock(return_value=True)
        self.assertEqual(R.resolve("", "", "secret", fetch, verify),
                         ("222", "333"))
        self.assertEqual(fetch.call_count, 2)
        self.assertIn("cursor=next-cursor", fetch.call_args.args[0])
        verify.assert_called_once_with("222", "333", "secret")

    def test_similar_names_and_multiple_matches_never_publish(self):
        for games in (
            [game("Iron Yard - BETA", 111, 222)],
            [game("Iron Yard", 111, 222), game("IRON YARD", 333, 444)],
        ):
            verify = Mock(side_effect=AssertionError("No cloud lookup"))
            with self.assertRaises(P.PublishError):
                R.resolve("", "", "secret", Mock(return_value=page(games)),
                          verify)
            verify.assert_not_called()

    def test_missing_or_malformed_public_game_is_rejected(self):
        for bad in (
            {}, {"data": None}, page([None]),
            page([{"name": "Iron Yard", "id": 2}]),
            page([game("IRON YARD", 0, 2)]),
            page([game("IRON YARD", 1, False)]),
            page([game("IRON YARD", "0" * 3, 4)]),
            page([game("IRON YARD", 1, 2)], cursor=["invalid"]),
        ):
            with self.subTest(response=bad):
                with self.assertRaises(P.PublishError):
                    R.discover(Mock(return_value=bad))

    def test_looping_cursor_and_unverifiable_target_are_blocked(self):
        fetch = Mock(return_value=page([], "repeated"))
        with self.assertRaisesRegex(P.PublishError, "Repeated"):
            R.discover(fetch)
        self.assertEqual(fetch.call_count, 2)

        verify = Mock(side_effect=P.PublishError("Wrong owner"))
        with self.assertRaisesRegex(P.PublishError, "Wrong owner"):
            R.resolve("", "", "secret",
                      Mock(return_value=page([game("IRON YARD", 1, 2)])),
                      verify)
        verify.assert_called_once_with("1", "2", "secret")

    def test_key_required_before_owner_validation(self):
        verify = Mock(return_value=True)
        with self.assertRaisesRegex(P.PublishError, "Missing ROBLOX"):
            R.resolve("1", "2", "", Mock(), verify)
        verify.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
