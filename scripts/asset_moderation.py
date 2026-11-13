#!/usr/bin/env python3
"""Strict Roblox Open Cloud owner/moderation parsing and pending-asset recovery.

Asset creation and approval are separate states. An API response with an
assigned assetId does NOT imply a usable image/model. All API keys stay in the
request transport; logs contain statuses and IDs only.
"""
import re
import time


def state_of(asset):
    result = asset.get("moderationResult") if isinstance(asset, dict) else None
    raw = result.get("moderationState") if isinstance(result, dict) else None
    token = re.sub(r"[^A-Z]", "", str(raw).upper())
    if token.startswith("MODERATIONSTATE"):
        token = token[len("MODERATIONSTATE"):]
    return token if token in ("APPROVED", "REVIEWING", "REJECTED") else "UNKNOWN"


def verify_asset(asset, asset_id, owner):
    if not isinstance(asset, dict):
        raise ValueError("Open Cloud returned invalid asset metadata")
    try:
        received_id = int(asset.get("assetId", 0))
    except (ValueError, TypeError):
        raise ValueError("Open Cloud returned an invalid asset ID") from None
    if received_id != asset_id or received_id <= 0:
        raise ValueError("Open Cloud returned an unexpected asset ID")
    creator = (asset.get("creationContext") or {}).get("creator") or {}
    if str(creator.get("userId")) != str(owner):
        raise ValueError("Roblox asset creator differs from the confirmed owner")
    return state_of(asset)


def await_approval(base_url, asset_id, owner, key, request_json,
                   *, polls=18, interval=8, sleep=time.sleep):
    """GET the existing asset: NEVER POST again just because it is Reviewing."""
    for attempt in range(polls):
        record = request_json(base_url + "/assets/" + str(asset_id), key)
        state = verify_asset(record, asset_id, owner)
        if state == "APPROVED":
            return
        if state == "REJECTED":
            raise RuntimeError(f"Roblox rejected asset {asset_id}; upload not activated")
        if state != "REVIEWING":
            raise RuntimeError(f"Roblox moderation state unknown for asset {asset_id}; "
                               "checkpoint preserved")
        if attempt + 1 < polls:
            sleep(interval)
    raise TimeoutError(f"Roblox asset {asset_id} still Reviewing; "
                       "checkpoint preserved, do not reupload")
