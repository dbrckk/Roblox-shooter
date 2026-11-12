local Vfx = require("../src/shared/CombatVfxProfile")

local function eq(actual, expected, description)
    assert(actual == expected, description .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
eq(Vfx.surface("DiamondPlate").sparks, true, "metal emits sparks")
eq(Vfx.surface("Wood").sparks, false, "wood makes splinters, not sparks")
eq(Vfx.surface("Glass").glimmer, true, "glass impact glints")
eq(Vfx.surface("Concrete").sparks, false, "concrete makes dust, not sparks")
eq(Vfx.surface("not-a-material").spread, 0.48, "unknown material is inert stone")
eq(Vfx.budget("ECO", true, 65).fragments, 1, "eco low particle allocation")
eq(Vfx.budget("ECO", false, 300), nil, "eco rejects distant impacts")
eq(Vfx.budget("QUALITY", true, 130).fragments, 3, "quality mobile effects")
eq(Vfx.budget("QUALITY", true, 150), nil, "mobile effects are distance culled")
eq(Vfx.budget("QUALITY", false, 185).fragments, 4, "quality desktop effects")
-- The same budgets now gate all nonlocal bot tracer/flash geometry.
-- Local predicted player tracers and server damage remain unaffected.
assert(Vfx.budget("ECO", true, 70) ~= nil
    and Vfx.budget("ECO", true, 71) == nil,
    "ECO remote bot tracers must cull past 70 studs")
assert(Vfx.budget("BALANCED", true, 115) ~= nil
    and Vfx.budget("BALANCED", true, 116) == nil,
    "Balanced Android remote bot tracers capped at 115 studs")
assert(Vfx.budget("QUALITY", true, 145) ~= nil
    and Vfx.budget("QUALITY", true, 146) == nil,
    "Quality Android remote bot tracers capped at 145 studs")
assert(Vfx.budget("BALANCED", false, 160) ~= nil
    and Vfx.budget("BALANCED", false, 161) == nil,
    "Balanced desktop remote tracer cap")

eq(Vfx.budget("QUALITY", false, 185).muzzleLight, true, "desktop optional flash light")
eq(Vfx.budget("BALANCED", true, 40).muzzleLight, false, "mobile no local pointlight")
eq(Vfx.budget("BALANCED", true, 40).marks, 16, "mobile mark cap")
eq(Vfx.budget("QUALITY", false, 40).marks, 36, "desktop mark cap")
eq(Vfx.tracer(180).length, 29, "long tracer is not a huge bar")
assert(Vfx.tracer(180).duration < Vfx.tracer(500).duration,
    "tracer travel grows with flight distance")
eq(Vfx.tracer(0), nil, "no degenerate tracer")
eq(Vfx.tracer(1500).duration, 0.15, "long tracer caps its lifetime")
-- Five materials have visibly distinct but bounded flight curves without
-- changing surface collision or creating a networked physical projectile.
local metalMotion = Vfx.fragmentMotion("CorrodedMetal")
local woodMotion = Vfx.fragmentMotion("WoodPlanks")
local glassMotion = Vfx.fragmentMotion("Glass")
local earthMotion = Vfx.fragmentMotion("Sand")
local stoneMotion = Vfx.fragmentMotion("Concrete")
assert(metalMotion.gravity < glassMotion.gravity
    and glassMotion.gravity < woodMotion.gravity
    and woodMotion.gravity < stoneMotion.gravity
    and stoneMotion.gravity < earthMotion.gravity)
assert(metalMotion.flicker > glassMotion.flicker
    and glassMotion.flicker > woodMotion.flicker)
assert(woodMotion.spin > stoneMotion.spin
    and stoneMotion.spin > metalMotion.spin)
assert(Vfx.fragmentMotion("not-a-material") == stoneMotion)
for _, material in ipairs({"Metal","Wood","Glass","Concrete","Ground"}) do
    local motion = Vfx.fragmentMotion(material)
    assert(motion.gravity >= 0 and motion.gravity <= 1)
    assert(motion.spin >= 0 and motion.spin <= 3)
    assert(motion.flicker >= 0 and motion.flicker <= 0.4)
end
local hit = Vfx.hitFeedback("BALANCED", true, 32, false, false)
assert(hit and hit.sparks == 1 and hit.duration <= 0.2)
local headHit = Vfx.hitFeedback("QUALITY", false, 50, true, false)
assert(headHit.radius > hit.radius, "Headshots are visible")
local killHit = Vfx.hitFeedback("QUALITY", false, 50, false, true)
assert(killHit.duration > hit.duration, "Eliminations remain legible")
assert(killHit.eliminationRing and not headHit.eliminationRing)
assert(Vfx.hitFeedback("ECO", true, 30, true, true).eliminationRing == false,
    "Economy mobile setting does not create extra elimination ring")
assert(Vfx.hitFeedback("BALANCED", true, 30, false, true).eliminationRing,
    "Confirmed elimination has its own phone-safe ring")
eq(Vfx.hitFeedback("ECO", true, 80, false, false), nil, "ECO range culling")
eq(Vfx.pelletVisualCount("ECO", true, 30), 1, "One ECO pellet")
eq(Vfx.pelletVisualCount("BALANCED", true, 30), 2, "Two mobile pellets")
eq(Vfx.pelletVisualCount("QUALITY", true, 30), 3, "Three high mobile pellets")
eq(Vfx.pelletVisualCount("BALANCED", true, 200), 0, "Far pellet culling")
local nearTracer = Vfx.tracer(3)
assert(nearTracer and nearTracer.length > 0.1 and nearTracer.length < 1.5,
    "Close-range tracer must move rather than fill the whole ray")
assert(Vfx.tracer(12).length < 6, "Short tracer stays compact")
eq(Vfx.tracer(180).length, 29, "Long tracer retains cap")
eq(Vfx.tracer(0/0), nil, "Reject NaN ray length")
eq(Vfx.tracer(math.huge), nil, "Reject infinite ray length")
local closeHit = Vfx.hitFeedback("BALANCED", true, 3, true, true)
assert(closeHit and closeHit.radius < killHit.radius and closeHit.sparks == 1,
    "Point-blank kills cannot overwhelm small phone screens")
assert(Vfx.shouldDisplayHit(10, 9.7, 1, 1), "Separated body shots are visible")
assert(not Vfx.shouldDisplayHit(10.04, 10, 1, 1),
    "Overlapping body pellet glints are suppressed")
assert(Vfx.shouldDisplayHit(10.04, 10, 1, 3),
    "Confirmed elimination supersedes ordinary glint cooldown")
assert(not Vfx.shouldDisplayHit(10.04, 10, 3, 2),
    "Nonfatal headshot cannot obscure recent elimination")
assert(Vfx.hitPriority(false, true) > Vfx.hitPriority(true, false),
    "Fatal confirmation has highest priority")
print("IRON YARD close-range traveling tracers, kill priority and mobile VFX: OK")



-- Reuse the *same* impact-mark pool with physically differentiated footprints.
local metal = Vfx.markStyle("Metal")
local wood = Vfx.markStyle("Wood")
local glass = Vfx.markStyle("Glass")
local dirt = Vfx.markStyle("Sand")
local stone = Vfx.markStyle("Concrete")
assert(metal.metallic and not wood.metallic and not stone.metallic)
assert(metal.widthMax < wood.widthMax and dirt.widthMax > stone.widthMax,
    "Bullet marks differentiate punctured metal, splintered wood and loose dirt")
assert(wood.aspectMin > stone.aspectMax,
    "Wood chip scars must be elongated along the impact plane")
assert(Vfx.markStyle("CorrodedMetal") == metal)
assert(Vfx.markStyle("WoodPlanks") == wood)
assert(Vfx.markStyle("not-a-material") == stone)
assert(Vfx.markStyle("Glass") == glass)
for _, material in ipairs({"Metal", "Wood", "Glass", "Sand", "Concrete"}) do
    local style = Vfx.markStyle(material)
    assert(style.widthMin > 0 and style.widthMax >= style.widthMin)
    assert(style.widthMax <= 0.4)
    assert(style.aspectMin > 0 and style.aspectMax >= style.aspectMin)
    assert(style.depth > 0 and style.depth <= 0.03)
    assert(style.surfaceOffset > style.depth / 2)
end
-- Distinct muzzle bursts for four guns, without increasing preset Part
-- budgets or replacing the original Blender PBR muzzle socket positions.
local pistol = Vfx.muzzleSignature("Pistol")
local rifle = Vfx.muzzleSignature("AssaultRifle")
local shotgun = Vfx.muzzleSignature("Shotgun")
local sniper = Vfx.muzzleSignature("Sniper")
assert(pistol.coreRadius < rifle.coreRadius and rifle.coreRadius < shotgun.coreRadius)
assert(pistol.finLength < rifle.finLength and rifle.finLength < sniper.finLength)
assert(shotgun.finWidth > rifle.finWidth and shotgun.duration > rifle.duration)
assert(sniper.finLength > shotgun.finLength)
assert(Vfx.muzzleSignature("Knife") == nil)
assert(Vfx.muzzleSignature("other") == rifle,
    "Unknown remote gun IDs use safe generic muzzle identity")
for _, id in ipairs({"Pistol", "AssaultRifle", "Shotgun", "Sniper"}) do
    local signature = Vfx.muzzleSignature(id)
    assert(#signature.tint == 3)
    assert(signature.coreRadius >= 0.1 and signature.coreRadius <= 0.4)
    assert(signature.finLength > 0 and signature.finLength < 0.9)
    assert(signature.finThickness > 0 and signature.finWidth > 0)
    assert(signature.advance >= 0.1 and signature.advance <= 0.4)
    assert(signature.duration >= 0.05 and signature.duration <= 0.1)
    assert(signature.finAlpha >= 0 and signature.finAlpha <= 0.5)
end
print("IRON YARD weapon-specific flash silhouettes and material bullet scars: OK")
