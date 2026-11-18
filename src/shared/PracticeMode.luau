-- A single replicated generation identifies both the mode and the session.
local PracticeMode = {}
PracticeMode.ATTRIBUTE = "IronYardRangeSession"

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

return PracticeMode
