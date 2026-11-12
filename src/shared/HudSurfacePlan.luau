-- IRON YARD / pure HUD surface contract for the first minute (LOT C2).
-- It answers "which surfaces may share the screen, and which must yield", so a
-- briefing card, a defeat card and the round result can never claim the same
-- moment. It also fixes the order of the first minute: a step counts only when
-- its own evidence exists and the previous step was reached.
-- The conditions mirror the shipped clients; scripts/check_first_minute_contract.py
-- fails as soon as those clients drift away from them.
-- No Roblox dependency: the caller passes the flags the clients actually read.
local Plan = {}

Plan.PHASES = { "WAITING", "COUNTDOWN", "LIVE", "RESULTS", "DUEL_PREP", "DUEL_BREAK" }
Plan.SURFACES = { "briefing", "defeat", "killFeed", "progression", "results",
    "tactical", "privatePerf" }
Plan.STEPS = { "JOIN", "OBJECTIVE", "AIM", "FIRE", "RELOAD", "DEATH", "RESPAWN",
    "RESULT", "PROGRESSION" }

local VALID_PHASE = {}
for _, phase in ipairs(Plan.PHASES) do VALID_PHASE[phase] = true end

local function contextOf(ctx)
    assert(type(ctx) == "table", "Missing HUD context")
    local phase = ctx.phase
    assert(type(phase) == "string" and VALID_PHASE[phase],
        "Unknown HUD phase: " .. tostring(phase))
    assert(ctx.mode == "FFA" or ctx.mode == "DUEL",
        "Unknown match mode: " .. tostring(ctx.mode))
    return phase
end

-- The briefing card belongs to the pre-fight moment only. A settings panel or a
-- dismissed card removes it; RESULTS and WAITING never show it.
function Plan.briefingVisible(ctx)
    local phase = contextOf(ctx)
    if ctx.dismissed == true or ctx.settingsOpen == true then return false end
    return phase == "COUNTDOWN" or phase == "LIVE"
end

-- The tactical board yields to the full briefing panel, exactly like the shipped
-- client, and stays hidden in the lobby.
function Plan.tacticalVisible(ctx)
    return contextOf(ctx) ~= "WAITING" and ctx.briefingOpen ~= true
end

-- The kill feed needs combat and a viewport wide enough to read it.
function Plan.killFeedVisible(ctx)
    return contextOf(ctx) == "LIVE" and ctx.wideScreen ~= false
end

-- The defeat card is a combat overlay: it never survives into the result panel.
function Plan.defeatVisible(ctx)
    local phase = contextOf(ctx)
    if ctx.defeated ~= true then return false end
    return phase == "LIVE" or (ctx.mode == "DUEL" and phase == "DUEL_BREAK")
end

function Plan.resultsVisible(ctx)
    return contextOf(ctx) == "RESULTS"
end

-- The career panel is persistent information: it steps aside for the result and
-- for the briefing panel, never for ordinary combat.
function Plan.progressionVisible(ctx)
    return contextOf(ctx) ~= "RESULTS" and ctx.briefingOpen ~= true
end

-- Studio, the place owner and an explicit opt-in: three gates, never fewer.
function Plan.privatePerfVisible(ctx)
    return ctx.owner == true and ctx.studio == true and ctx.optIn == true
end

function Plan.expected(ctx)
    return {
        briefing = Plan.briefingVisible(ctx),
        tactical = Plan.tacticalVisible(ctx),
        killFeed = Plan.killFeedVisible(ctx),
        defeat = Plan.defeatVisible(ctx),
        results = Plan.resultsVisible(ctx),
        progression = Plan.progressionVisible(ctx),
        privatePerf = Plan.privatePerfVisible(ctx),
    }
end

-- Pairs that can never share the screen, whatever a client reports.
local FORBIDDEN = {
    { "results", "defeat", "the round result and the defeat card must not share the screen" },
    { "results", "killFeed", "the round result replaces the kill feed" },
}

-- `observed` is what a client says it is drawing. The audit names every surface
-- that disagrees with the plan, plus any pair that must never coexist.
function Plan.audit(ctx, observed)
    assert(type(observed) == "table", "Missing observed surfaces")
    local problems = {}
    local expected = Plan.expected(ctx)
    for _, name in ipairs(Plan.SURFACES) do
        local seen = observed[name]
        if type(seen) ~= "boolean" then
            table.insert(problems, name .. " must be reported as a boolean")
        elseif seen ~= expected[name] then
            table.insert(problems, name .. (seen and " must be hidden" or " must be visible"))
        end
    end
    for _, pair in ipairs(FORBIDDEN) do
        if observed[pair[1]] == true and observed[pair[2]] == true then
            table.insert(problems, pair[3])
        end
    end
    return problems
end

-- A step counts only when its own evidence exists AND the previous step was
-- reached: no result before a death, no progression claim before a result.
function Plan.reached(evidence)
    assert(type(evidence) == "table", "Missing first-minute evidence")
    local reached = {}
    for index, step in ipairs(Plan.STEPS) do
        local ok = evidence[step] == true
        if index > 1 and reached[Plan.STEPS[index - 1]] ~= true then ok = false end
        reached[step] = ok
    end
    return reached
end

-- First step that is not reached, so a failure names the gap instead of an index.
function Plan.missing(reached)
    assert(type(reached) == "table", "Missing reached steps")
    for _, step in ipairs(Plan.STEPS) do
        if reached[step] ~= true then return step end
    end
    return nil
end

return Plan
