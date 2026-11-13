#!/usr/bin/env python3
"""Realistic offline Roblox moderation state and ID recovery regressions."""
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import asset_moderation as moderation
import upload_vanguard_models as models
import upload_world_pbr_images as images

OWNER = 9774173158
ASSET_ID = 9000123456

def asset(state, *, owner=OWNER, asset_id=ASSET_ID):
    return {"assetId": str(asset_id), "creationContext": {"creator": {"userId": str(owner)}},
            "moderationResult": {"moderationState": state}}

for spelling in ("Approved", "MODERATION_STATE_APPROVED", "approved"):
    assert moderation.verify_asset(asset(spelling), ASSET_ID, OWNER) == "APPROVED"
for spelling in ("Reviewing", "MODERATION_STATE_REVIEWING"):
    assert moderation.verify_asset(asset(spelling), ASSET_ID, OWNER) == "REVIEWING"
for spelling in ("Rejected", "MODERATION_STATE_REJECTED"):
    assert moderation.verify_asset(asset(spelling), ASSET_ID, OWNER) == "REJECTED"
assert moderation.state_of(asset(None)) == "UNKNOWN"

for tampered in (asset("Approved", owner=42), asset("Approved", asset_id=34),
                 {"assetId": None}):
    try:
        moderation.verify_asset(tampered, ASSET_ID, OWNER)
    except ValueError:
        pass
    else:
        raise AssertionError("Untrusted ID or owner was accepted")

responses = iter([asset("Reviewing"), asset("MODERATION_STATE_APPROVED")])
calls = []
def request(url, key):
    calls.append(("GET", url))
    return next(responses)
moderation.await_approval("https://apis.roblox.com/assets/v1", ASSET_ID,
    OWNER, "hidden", request, polls=3, interval=0, sleep=lambda _: None)
assert len(calls) == 2 and all(x[0] == "GET" for x in calls), (
    "Reviewing assets must be retrieved, not uploaded again")
try:
    moderation.await_approval("url", ASSET_ID, OWNER, "hidden",
        lambda *_: asset("Reviewing"), polls=2, interval=0, sleep=lambda _: None)
except TimeoutError as exc:
    assert "checkpoint preserved" in str(exc)
else:
    raise AssertionError("Pending moderation was falsely activated")
try:
    moderation.await_approval("url", ASSET_ID, OWNER, "hidden",
        lambda *_: asset("Rejected"), polls=1)
except RuntimeError:
    pass
else:
    raise AssertionError("Roblox moderation rejection was not blocked")

# Verify BOTH upload transports accept Roblox's actual short status spelling.
original_model_request = models.request_json
original_world_request = images.request_json
try:
    response = {"path": "operations/test", "done": True,
                "response": asset("Approved")}
    models.request_json = lambda *a, **kw: response
    images.request_json = lambda *a, **kw: response
    id1, state1 = models.upload_one(OWNER, "olive", b"fake offline fixture", "hidden")
    id2, state2 = images.upload_one("hidden", OWNER, "freight_steel",
                                    "NormalMap", b"fixture")
    assert (id1, state1) == (ASSET_ID, "APPROVED")
    assert (id2, state2) == (ASSET_ID, "APPROVED")
finally:
    models.request_json = original_model_request
    images.request_json = original_world_request

for wf, checkpoint in (
    ("upload-vanguard-opencloud.yml", "vanguard-upload-checkpoint"),
    ("upload-world-pbr-opencloud.yml", "world-pbr-upload-checkpoint")):
    source = (ROOT / ".github/workflows" / wf).read_text()
    assert "resume_run_id:" in source and checkpoint in source
    assert 'GH_TOKEN: ${{ github.token }}' in source
    assert "gh run download" in source and "ownership will be rechecked" in source

for uploader in ("upload_vanguard_models.py", "upload_world_pbr_images.py"):
    content = (ROOT / "scripts" / uploader).read_text()
    assert "checkpoint()" in content and "await_approval(" in content
    assert 'moderation"] == "APPROVED"' in content or "get(\"moderation\") == \"APPROVED\"" in content

print("IRON YARD Open Cloud Approved/Reviewing/Rejected and checkpoint recovery: OK")
