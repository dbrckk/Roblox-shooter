-- Server-only completion gate for the delayed mantle displacement.
-- Both contexts are derived from authoritative server state, never from
-- client-submitted Instance references, phase, epoch or generation token.
local MantleCommitPolicy = {}

function MantleCommitPolicy.canFinish(request, current)
    if type(request) ~= "table" or type(current) ~= "table" then return false end
    return type(request.token) == "number" and request.token >= 1
        and request.token == current.token
        and request.character ~= nil and request.character == current.character
        and request.root ~= nil and request.root == current.root
        and type(request.epoch) == "number" and request.epoch == current.epoch
        and request.phase == "LIVE" and current.phase == "LIVE"
        and current.anchored == false
end

return MantleCommitPolicy
