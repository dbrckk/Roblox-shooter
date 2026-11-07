local Plan = require("../src/shared/BotDeathPlan")

local neutral = Plan.sequence(0, 0, 1)
assert(#neutral == 3, "Elimination has exactly three authored stages")
local elapsed = Plan.duration(neutral)
assert(elapsed > 0.85 and elapsed < 1.3,
    "Stagger, fall and settle complete before the 2.5 s despawn")
assert(neutral[1].drop > neutral[2].drop
    and neutral[2].drop > neutral[3].drop,
    "Each phase moves the upper body closer to the floor")
assert(neutral[1].pitch > neutral[2].pitch
    and neutral[2].pitch > neutral[3].pitch,
    "The rig folds in stages rather than freezing at the initial flinch")
local right = Plan.sequence(1, 0.3, 2)
local left = Plan.sequence(-1, 0.3, 2)
assert(right[2].roll > 0 and left[2].roll < 0,
    "Incoming verified hit side mirrors the collapse")
assert(right[3].roll == -left[3].roll, "Settled pose retains impact direction")
local invalid = Plan.sequence(0/0, math.huge, 2)
for _, stage in ipairs(invalid) do
    assert(stage.pitch == stage.pitch and math.abs(stage.roll) < 0.4,
        "Invalid direction must fail closed to a bounded cosmetic pose")
end
assert(Plan.duration({{ duration = -1 }}) == 0, "Bad stage timing rejected")
assert(Plan.duration({{ duration = 0/0 }}) == 0, "Nonfinite stage timing rejected")
local eco = Plan.dustBudget("ECO", true, 35)
assert(eco and eco.fragments == 1, "ECO gets one short-lived local dust puff")
local mobile = Plan.dustBudget("BALANCED", true, 70)
assert(mobile and mobile.fragments == 2, "Balanced mobile draws at most two puffs")
local high = Plan.dustBudget("QUALITY", true, 100)
assert(high and high.fragments == 3, "Quality mobile caps dust at three parts")
local desktop = Plan.dustBudget("QUALITY", false, 160)
assert(desktop and desktop.fragments == 4, "Desktop high can draw four particles")
assert(Plan.dustBudget("ECO", true, 90) == nil, "Distant ECO defeats culled")
assert(Plan.dustBudget("QUALITY", true, math.huge) == nil,
    "Invalid distance never allocates an effect")
print("IRON YARD three-stage bot elimination, safe cleanup and LOD dust: OK")
