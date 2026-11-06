local S = require("../src/shared/BotTargetSelection")
local choose = S.choose
local model, pos = choose({
    {model="Far", distance=110, visible=true, position="far"},
    {model="Near", distance=25, visible=true, position="near"},
    {model="Later", distance=139, visible=true, position="later"},
}, nil, 10, 0)
assert(model == "Near" and pos == "near", "Selection must pair its own sighting")
model, pos = choose({
    {model="Old", distance=28, visible=false, position="hidden-live"},
}, "Old", 11.8, 10)
assert(model == "Old" and pos == nil, "Hidden live coordinates must never propagate")
model, pos = choose({
    {model="Old", distance=28, visible=false, position="hidden-live"},
}, "Old", 12.3, 10)
assert(model == nil and pos == nil, "Sighting expires after 2.2 seconds")
model, pos = choose({
    {model="Old", distance=20, visible=false, position="hidden"},
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
print("IRON YARD verified target memory and per-fighter sighting identity: OK")
