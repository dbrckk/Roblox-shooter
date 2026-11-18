-- Independent from the career key. UpdateAsync can replay this transaction.
local Objectives = if script then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared")
    :WaitForChild("SessionObjectives")) else require("../shared/SessionObjectives")
local Ledger = {}

local function validChoice(choice)
    return type(choice) == "table" and type(choice.selected) == "boolean"
        and type(choice.token) == "string" and #choice.token >= 8
        and type(choice.stamp) == "number" and choice.stamp >= 0
        and choice.stamp < 2^53 and choice.stamp % 1 == 0
end

local function copyDay(bucket)
    assert(type(bucket) == "table" and type(bucket.credits) == "table", "Invalid objective day")
    local state = Objectives.normalize(bucket.progress)
    assert(state, "Invalid objective progress")
    local credits = {}
    local total = 0
    for token, count in pairs(bucket.credits) do
        assert(type(token) == "string" and #token >= 8 and type(count) == "number"
            and count > 0 and count <= Objectives.ELIMINATIONS and count % 1 == 0,
            "Invalid objective credit")
        credits[token] = count
        total += count
    end
    assert((state.kills == Objectives.ELIMINATIONS and total == 0) or total == state.kills,
        "Objective credits disagree with earned eliminations")
    return { progress = state, credits = credits }
end

local function blankDay(day)
    return { progress = Objectives.forDay(nil, day), credits = {} }
end

local function earn(bucket, token, delta)
    if not delta or delta.day ~= bucket.progress.day then return end
    local progress = bucket.progress
    local previously = bucket.credits[token] or 0
    local added = math.max(0, delta.kills - previously)
    local kills = math.min(Objectives.ELIMINATIONS, progress.kills + added)
    if kills == Objectives.ELIMINATIONS then
        -- No further kill credits matter after reaching the daily cap.
        bucket.credits = {}
    elseif added > 0 then
        bucket.credits[token] = delta.kills
    end
    bucket.progress = Objectives.normalize({
        day = progress.day, kills = kills, weapons = bit32.bor(progress.weapons, delta.weapons),
        ffa = progress.ffa or delta.ffa, unlocked = progress.unlocked or delta.unlocked,
    })
end

function Ledger.commit(raw, token, day, today, yesterday, choice)
    assert(type(token) == "string" and #token >= 8, "Invalid objective session")
    local current, previous, selected
    local unlocked = false
    if raw ~= nil then
        assert(type(raw) == "table" and raw.schema == 1 and type(raw.unlocked) == "boolean",
            "Unknown objective schema")
        current = copyDay(raw.current)
        previous = raw.previous and copyDay(raw.previous)
        unlocked = raw.unlocked or current.progress.unlocked or (previous and previous.progress.unlocked) == true
        if raw.selection ~= nil then
            assert(validChoice(raw.selection), "Invalid stored objective selection")
            selected = table.clone(raw.selection)
        end
    end

    local activeDay = current and math.max(day, current.progress.day) or day
    if not current or current.progress.day < activeDay then
        previous = current and current.progress.day == activeDay - 1 and current or nil
        current = blankDay(activeDay)
    end
    if previous and previous.progress.day ~= activeDay - 1 then previous = nil end
    if not previous and ((today and today.day == activeDay - 1)
        or (yesterday and yesterday.day == activeDay - 1)) then
        previous = blankDay(activeDay - 1)
    end
    earn(current, token, today)
    earn(current, token, yesterday)
    if previous then
        earn(previous, token, today)
        earn(previous, token, yesterday)
    end

    unlocked = unlocked or current.progress.unlocked or (previous and previous.progress.unlocked) == true
    current.progress.unlocked = unlocked
    if choice then
        assert(validChoice(choice) and choice.token == token, "Invalid objective selection")
        if (not choice.selected or unlocked)
            and (not selected or choice.stamp > selected.stamp
                or (choice.stamp == selected.stamp and choice.token > selected.token)) then
            selected = table.clone(choice)
        end
    end
    return { schema = 1, current = current, previous = previous, unlocked = unlocked, selection = selected }
end

return Ledger
