#!/usr/bin/env python3
"""Offline tests: recover only complete original, approved checkpoints."""
from copy import deepcopy
from verify_world_pbr_checkpoint import verify, OWNER, SOURCE, MATERIALS, CHANNELS

files = {mat: {ch: {"sha256": "a"*64, "bytes": 100 + i}
               for i, ch in enumerate(CHANNELS)} for mat in MATERIALS}
manifest = {"resolution": [1024, 1024], "sets": list(MATERIALS),
            "channels": list(CHANNELS), "files": files}
seq = iter(range(99001, 99013))
saved = {"ownerUserId": OWNER, "sourceCommit": SOURCE,
         "assets": {mat: {ch: {**files[mat][ch], "assetId": next(seq),
                                "moderation": "APPROVED"}
                           for ch in CHANNELS} for mat in MATERIALS}}
assert verify(saved, manifest)
for field, wrong in (("ownerUserId", 33), ("sourceCommit", "f"*40)):
    bad = deepcopy(saved)
    bad[field] = wrong
    try: verify(bad, manifest)
    except ValueError: pass
    else: raise AssertionError("Accepted unexpected " + field)
for field, wrong in (("sha256", "b"*64), ("bytes", 0),
                     ("assetId", 0), ("assetId", True),
                     ("moderation", "REVIEWING")):
    bad = deepcopy(saved)
    bad["assets"]["freight_steel"]["ColorMap"][field] = wrong
    try: verify(bad, manifest)
    except ValueError: pass
    else: raise AssertionError("Accepted corrupt checkpoint " + field)
bad = deepcopy(saved)
bad["assets"]["freight_steel"]["ColorMap"]["assetId"] = (
    bad["assets"]["freight_steel"]["NormalMap"]["assetId"])
try: verify(bad, manifest)
except ValueError: pass
else: raise AssertionError("Accepted duplicate Image asset ID")
print("IRON YARD original world PBR checkpoint: safe and atomic")
