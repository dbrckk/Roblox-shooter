# IRON YARD — reliable persistent progression

## What is actually implemented

`src/server/ProgressionService.luau` is an **authoritative server-side DataStore** adapter. It records durable XP, eliminations, headshots, and FFA round victories by **immutable Roblox UserId**, not display name. The UI in `src/client/ProgressionHud.client.luau` displays a derived rank (250 × level-step squared) and the current save status. `CombatAwards` still manages per-round medals and per-session XP independently.

Each accepted human kill triggers one progression grant, **after** the authoritative weapon damage confirms a death. All eight shotgun pellets are combined into one elimination award. The player winner is identified by the original Player object, not by a possibly duplicate DisplayName. Ties and bot victories do not grant human wins.

## DataStore v1

Store name: `IronYard_Progression_v1`. Key: `player_<UserId>`. Schema 1 retains `xp`, `eliminations`, `headshots`, `victories`, `lock`, and `lastSession`. Invalid schemas or corrupt totals cause **no overwriting**, with a visible save-failure status.

- **Atomic writes:** `UpdateAsync` for initial load/lease acquisition and every save. No `SetAsync` blind overwrite. This also makes concurrent servers respect each other's in-flight work.
- **Session lease:** each server/player connection receives an unguessable GUID. An active lock lasts 180 seconds and is refreshed on 45-second autosaves. A second server cannot load and overwrite the same record while the first lock is valid. A crashed session becomes available when its lease expires.
- **Idempotent grants:** the record remembers per-session committed counters. Repeated `UpdateAsync` save callbacks, network retries and repeated shutdown release requests **add only the unsaved delta**, never award the whole session twice.
- **Autosave and shutdown:** saves run every 45 seconds; leave and `game:BindToClose` attempt a final atomic write and release. Network failures are retried three times. An unexpected process kill or a Roblox outage can still lose progress granted since the last acknowledged save; this is not a transaction guarantee.
- **Offline continuity:** if loading fails, is locked or DataStore access is unavailable, gameplay and medals continue. Counters remain in memory and loading retries periodically. The HUD never calls this state 'saved'. If the service recovers while the player remains connected, pending session XP is included in the next successful write.
- **Studio safety:** Studio sessions deliberately remain `STUDIO / SESSION ONLY` to avoid touching a live experience's real player keys. Roblox recommends testing DataStores in a **separate published test experience** rather than enabling production DataStore access in Studio.

## UI status

| Status | Meaning |
|---|---|
| ONLINE | Record loaded and lease acquired; autosave is active |
| LOADING | Waiting for Roblox DataStore |
| LOCKED | Another server holds a non-expired lock, or our lock was lost |
| RETRYING | Request failed; pending awards still exist in this server's memory |
| STUDIO | Preview only; no DataStore operations |
| UNAVAILABLE | No DataStore could be obtained; session-only until service recovers |

The `IronYardLifetime*` attributes shown during LOADING/RETRYING include unsaved session gains and are **not proof of persistence**. The interface displays a warning in these states.

## Real validation before claiming durable player data

GitHub Actions can compile Lua and check source contracts, but **cannot validate a Roblox DataStore from a GitHub runner**. The following requires a published experience with an authorized server:

1. Play, earn a headshot and 100+ XP, wait for an autosave, leave, rejoin; confirm rank, kills, headshots and XP are restored.
2. Win a round as a human, leave, rejoin; confirm exactly one win. Test tied players and a winning bot: human wins must **not** increment.
3. Simulate leaving shortly after earning XP and immediately rejoining; the new server must wait for release or lease expiry without resetting totals.
4. Re-run writes under throttling/fault injection; repeated saves must not duplicate XP. Disconnect the server without a clean shutdown and observe lease expiry and possible last-autosave loss.
5. With unavailable DataStore, verify the UI visibly warns that progress is not saved; restore service and confirm safe retry without replacing previously stored values.
6. Check live low-end Android game, medal overlay and rank HUD for overlap and performance.

Do **not** enable Studio API access on the same production experience for testing. The game is not published via GitHub Actions until the required destination IDs and Open Cloud authorization are actually set.

Documentation reference: https://create.roblox.com/docs/cloud-services/data-stores
