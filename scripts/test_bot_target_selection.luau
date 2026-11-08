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
-- The third returned value is the *exact* head/torso point that passed
-- the already performed LOS ray for this selected candidate.
-- Hidden memory may never provide a point that allows firing.
local selected, lastSeen, aim = choose({
    {model="A", distance=30, visible=true, position="A-root",
        aimPoint="A-head"},
    {model="B", distance=50, visible=true, position="B-root",
        aimPoint="B-torso"},
}, nil, 40, 0)
assert(selected == "A" and lastSeen == "A-root" and aim == "A-head",
    "Selection pairs the same fighter with their own ray-verified head aim")
selected, lastSeen, aim = choose({
    {model="A", distance=40, visible=true, position="A-root",
        aimPoint="A-torso"},
    {model="B", distance=33, visible=true, position="B-root",
        aimPoint="B-head"},
}, "A", 40.3, 40.0, 40.0)
assert(selected == "A" and lastSeen == "A-root" and aim == "A-torso",
    "Target commitment must also return incumbent's own verified body point")
selected, lastSeen, aim = choose({
    {model="A", distance=90, visible=true, position="A-root",
        aimPoint="A-head"},
    {model="B", distance=18, visible=true, position="B-root",
        aimPoint="B-torso", threatMatch=true},
}, "A", 40.3, 40.0, 40.0)
assert(selected == "B" and lastSeen == "B-root" and aim == "B-torso",
    "Urgent switch must not keep previous target's gun aim coordinate")
selected, lastSeen, aim = choose({
    {model="A", distance=0.1, memoryDistance=15, visible=false,
        position="A-live-should-not-leak", aimPoint="A-hidden-head"},
}, "A", 40.3, 40.0, 40.0)
assert(selected == "A" and lastSeen == nil and aim == nil,
    "Recent memory cannot grant hidden head/torso aim coordinates")
selected, lastSeen, aim = choose({
    {model="A", distance=28, visible=true, position="A-root",
        aimPoint=nil},
}, nil, 40, 0)
assert(selected == "A" and lastSeen == "A-root" and aim == nil,
    "Missing verified aim never becomes a guessed firing coordinate")
print("IRON YARD LOS, target commitment, switch urgency, and fair memory: OK")
