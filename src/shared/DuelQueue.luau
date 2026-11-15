-- The source server owns queue order and both players' consent.
local Queue = {}

function Queue.pair(entries, order, available)
    local firstSearch
    local eligible = {}
    for _, player in ipairs(order) do
        if entries[player] and available(player) then eligible[player] = true end
    end
    for _, player in ipairs(order) do
        if not eligible[player] then continue end
        local target = entries[player].target
        if target then
            if eligible[target] and entries[target].target == player then return player, target end
        elseif firstSearch then
            return firstSearch, player
        else
            firstSearch = player
        end
    end
    return nil
end

return Queue
