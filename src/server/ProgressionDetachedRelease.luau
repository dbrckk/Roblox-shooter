-- Pure per-record single-flight guard for late DataStore release.
-- A departed Player can be observed by PlayerRemoving and a late acquire
-- concurrently. Only ONE detached release may be scheduled for that record.
local Detached = {}

function Detached.claim(record)
    if type(record) ~= "table" or record.detachedReleaseQueued == true then
        return false
    end
    record.detachedReleaseQueued = true
    return true
end

return Detached
