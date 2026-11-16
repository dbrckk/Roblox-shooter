"""Run read-only inspection-station checks on the exact v75 Roblox place."""
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.request

HOST = "https://apis.roblox.com"
VERSION_PATH = "cloud/v2/universes/10775909016/places/99189039770065/versions/71"
SCRIPT = Path(__file__).with_name("inspection-station-v75.luau")


def request(path, key, payload=None):
    query = urllib.request.Request(
        f"{HOST}/{path}",
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"x-api-key": key, "Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(query, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        try:
            reason = json.load(error)
            print(f"Roblox HTTP {error.code}: {reason.get('code', '')} {reason.get('message', '')}")
        except (AttributeError, ValueError):
            print(f"Roblox HTTP {error.code}")
        raise SystemExit(1) from None


def main():
    key = os.environ.get("ROBLOX_OPEN_CLOUD_QA_KEY", "").strip()
    if not key:
        raise SystemExit("Configure the GitHub Actions secret ROBLOX_OPEN_CLOUD_QA_KEY for Luau execution on IRON YARD.")
    task = request(f"{VERSION_PATH}/luau-execution-session-tasks", key, {"script": SCRIPT.read_text()})
    path = task["path"].lstrip("/")
    if not path.startswith("cloud/"):
        path = "cloud/v2/" + path
    pattern = VERSION_PATH + r"/luau-execution-sessions/[A-Za-z0-9_-]+/tasks/[A-Za-z0-9_-]+"
    if not re.fullmatch(pattern, path):
        raise SystemExit("Unexpected task path for the pinned Roblox version")
    deadline = time.monotonic() + 315
    while task.get("state") in ("QUEUED", "PENDING", "PROCESSING") and time.monotonic() < deadline:
        time.sleep(5)
        task = request(path, key)

    logs = request(f"{path}/logs", key)
    log_output = json.dumps(logs, ensure_ascii=False)
    print(f"Luau task state: {task.get('state', 'UNKNOWN')}")
    print(log_output)
    if task.get("state") != "COMPLETE" or "IRON YARD v75 engine OK:" not in log_output:
        raise SystemExit("The v75 engine checks did not produce all required evidence")


if __name__ == "__main__":
    main()
