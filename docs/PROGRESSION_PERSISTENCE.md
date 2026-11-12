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

## Victory experience

A non-tied FFA win by an actual human Player awards **250 XP and one lifetime victory**, in addition to elimination XP. The match service sends exactly one server-controlled victory event before transitioning to RESULTS; the player's round/session XP counter and medal notification are updated alongside the persistent totals. A bot winner, draw or duplicated display name cannot award this bonus by matching text.

## Executable transaction tests (October 2026)

The DataStore merge and lease rules were moved to the dependency-free
`src/server/ProgressionLedger.luau`. It is called **inside both real
UpdateAsync callbacks**, not merely reimplemented in a test mock. CI runs
`scripts/test_progression_ledger.luau` with the official Luau interpreter
and exercises first-time records, exact-once replays, reconnect after release,
out-of-order saves, stale writers, lock expiry, corrupted schemas and
nonnegative XP limits. This verifies the state-machine calculations; it is
**not** a substitute for published Roblox DataStore throttling tests.

## Recovery when an acquisition completes after departure (9 November 2026)

A slow `UpdateAsync` may acquire a lock **after** `PlayerRemoving` has exhausted its bounded wait and detached the Player record. The acquisition completion now schedules a final, GUID-owned `Ledger.commit(..., release=true)` using the Player's original UserId and the XP earned before departure. It is best-effort: an interrupted server or a continuing DataStore outage can still delay recovery until lease expiry. No live player key is used from Studio.

A successful release may be retried after another server has already acquired the key. `Ledger.commit` now acknowledges the old session only if `lastSession.owner` and all committed counters prove it was fully persisted; it does **not** modify the newer server's lock or grant extra XP. The pure Luau regression covers both a valid acknowledgement and rejection of missing earnings.

**Still required:** reproduce a delayed acquisition, leave/rejoin, throttling and server shutdown in a private published Roblox test universe. GitHub CI cannot prove real DataStore timing or the durability of a live session.

## Visible save confirmation (9 November 2026)

The server now publishes `IronYardSavedXP`, based only on the loaded persistent baseline and the last successfully acknowledged local `UpdateAsync` snapshot. `IronYardLifetimeXP` continues to show earned XP immediately. While the two differ, the career HUD explicitly displays **SAVE PENDING**, including a compact indicator during live mobile play; after a successful save it displays **SAVED**. LOADING, LOCKED, STUDIO and RETRYING states still warn independently. This is confirmation of a completed DataStore request, **not** a guarantee against every eventual Roblox outage or platform failure.

When the player earns more XP during an in-flight save, only the snapshotted amount becomes confirmed; the newer XP remains pending. Failed writes never advance the confirmed counter. This state is ephemeral and does not change DataStore schema v1, player keys or reward amounts.


## Match results show durable save state (9 November 2026)

Before this change the RESULTS podium displayed lifetime XP while hiding the in-game career panel, leaving players unable to distinguish pending from saved XP. The results screen and active career HUD now share the standalone, CI-tested `src/shared/CareerReadout.luau` presentation policy. `CAREER / SAVED` appears only if the server reports ONLINE and confirmed `IronYardSavedXP` equals live `IronYardLifetimeXP`. Pending XP is the difference, not all earned XP. Replication may deliver attributes in either order; when saved totals temporarily exceed received totals, the UI says SYNCING and never indicates a confirmed save.

The results screen refreshes on live save-status and saved-XP attribute changes and now shows XP **remaining** to the next rank. Studio and DataStore failures remain visibly unconfirmed. DataStore v1 keys, awards, authoritative server logic and gameplay are unchanged.


## Refus des confirmations de sauvegarde incohérentes (12 novembre 2026)

Avant d'accepter un verrou de session actif (`lock.committed`) ou une attestation
de session libérée (`lastSession.committed`), le registre serveur vérifie
désormais **pour chacun des quatre compteurs** que la valeur annoncée comme
déjà persistée ne dépasse pas le total durable réellement enregistré.
Cette cohérence était déjà vérifiée lors de certains calculs de base de
session, mais pas lors de toutes les transactions, notamment les retries
de libération après reconnexion. Sans elle, un enregistrement corrompu
pourrait confirmer une progression qui n'existe pas réellement.

Les enregistrements incohérents provoquent une erreur du callback
`UpdateAsync` : **aucune réécriture ni remise à zéro automatique**.
Le serveur conserve la progression acquise en mémoire et affiche un état
de synchronisation non confirmé plutôt qu'un faux `SAVED`. Les tests
exécutables Luau couvrent les quatre champs sur verrous actifs,
ré-acquisitions, autosaves, libérations et reprises de session, ainsi
que le fonctionnement des enregistrements valides. Le schéma v1, les
clés DataStore, les récompenses et la durée des verrous restent inchangés.

**Limite :** la CI vérifie ces règles dans le registre réellement appelé
par les callbacks, mais ne simule pas l'infrastructure DataStore Roblox ;
un contrôle de persistance et de reconnexion dans une expérience Roblox
autorisée reste nécessaire.
