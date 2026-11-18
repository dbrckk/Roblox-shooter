local Guide = require("../src/shared/FirstMatchGuide")
assert(Guide.objective(15) == "FIRST TO 15 ELIMINATIONS")
assert(Guide.objective(20) == "FIRST TO 20 ELIMINATIONS")
assert(Guide.objective(nil) == "FIRST TO 15 ELIMINATIONS")
assert(Guide.objective(0) == "FIRST TO 1 ELIMINATIONS")
assert(Guide.objective(999) == "FIRST TO 100 ELIMINATIONS")

local completed, shown = {}, {}
assert(Guide.nextAction(completed, shown) == "FIRE")
shown.FIRE = true
assert(Guide.nextAction(completed, shown) == nil, "Idle players are shown each cue once")
completed.FIRE = true
assert(Guide.nextAction(completed, shown) == "RELOAD")
assert(Guide.nextAction({ FIRE = true, RELOAD = true }, {}) == "DUEL",
    "Skip reload guidance when the server already confirmed it")
shown.RELOAD = true
assert(Guide.nextAction(completed, shown) == "DUEL", "Duel is discoverable without mandatory reload")
completed.DUEL = true
assert(Guide.nextAction(completed, shown) == nil, "Opening the duel menu completes its guidance")

local expected = {
    keyboard = { FIRE = "LEFT CLICK TO FIRE", RELOAD = "PRESS R", DUEL = "PRESS V FOR 1V1" },
    touch = { FIRE = "TAP FIRE TO SHOOT", RELOAD = "TAP RLD", DUEL = "TAP 1V1" },
    gamepad = { FIRE = "PRESS RT TO FIRE", RELOAD = "PRESS X", DUEL = "PRESS RIGHT STICK [R3]" },
}
for device, actions in pairs(expected) do
    for action, binding in pairs(actions) do
        local heading, control = Guide.prompt(action, device)
        assert(type(heading) == "string" and #heading > 0)
        assert(control == binding, device .. " " .. action .. " must show its actual binding")
    end
end
print("IRON YARD first-match guidance: objective, progression and three device bindings passed")
