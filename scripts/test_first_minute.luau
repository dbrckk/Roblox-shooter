-- IRON YARD / deterministic first minute: journey order, HUD surfaces, touch
-- geometry. No engine, no clock, no frame-rate claim: this locks what the player
-- is shown, in which order, and where the controls land on small screens.
local Plan = require("../src/shared/HudSurfacePlan")
local Guide = require("../src/shared/FirstMatchGuide")
local Career = require("../src/shared/CareerReadout")
local Defeat = require("../src/shared/DefeatPresentation")
local Layout = require("../src/shared/TouchLayout")

local function check(ok, message)
    assert(ok, message)
end

-- 1. Journey order: evidence is required, and so is everything before it.
local reached = Plan.reached({ JOIN = true, RESULT = true })
check(reached.JOIN, "Join must be reached")
check(not reached.OBJECTIVE, "The objective needs the LIVE evidence")
check(not reached.RESULT, "A result without a death must not count")
check(Plan.missing(reached) == "OBJECTIVE", "The journey names the first missing step")

local full = {}
for _, step in ipairs(Plan.STEPS) do full[step] = true end
reached = Plan.reached(full)
for _, step in ipairs(Plan.STEPS) do
    check(reached[step], step .. " must be reached when every evidence is present")
end
check(Plan.missing(reached) == nil, "A complete first minute leaves no missing step")

-- Ordering is enforced: a client cannot announce the result at join time.
reached = Plan.reached({ JOIN = true, OBJECTIVE = true, AIM = true, RESULT = true })
check(not reached.RESULT, "The result must wait for death and respawn")
check(Plan.missing(reached) == "FIRE", "Fire is the first gap of that path")
check(not Plan.reached({})["JOIN"], "An empty journey reaches nothing")

-- 2. Objective and control copy come from the shipped guide, not from this test.
check(Guide.objective(15) == "FIRST TO 15 ELIMINATIONS", "The FFA objective is 15 eliminations")
check(Guide.objective(nil) == "FIRST TO 15 ELIMINATIONS", "The default objective stays 15")
check(Guide.hint(true, 0, 0):find("LEFT STICK", 1, true) ~= nil, "The touch hint names the stick")
check(Guide.hint(false, 1, 0):find("RELOAD", 1, true) ~= nil, "The desktop hint names the reload")
check(Guide.hint(false, 0, 0, true):find("RT FIRE", 1, true) ~= nil, "The gamepad hint names fire")

-- 3. Death, redeploy and result copy stay consistent with the phases.
local title, timer, hint = Defeat.labels("FFA", "LIVE", 0, 3, nil)
check(title == "ELIMINATED", "The FFA defeat title stays ELIMINATED")
check(timer == "REDEPLOY IN  3s", "The FFA redeploy countdown matches the remaining time")
check(hint:find("SPAWN SHIELD 2.5s", 1, true) ~= nil,
    "The defeat card states the real spawn shield")
local _, finished = Defeat.labels("FFA", "LIVE", 0, 0, nil)
check(finished == "REDEPLOYING...", "A finished countdown redeploys")
check(Defeat.labels("DUEL", "DUEL_BREAK", 4, 0, "ROUND LOST") == "ROUND LOST",
    "A duel break reports the lost bout")
check(Defeat.labels("DUEL", "DUEL_BREAK", 4, 0, "ROUND WON") == "ROUND WON",
    "A duel break reports the won bout")
check(Defeat.labels("DUEL", "DUEL_BREAK", 4, 0, "ROUND DRAW") == "ROUND DRAW",
    "A duel break reports the draw")
local duelTitle, duelTimer, duelHint = Defeat.labels("DUEL", "DUEL_PREP", 0, 0, nil)
check(duelTitle == "ELIMINATED", "The duel preparation keeps the elimination title")
check(duelTimer == "AWAITING ROUND RESULT", "The duel preparation promises no respawn")
check(duelHint:find("NO SECOND LIFE", 1, true) ~= nil, "The duel card stays honest")

-- 4. Progression never claims a save that DataStore has not acknowledged.
check(Career.save("ONLINE", 120, 120).label == "CAREER / SAVED",
    "An acknowledged save is shown as saved")
check(Career.save("ONLINE", 120, 90).label:find("SAVE PENDING", 1, true) ~= nil,
    "Unacknowledged XP is shown as pending")
for _, status in ipairs({ "STUDIO", "LOCKED", "UNAVAILABLE", "LOADING" }) do
    check(not Career.save(status, 120, 120).label:find("SAVED", 1, true),
        status .. " must never show SAVED")
end
check(not Career.save("ONLINE", 120, 150).label:find("SAVED", 1, true),
    "A replicated savedXP above the session XP must not be announced as saved")

-- 5. Surface matrix: every phase, both modes, the flags the clients read.
local audited = 0
for _, phase in ipairs(Plan.PHASES) do
    for _, mode in ipairs({ "FFA", "DUEL" }) do
        for _, defeated in ipairs({ false, true }) do
            for _, briefingOpen in ipairs({ false, true }) do
                local ctx = {
                    phase = phase, mode = mode, defeated = defeated,
                    briefingOpen = briefingOpen, dismissed = false,
                    settingsOpen = false, wideScreen = true,
                    owner = false, studio = false, optIn = false,
                }
                local expected = Plan.expected(ctx)
                local problems = Plan.audit(ctx, expected)
                check(#problems == 0,
                    phase .. "/" .. mode .. ": " .. tostring(problems[1]))
                if expected.results then
                    check(not expected.defeat and not expected.killFeed
                        and not expected.briefing,
                        phase .. "/" .. mode .. ": the round result must stand alone")
                end
                audited += 1
            end
        end
    end
end
check(audited == #Plan.PHASES * 2 * 2 * 2, "Every phase, mode and flag is audited")

-- The briefing card yields to settings and to a dismissed card.
check(not Plan.briefingVisible({ phase = "LIVE", mode = "FFA", settingsOpen = true }),
    "The settings panel hides the briefing card")
check(not Plan.briefingVisible({ phase = "LIVE", mode = "FFA", dismissed = true }),
    "A dismissed briefing card stays hidden")
check(not Plan.briefingVisible({ phase = "RESULTS", mode = "FFA" }),
    "The result phase never shows the briefing card")

-- 6. The audit must refuse a contradictory client instead of trusting it.
local live = { phase = "LIVE", mode = "FFA", defeated = false, briefingOpen = false,
    dismissed = false, settingsOpen = false, wideScreen = true,
    owner = false, studio = false, optIn = false }
local lying = Plan.expected(live)
lying.results = true
lying.defeat = true
lying.killFeed = false
local problems = Plan.audit(live, lying)
check(#problems >= 3, "A contradictory HUD report must be refused")
local joined = table.concat(problems, " | ")
check(joined:find("results", 1, true) ~= nil, "The audit names the result panel")
check(joined:find("defeat", 1, true) ~= nil, "The audit names the defeat card")
check(joined:find("killFeed", 1, true) ~= nil, "The audit names the kill feed")
check(#Plan.audit(live, {}) >= #Plan.SURFACES,
    "A client that reports nothing is refused on every surface")

-- The private profiler needs all three gates.
check(not Plan.privatePerfVisible({ phase = "LIVE", mode = "FFA",
    owner = false, studio = true, optIn = true }),
    "The private profiler stays hidden without the place owner")
check(not Plan.privatePerfVisible({ phase = "LIVE", mode = "FFA",
    owner = true, studio = false, optIn = true }),
    "A published client never shows the private profiler")
check(not Plan.privatePerfVisible({ phase = "LIVE", mode = "FFA",
    owner = true, studio = true, optIn = false }),
    "The private profiler stays opt-in")
check(Plan.privatePerfVisible({ phase = "LIVE", mode = "FFA",
    owner = true, studio = true, optIn = true }),
    "Studio, the place owner and the opt-in may show the private profiler")

-- 7. Touch geometry on small 16:9 and 20:9 screens, with notch-preserved insets.
local screens = {
    { name = "16:9 small", w = 640, h = 360 },
    { name = "16:9 notch", w = 640, h = 336 },
    { name = "20:9", w = 960, h = 432 },
    { name = "20:9 notch", w = 960, h = 408 },
    { name = "16:9 tablet", w = 1024, h = 576 },
}
local measured = 0
for _, screen in ipairs(screens) do
    for _, preset in ipairs(Layout.PRESETS) do
        local buttons = Layout.compute(screen.w, screen.h, preset)
        local ok, reason = Layout.check(screen.w, screen.h, buttons)
        check(ok, screen.name .. " " .. preset .. ": " .. tostring(reason))
        for _, name in ipairs(Layout.NAMES) do
            local rect = buttons[name]
            check(rect.y >= 78, screen.name .. " " .. preset .. ": " .. name
                .. " must stay below the top HUD band")
            check(rect.w >= 28 and rect.h >= 28, screen.name .. " " .. preset
                .. ": " .. name .. " must stay large enough to tap")
        end
        measured += 1
    end
end
check(measured == #screens * #Layout.PRESETS, "Every screen and preset is measured")

local raised = Layout.compute(640, 360)
raised.Aim.y = 60
check(not Layout.check(640, 360, raised),
    "A control pushed into the top HUD band must be refused")
local wide = Layout.compute(960, 432, "LARGE")
check(wide.Fire.x > wide.Aim.x, "Fire stays right of ADS on a 20:9 screen")
check(wide.Fire.x + wide.Fire.w <= 960, "Fire stays on screen on a 20:9 screen")
check(wide.Fire.y + wide.Fire.h <= 432, "Fire stays above the bottom edge")
check(wide.Fire.x > 960 / 2, "Fire stays in the right-hand thumb zone")

print("IRON YARD first minute: " .. tostring(audited) .. " HUD states, "
    .. tostring(measured) .. " touch layouts on 16:9 and 20:9 screens: OK")
