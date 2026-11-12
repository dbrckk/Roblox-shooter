-- IRON YARD / pure ADS + authoritative reload transition tests.
local P = require("../src/shared/WeaponAimReloadPolicy")
assert(P.canEnterAim(nil))
assert(P.canEnterAim({}))
assert(P.canEnterAim({reloading=false}))
assert(P.canEnterAim({reloading="true"}))
assert(not P.canEnterAim({reloading=true}))
assert(P.canEnterAim("unknown"))
assert(P.releaseOnConfirmedReload("Pistol", "Pistol", true, true))
assert(P.releaseOnConfirmedReload("Sniper", "Sniper", true, true))
assert(not P.releaseOnConfirmedReload("Pistol", "Pistol", false, true))
assert(not P.releaseOnConfirmedReload("Pistol", "Pistol", true, false))
assert(not P.releaseOnConfirmedReload("Pistol", "Sniper", true, true))
assert(not P.releaseOnConfirmedReload("Pistol", "Pistol", "true", true))
assert(not P.releaseOnConfirmedReload(nil, nil, true, true))
assert(not P.releaseOnConfirmedReload("", "", true, true))
local scoped, releases = true, 0
for _ = 1, 100 do
    if P.releaseOnConfirmedReload("Sniper", "Sniper", true, scoped) then
        scoped = false
        releases += 1
    end
end
assert(releases == 1, "Repeated server snapshots must not trigger ADS remote spam")
assert(not P.canEnterAim({reloading=true}) and P.canEnterAim({reloading=false}))
print("IRON YARD: confirmed reload exits ADS once; rejected reload preserves ADS OK")
