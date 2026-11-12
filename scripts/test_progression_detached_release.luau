-- This is the same pure guard used by ProgressionService on a
-- slow autosave timeout and on a late acquisition finishing after leave.
local D = require("../src/server/ProgressionDetachedRelease")
local T = require("../src/server/ProgressionShutdownTracker")

local first = {detachedReleaseQueued=false}
local other = {detachedReleaseQueued=false}
assert(D.claim(first), "First departing-player release is scheduled")
assert(first.detachedReleaseQueued)
for i=1,10000 do
    assert(not D.claim(first), "Two callbacks cannot queue duplicate releases")
end
assert(D.claim(other), "Another player's release is independent")
assert(not D.claim(nil))
assert(not D.claim("not a record"))

-- Simulate the tracker lifetime when PlayerRemoving times out on autosave:
-- the later worker remains pending after both existing callbacks finish.
local tracker = T.new()
T.begin(tracker) -- busy original autosave
T.begin(tracker) -- PlayerRemoving callback
T.begin(tracker) -- deferred release reserved BEFORE unlinking player
assert(T.hasPending(tracker) and tracker.count==3)
T.finish(tracker) -- PlayerRemoving unlinks records[player]
T.finish(tracker) -- slow autosave eventually returns
assert(T.hasPending(tracker) and tracker.count==1,
    "BindToClose must still wait for detached final release")
T.finish(tracker) -- final release UpdateAsync completes
assert(not T.hasPending(tracker) and tracker.count==0)

-- No repeated detached worker after the late acquire finishes as well.
assert(not D.claim(first), "Late acquire cannot enqueue a second release")
print("IRON YARD: slow autosave departure queues one tracked final release")
