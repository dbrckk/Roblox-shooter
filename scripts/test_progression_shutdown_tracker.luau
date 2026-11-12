-- Executable shutdown overlap regression. Tests the exact pure counter used
-- by ProgressionService when Roblox invokes overlapping lifecycle callbacks.
local T = require("../src/server/ProgressionShutdownTracker")
local state = T.new()
assert(state.count == 0 and not T.hasPending(state))
assert(not pcall(T.finish, state), "No operation can complete twice")

-- A pending acquire and PlayerRemoving overlap.
T.begin(state) -- the acquisition UpdateAsync is still in flight
T.begin(state) -- PlayerRemoving waits for acquire and releases its own record
assert(state.count == 2 and T.hasPending(state))

-- The departing player is unlinked, but the acquisition subsequently obtains
-- a lease. The late release MUST be registered before finishing acquire.
T.begin(state) -- detached late release, scheduled before completing acquire
T.finish(state) -- acquire ends
T.finish(state) -- PlayerRemoving returns and unlinks records[player]
assert(state.count == 1 and T.hasPending(state),
    "BindToClose must not stop while detached final save remains pending")

-- A second online player autosaves and receives BindToClose simultaneously.
T.begin(state) -- second player's original autosave
T.begin(state) -- shutdown final save waits for autosave
assert(state.count == 3)
T.finish(state)
assert(T.hasPending(state))
T.finish(state)
assert(T.hasPending(state))
T.finish(state) -- detached release finally finishes
assert(state.count == 0 and not T.hasPending(state))
assert(not pcall(T.finish, state),
    "A double-completion must not silently hide pending operations")
T.begin(state)
T.finish(state)
assert(not T.hasPending(state),
    "Tracker can be reused without leaking slots after clean shutdown")
print("IRON YARD: detached late DataStore release keeps BindToClose waiting OK")
