-- The replicated generation identifies both the mode and the session.
local PracticeMode = {}
PracticeMode.ATTRIBUTE = "IronYardRangeSession"
PracticeMode.STATS_ATTRIBUTE = "IronYardRangeStats"

function PracticeMode.session(player)
    return player:GetAttribute(PracticeMode.ATTRIBUTE) or 0
end

function PracticeMode.active(player)
    return PracticeMode.session(player) % 2 == 1
end

function PracticeMode.matches(player, session)
    local current = PracticeMode.session(player)
    return session == current or (session == nil and current == 0)
end

function PracticeMode.stats(player)
    local snapshot = player:GetAttribute(PracticeMode.STATS_ATTRIBUTE)
    if type(snapshot) == "string" then
        local session, shots, hits, targets, revision = snapshot:match("^(%d+):(%d+):(%d+):(%d+):(%d+)$")
        if tonumber(session) == PracticeMode.session(player) then
            return tonumber(shots), tonumber(hits), tonumber(targets), tonumber(revision)
        end
    end
    return 0, 0, 0
end

return PracticeMode
