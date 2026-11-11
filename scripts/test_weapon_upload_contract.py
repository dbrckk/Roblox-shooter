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
        "displayName": "IRON YARD pistol LOD0 Original PBR",
        "creationContext": {"creator": {"userId": "9774173158"}},
        "moderationResult": {"moderationState": "MODERATION_STATE_APPROVED"},
    }
    assert U.confirmed_asset(valid, 9774173158) == 123
    assert U.confirmed_asset(valid, 9774173158,
                             U.model_display_name("pistol", "LOD0")) == 123
    for wrong in ("IRON YARD pistol LOD1 Original PBR",
                  "IRON YARD shotgun LOD0 Original PBR", "", None):
        expect_invalid_name = dict(valid, displayName=wrong)
        try:
            U.confirmed_asset(expect_invalid_name, 9774173158,
                              U.model_display_name("pistol", "LOD0"))
        except ValueError:
            pass
        else:
            raise AssertionError("Wrong original weapon / LOD model accepted")
    for w, lod in (("Unknown", "LOD0"), ("pistol", "LOD2")):
        try:
            U.model_display_name(w, lod)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid authored weapon / LOD accepted")
    for edited in (
        {"assetId": "0"},
        {"assetId": "-1"},
        {"assetId": 1.5},
        {"assetId": True},
        {"assetId": "1.5"},
        {"assetId": "1e5"},
        {"assetId": " 123"},
        {"assetId": "999999999999999999999999999999"},
        {"assetType": "ASSET_TYPE_MESH"},
        {"assetType": ""},
        {"creationContext": {"creator": {"userId": "42"}}},
        {"moderationResult": {"moderationState": "MODERATION_STATE_REJECTED"}},
        {"moderationResult": {"moderationState": "MODERATION_STATE_PENDING"}},
        {"moderationResult": {}},
    ):
        expect_invalid(dict(valid, **edited))
    expect_invalid(None)
    runtime = (Path(__file__).resolve().parents[1] / "src/shared/WeaponAssetPolicy.luau").read_text()
    assert set(U.RUNTIME_NAMES) == set(U.WEAPONS)
    for game_name in U.RUNTIME_NAMES.values():
        assert '"' + game_name + '"' in runtime, (
            "Generated upload registry must match game's exact weapon IDs")

    recorded_paths = []
    def upload_request(url, key, *, payload=None, content_type=None):
        if payload is not None:
            assert url == U.API + "/assets"
            assert b'IRON YARD pistol LOD0 Original PBR' in payload
            assert content_type.startswith("multipart/form-data; boundary=IY-")
            assert b'Content-Disposition: form-data; name="request"' in payload
            assert b'Content-Disposition: form-data; name="fileContent"' in payload
            assert b"Content-Type: model/gltf-binary" in payload
            assert b"\r\n" in payload
            assert b"GLB-BYTES-FROM-VALIDATED-FORGE" in payload
            return {"path": "operations/upload_123", "done": False}
        assert url == U.API + "/operations/upload_123"
        assert recorded_paths == ["operations/upload_123"], (
            "Checkpoint callback must run before first network poll")
        return {"path": "operations/upload_123", "done": True, "response": valid}

    with mock.patch.object(U, "request_json", side_effect=upload_request), \
            mock.patch.object(U.time, "sleep", return_value=None):
        assert U.upload_model(9774173158, "pistol", "LOD0",
                              b"GLB-BYTES-FROM-VALIDATED-FORGE", "fake",
                              on_started=recorded_paths.append) == 123
    assert recorded_paths == ["operations/upload_123"]
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

    # A resumed, previously POSTed operation must be checked for the
    # SAME exact weapon/LOD before the uploader trusts it as completed.
    wrong_lod = dict(valid, displayName="IRON YARD pistol LOD1 Original PBR")
    with mock.patch.object(U, "request_json", return_value={
            "path": "operations/already_started", "done": True,
            "response": wrong_lod}) as get:
        try:
            U.upload_model(9774173158, "pistol", "LOD0", b"VALID-GLB", "fake",
                           operation_path="operations/already_started")
        except ValueError as exc:
            assert "authored weapon/LOD" in str(exc)
        else:
            raise AssertionError("Wrong-LOD completed operation accepted")
        get.assert_called_once_with(U.API + "/operations/already_started", "fake")

    # A GET asset response may incorrectly point at a different ID,
    # even when owner and displayName look valid. Never consider it proven.
    with mock.patch.object(U, "request_json", return_value=dict(
            valid, assetId="456")) as get:
        try:
            U.verify_existing(123, 9774173158, "fake", "pistol", "LOD0")
        except ValueError as exc:
            assert "different asset ID" in str(exc)
        else:
            raise AssertionError("Mismatched remote asset ID accepted")
        get.assert_called_once_with(U.API + "/assets/123", "fake")

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
        def verify(asset_id, owner, key, weapon, lod):
            verified.append((asset_id, weapon, lod))
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
        assert verified == [(1001, "pistol", "LOD0"),
                            (1002, "pistol", "LOD1")]
        contents = module.read_text()
        assert "LOD0 = 1001" in contents and "LOD1 = 1002" in contents
        assert "LOD1 = 2008" in contents and "ownerUserId = 9774173158" in contents
        assert all(f"        {U.RUNTIME_NAMES[w]} = {{ LOD0 =" in contents
                   for w in U.WEAPONS)
        assert contents.count("LOD0 =") == 5 and contents.count("LOD1 =") == 5
        assert all("operationPath" not in x for x in json.loads(
            (root / "checkpoint.json").read_text())["models"].values())

        # An ID already saved to a checkpoint can point to a different
        # Model owned by the same user. The uploader must fail closed;
        # a silent replacement would duplicate assets and corrupt inventory.
        module.write_text(original, "utf-8")
        first_entry = fake_entries()["pistol", "LOD0"]
        (root / "checkpoint.json").write_text(json.dumps({
            "ownerUserId": 9774173158,
            "sourceCommit": "a" * 40,
            "models": {"pistol/LOD0": {
                "sha256": first_entry["sha256"], "assetId": 123}},
        }))
        wrong_model = dict(valid, displayName="IRON YARD shotgun LOD0 Original PBR")
        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_ASSETS_KEY": "fake-key"}), \
                mock.patch.object(U, "sources", return_value=fake_entries()), \
                mock.patch.object(U, "request_json", return_value=wrong_model) as get, \
                mock.patch.object(U, "upload_model",
                                  side_effect=AssertionError("Must not POST a duplicate")):
            try:
                U.main(flags(root, publish=True))
            except ValueError as exc:
                assert "authored weapon/LOD" in str(exc)
            else:
                raise AssertionError("Wrong approved owned Model was accepted")
            get.assert_called_once_with(U.API + "/assets/123", "fake-key")
        assert module.read_text() == original, "Untrusted cache altered live IDs"

        # The same invariant applies to asset IDs committed in a previously
        # activated version. Even a transient verification mismatch should
        # halt the release instead of creating replacement Roblox models.
        module.write_text(example, "utf-8")
        (root / "checkpoint.json").unlink(missing_ok=True)
        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_ASSETS_KEY": "fake-key"}), \
                mock.patch.object(U, "sources", return_value=fake_entries()), \
                mock.patch.object(U, "request_json",
                                  return_value=dict(wrong_model, assetId="100")) as get, \
                mock.patch.object(U, "upload_model",
                                  side_effect=AssertionError("No duplicate upload allowed")):
            try:
                U.main(flags(root, publish=True))
            except ValueError as exc:
                assert "authored weapon/LOD" in str(exc)
            else:
                raise AssertionError("Wrong committed Model was accepted")
            get.assert_called_once_with(U.API + "/assets/100", "fake-key")
        assert module.read_text() == example, "Bad saved ID rewrote live registry"

        # Ten distinct source GLBs must map to ten DISTINCT Roblox Model IDs.
        # A malformed provider response cannot alias two weapons and be pushed.
        module.write_text(original, "utf-8")
        (root / "checkpoint.json").unlink(missing_ok=True)
        with mock.patch.dict(os.environ, {"ROBLOX_OPEN_CLOUD_ASSETS_KEY": "fake-key"}), \
                mock.patch.object(U, "sources", return_value=fake_entries()), \
                mock.patch.object(U, "upload_model", return_value=9999):
            try:
                U.main(flags(root, publish=True))
            except ValueError as exc:
                assert "same Roblox asset ID" in str(exc)
            else:
                raise AssertionError("Duplicated Roblox IDs reached live registry")
        assert module.read_text() == original

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
