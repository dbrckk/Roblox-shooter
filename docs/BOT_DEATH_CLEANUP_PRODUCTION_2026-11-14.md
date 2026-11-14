# IRON YARD — production bot death cleanup ordering (14 November 2026)

## Confirmed code fault
In the previous public build, `humanoid.Died` called
`BotNavigation.invalidate(bot)` and `BotDeathAnimation.play(bot)` *before*
scheduling the real `task.delay(config.DespawnAfterDeath, ...)` slot cleanup.
If either function raised a runtime exception, the listener terminated before
registering cleanup. The dead bot remained in `slots[slot]` indefinitely and
`reconcile()` would not replace it, even though `NeonBotCount` excluded dead
humanoids. This is an error-path bug established by the code, **not an observed
Android incident**.

## Production correction
1. On real `Humanoid.Died`, schedule the existing **2.5-second** cleanup
   first. A guard `slots[slot] ~= bot` prevents a delayed callback from
   destroying a newer replacement bot in the same slot.
2. Invalidate obsolete paths with `pcall`, so a failure does not prevent
   deactivation of the corpse's collision and ray-query geometry.
3. Keep the same animated three-stage death, but guard it with `pcall` and
   record a throttled server warning on failure; gameplay cleanup is
   already scheduled.
4. Keep original combat scores, hitboxes while alive, hit attribution,
   kill counts, spawn safety, death delays, network messages and VFX.
5. Extend CI source checks for guaranteed cleanup ordering and
   protection of all old/new slot identities.

## Runtime acceptance
- Kill all four bots repeatedly during FFA and verify a 2.5-second corpse
  window and restored AI count without ghost actors.
- During 1v1 setup/end, verify that no delayed cleanup can erase a bot
  from another round, and that no bot is spawned in active duel mode.
- Ensure hits pass through dead bodies, rewards occur only once for each
  legitimate elimination and gameplay continues on Android.

A green Luau/Rojo CI verifies code and contracts; it does not execute
Roblox Humanoid death events, streaming or physical player sessions.
