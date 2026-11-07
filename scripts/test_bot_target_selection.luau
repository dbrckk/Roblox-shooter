local S = require("../src/shared/BotTargetSelection")
local choose = S.choose
local model, pos = choose({
    {model="Far", distance=110, visible=true, position="far"},
    {model="Near", distance=25, visible=true, position="near"},
    {model="Later", distance=139, visible=true, position="later"},
}, nil, 10, 0)
assert(model == "Near" and pos == "near", "Selection must pair its own sighting")
model, pos = choose({
    {model="Old", distance=1, memoryDistance=28, visible=false, position="hidden-live"},
}, "Old", 11.8, 10)
assert(model == "Old" and pos == nil, "Hidden live coordinates must never propagate")
model, pos = choose({
    {model="Old", distance=1, memoryDistance=28, visible=false, position="hidden-live"},
}, "Old", 12.3, 10)
assert(model == nil and pos == nil, "Sighting expires after 2.2 seconds")
model, pos = choose({
    {model="Old", distance=1, memoryDistance=20, visible=false, position="hidden"},
    {model="New", distance=80, visible=true, position="new"},
}, "Old", 11, 10)
assert(model == "New" and pos == "new", "Fresh visible fighter outranks hidden memory")
model, pos = choose({
    {model="A", distance=35, visible=true, position="A"},
    {model="B", distance=40, visible=true, position="B"},
}, "B", 11, 10)
assert(model == "B" and pos == "B", "Incumbent preference prevents random switching")
model, pos = choose({
    {model="Invalid", distance=0 / 0, visible=true, position="bad"},
    {model="Good", distance=40, visible=true, position="good"},
}, nil, 11, 10)
assert(model == "Good" and pos == "good", "Invalid distance rejected")
model, pos = choose({
    {model="Hidden", distance=1, visible=false, position="cheat"},
}, "Hidden", 11, 10)
assert(model == nil and pos == nil, "Hidden live distance must not be used for memory")
model, pos = choose({
    {model="Old", distance=1, memoryDistance=96, visible=false, position="hidden-live"},
}, "Old", 11, 10)
assert(model == "Old" and pos == nil, "Memory uses verified past range only")
model, pos = choose({
    {model="A", distance=22, visible=true, position="A"},
    {model="B", distance=55, visible=true, position="B", threatMatch=true},
}, "A", 11, 10)
assert(model == "B" and pos == "B", "Visible recent aggressor outranks passive incumbent")
model, pos = choose({
    {model="Hidden", distance=1, memoryDistance=45, visible=false,
        position="unverified", threatMatch=true},
    {model="Visible", distance=90, visible=true, position="seen"},
}, "Hidden", 11, 10)
assert(model == "Visible" and pos == "seen", "Threat bonus never boosts an unseen fighter")
model, pos = choose({
    {model="Invalid", distance=18, visible=true},
}, nil, 11, 10)
assert(model == nil and pos == nil, "Visible target requires a paired sighting")
model, pos = choose({
    {model="A", distance=40, visible=true, position="A"},
    {model="B", distance=30, visible=true, position="B"},
}, "A", 20.4, 20, 20)
assert(model == "A" and pos == "A", "Target commitment resists tiny duel changes")
model, pos = choose({
    {model="A", distance=110, visible=true, position="A"},
    {model="B", distance=15, visible=true, position="B"},
}, "A", 20.4, 20, 20)
assert(model == "B" and pos == "B", "Much closer visible threat breaks commitment")
model, pos = choose({
    {model="A", distance=40, visible=true, position="A"},
    {model="B", distance=15, visible=true, position="B", threatMatch=true},
}, "A", 20.4, 20, 20)
assert(model == "B" and pos == "B", "Visible confirmed aggressor breaks commitment")
model, pos = choose({
    {model="A", memoryDistance=25, visible=false, position="hidden-live"},
    {model="B", distance=60, visible=true, position="B"},
}, "A", 20.4, 20, 20)
assert(model == "B" and pos == "B", "A hidden incumbent never keeps visible foes locked out")
model, pos = choose({
    {model="A", distance=40, visible=true, position="A"},
    {model="B", distance=10, visible=true, position="B"},
}, "A", 21.6, 20, 20)
assert(model == "A" and pos == "A", "Post-commitment margin still prevents tiny fluctuations")
print("IRON YARD LOS, target commitment, switch urgency, and fair memory: OK")
