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
        {"moderationResult": {}},
    ):
        expect_invalid(dict(valid, **edited))
    expect_invalid(None)
    assert U.safe_operation_path("operations/AZ-987_123") == "operations/AZ-987_123"
    for bad in ("assets/123", "operations/../assets/1", "operations/foo/bar",
                "operations/valid?x=1", "", None):
        try:
            U.safe_operation_path(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("Unsafe operation path accepted: " + str(bad))

    approved = dict(valid)
    pending = dict(valid, moderationResult={"moderationState":
                                           "MODERATION_STATE_PENDING"})
    completed_pending = {"path": "operations/pending-one", "done": True,
                         "response": pending}
    observed_urls = []
    states = [
        pending, completed_pending,
        approved,
    ]
    def simulated_operation_get(url, key):
        assert "operations/pending-one" in url or url.endswith("/assets/123")
        observed_urls.append(url)
        return states.pop(0)
    with mock.patch.object(U, "request_json", side_effect=simulated_operation_get), \
            mock.patch.object(U.time, "sleep", return_value=None):
        assert U.poll_operation("operations/pending-one", 9774173158, "fake",
                                initial=completed_pending) == 123
    assert len(observed_urls) == 3 and not states
    assert observed_urls[0].endswith("/assets/123")
    assert observed_urls[1].endswith("/operations/pending-one")
    assert observed_urls[2].endswith("/assets/123")

    with mock.patch.object(U, "request_json",
                           side_effect=AssertionError("No network for rejected op")):
        try:
            U.poll_operation("operations/failed", 9774173158, "fake",
                             initial={"done": True, "error": {"code": 7}})
        except RuntimeError:
            pass
        else:
            raise AssertionError("Rejected operation accepted")

    assert U.confirmed_asset(
        dict(valid, moderationResult={"moderationState": "Approved"}),
        9774173158) == 123
    example = U.render_module(9774173158, "a" * 40, {
        (w, lod): {"assetId": 100 + i * 2 + j}
        for i, w in enumerate(U.WEAPONS)
        for j, lod in enumerate(U.LODS)
    })
    recognized = U.matching_committed_ids(example, "a" * 40)
    assert len(recognized) == 10, "Existing signed source registry not parsed"
    assert all(f"{U.RUNTIME_NAMES[w]} = {{ LOD0 =" in example for w in U.WEAPONS)
    assert not any(f"        {w} = {{ LOD0 =" in example for w in U.WEAPONS)
    assert "AssaultRifle = { LOD0 =" in example
    assert recognized["assault_rifle", "LOD0"] == 104
    assert U.matching_committed_ids(example, "b" * 40) == {}
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
        def interrupted(owner, w, lod, raw, key, **kwargs):
            calls.append((w, lod))
            if len(calls) == 3:
                kwargs["on_started"]("operations/weapon_3")
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
        assert len(checkpoint["models"]) == 3, "Pending job must survive interruption"
        assert checkpoint["models"]["knife/LOD0"]["operationPath"] == (
            "operations/weapon_3")
        assert "assetId" not in checkpoint["models"]["knife/LOD0"]

        verified = []
        uploaded = []
        def verify(asset_id, owner, key):
            verified.append(asset_id)
            return asset_id in (1001, 1002)

        def resumed(owner, weapon, lod, raw, key, **kwargs):
            uploaded.append((weapon, lod))
            if (weapon, lod) == ("knife", "LOD0"):
                assert kwargs.get("operation_path") == "operations/weapon_3", (
                    "Resume the recorded pending operation, never POST a second model")
            else:
                assert kwargs.get("operation_path") is None
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
        assert all(f"        {U.RUNTIME_NAMES[w]} = {{ LOD0 =" in contents
                   for w in U.WEAPONS)
        assert contents.count("LOD0 =") == 5 and contents.count("LOD1 =") == 5
        assert all("operationPath" not in x for x in json.loads(
            (root / "checkpoint.json").read_text())["models"].values())

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
          "pending moderation, resumable operations, and 10-asset commit OK")


if __name__ == "__main__":
    main()
