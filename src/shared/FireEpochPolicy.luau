-- IRON YARD / pure match-generation guard for server-authoritative shots.
-- A RemoteEvent dispatched during a prior LIVE phase must not spend a fresh
-- magazine or damage an opponent after a new FFA round or 1v1 bout begins.
local Policy = {}
local MAX_INTEGER = 9007199254740991

function Policy.valid(epoch)
    return type(epoch) == "number" and epoch == epoch
        and epoch >= 0 and epoch < MAX_INTEGER
        and epoch % 1 == 0
end

function Policy.matches(received, current)
    return Policy.valid(received) and Policy.valid(current)
        and current > 0 and received == current
end

-- Ammo replies have their own version, so an old reply cannot overwrite
-- a newer-round magazine after attributes/remotes replicate out of order.
-- Zero is valid only for initial lobby snapshots, never for a LIVE shot.
function Policy.acceptAmmo(received, worldEpoch, latestAmmoEpoch)
    if not Policy.valid(received) then return false end
    local minimum = 0
    if Policy.valid(worldEpoch) then minimum = math.max(minimum, worldEpoch) end
    if Policy.valid(latestAmmoEpoch) then
        minimum = math.max(minimum, latestAmmoEpoch)
    end
    return received >= minimum
end

return Policy
