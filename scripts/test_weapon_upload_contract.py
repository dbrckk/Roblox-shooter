#!/usr/bin/env python3
"""Offline security and state-transition checks for weapon Open Cloud uploads."""
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import upload_weapon_models as U


def fake_entries():
    return {(w, lod): {
        "filename": f"iron_yard_{w}_{lod}.glb",
        "bytes": 3300,
        "sha256": f"{len(w):02x}" * 30 + ("00" if lod == "LOD0" else "01"),
        "triangles": 1000 if lod == "LOD0" else 400,
        "raw": b"genuine-model-validated-by-real-source-parser",
    } for w in U.WEAPONS for lod in U.LODS}


def flags(root, publish=False):
    return [
        "--assets", str(root / "source"),
        "--owner-user-id", "9774173158",
        "--source-commit", "a" * 40,
        "--checkpoint", str(root / "checkpoint.json"),
        "--module", str(root / "WeaponAssetIds.luau"),
    ] + (["--publish"] if publish else [])


def expect_invalid(response, owner=9774173158):
    try:
        U.confirmed_asset(response, owner)
    except ValueError:
        return
    raise AssertionError("Invalid asset creator/type/moderation/ID accepted")


def main():
    valid = {
        "assetId": "123",
        "assetType": "ASSET_TYPE_MODEL",
        "creationContext": {"creator": {"userId": "9774173158"}},
        "moderationResult": {"moderationState": "MODERATION_STATE_APPROVED"},
    }
    assert U.confirmed_asset(valid, 9774173158) == 123
    for edited in (
        {"assetId": "0"},
        {"assetId": "-1"},
        {"assetType": "ASSET_TYPE_MESH"},
        {"assetType": ""},
        {"creationContext": {"creator": {"userId": "42"}}},
        {"moderationResult": {"moderationState": "MODERATION_STATE_REJECTED"}},
        {"moderationResult": {"moderationState": "MODERATION_STATE_PENDING"}},
    ):
        expect_invalid(dict(valid, **edited))
    expect_invalid(None)
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        module = root / "WeaponAssetIds.luau"
        original = "return { ownerUserId = 9774173158, modelIds = {} }\n"
        module.write_text(original, "utf-8")
        (root / "source").mkdir()
        entries = fake_entries()
        calls = []
        with mock.patch.object(U, "sources", return_value=entries), \
                mock.patch.object(U, "request_json",
                                  side_effect=AssertionError("network in dry-run")):
            assert U.main(flags(root)) == 0
        assert module.read_text() == original
        assert not (root / "checkpoint.json").exists(), "Dry-run wrote checkpoint"

        # First upload interrupted on third Model: existing production IDs
        # must not change. Durable checkpoint retains confirmed first two.
        def interrupted(owner, w, lod, raw, key):
            calls.append((w, lod))
            if len(calls) == 3:
                raise RuntimeError("temporary moderation/network failure")
            return 1000 + len(calls)

        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_ASSETS_KEY": "fake-key"}), \
                mock.patch.object(U, "sources", return_value=fake_entries()), \
                mock.patch.object(U, "upload_model", side_effect=interrupted):
            try:
                U.main(flags(root, publish=True))
            except RuntimeError:
                pass
            else:
                raise AssertionError("Failed upload must not mark success")

        assert module.read_text() == original, "Partial upload changed live registry"
        checkpoint = json.loads((root / "checkpoint.json").read_text())
        assert len(checkpoint["models"]) == 2, "Missing partial upload checkpoint"

        verified = []
        uploaded = []
        def verify(asset_id, owner, key):
            verified.append(asset_id)
            return asset_id in (1001, 1002)

        def resumed(owner, weapon, lod, raw, key):
            uploaded.append((weapon, lod))
            return 2000 + len(uploaded)

        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_ASSETS_KEY": "fake-key"}), \
                mock.patch.object(U, "sources", return_value=fake_entries()), \
                mock.patch.object(U, "upload_model", side_effect=resumed), \
                mock.patch.object(U, "verify_existing", side_effect=verify):
            assert U.main(flags(root, publish=True)) == 0
        assert len(verified) == 2 and len(uploaded) == 8, \
            "Checkpoint IDs must be remotely reverified before reuse"
        contents = module.read_text()
        assert "LOD0 = 1001" in contents and "LOD1 = 1002" in contents
        assert "LOD1 = 2008" in contents and "ownerUserId = 9774173158" in contents
        assert contents.count("LOD0 =") == 5 and contents.count("LOD1 =") == 5

        # Malformed owner must not upload even when a key is configured.
        module.write_text("return { ownerUserId = 99, modelIds = {} }")
        with mock.patch.object(U, "sources",
                               side_effect=AssertionError("source touched")):
            try:
                U.main(flags(root, publish=True))
            except ValueError:
                pass
            else:
                raise AssertionError("Mismatched creator registry accepted")
    print("IRON YARD weapon Open Cloud: fail-closed owner, no-network dry-run, "
          "partial checkpoint and 10-asset commit OK")


if __name__ == "__main__":
    main()
