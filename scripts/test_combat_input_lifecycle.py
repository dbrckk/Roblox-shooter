#!/usr/bin/env python3
"""Drive the production input callbacks and render step with a Luau fixture."""
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

root = Path(__file__).resolve().parents[1]
source = (root / "src/client/init.client.luau").read_text(encoding="utf-8")
gamepad = (root / "src/shared/GamepadCombatPolicy.luau").read_text(encoding="utf-8")


def section(start, end):
    first = source.index(start)
    return source[first:source.index(end, first)]


fixture = r"""
local function signal()
    local handlers = {}
    return {
        Connect = function(_, handler)
            local connection = {callback = handler, connected = true}
            table.insert(handlers, connection)
            return {Disconnect = function() connection.connected = false end}
        end,
        fire = function(_, ...)
            for _, handler in ipairs(handlers) do
                if handler.connected then handler.callback(...) end
            end
        end,
    }
end

local function enum()
    return setmetatable({}, {__index = function(self, name)
        local item = {Name = name}
        self[name] = item
        return item
    end})
end

local Enum = {KeyCode = enum(), UserInputType = enum(), RenderPriority = {Camera = {Value = 1}}}
Enum.UserInputState = enum()
local now = 0
local os = {clock = function() return now end}
local GuiService = {MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal()}
local UserInputService = {
    InputBegan = signal(), InputEnded = signal(), JumpRequest = signal(),
    WindowFocusReleased = signal(), GamepadDisconnected = signal(), TouchEnded = signal(),
    TouchEnabled = true,
}
local lastDevice = Enum.UserInputType.Touch
function UserInputService:GetLastInputType() return lastDevice end
local physicalSpace = false
function UserInputService:IsKeyDown() return physicalSpace end
function UserInputService:GetFocusedTextBox() return nil end

local duelOpen = false
local playerGui = {
    GetAttribute = function() return duelOpen end,
    DescendantAdded = signal(), DescendantRemoving = signal(),
    FindFirstChild = function() return nil end,
}
local phase = "LIVE"
local player = {GetAttribute = function() return nil end}
local workspace = {GetAttribute = function() return phase end}
local nativeGui = {Name = "TouchGui", Parent = playerGui, Enabled = true,
    IsA = function(_, class) return class == "ScreenGui" end}
local nativeFrame = {Name = "TouchControlFrame", Parent = nativeGui, Visible = true,
    IsA = function(_, class) return class == "GuiObject" end}
local function newJumpButton()
    local properties = {AbsolutePosition = signal(), AbsoluteSize = signal()}
    return {Name = "JumpButton", Parent = nativeFrame, Visible = true, InputBegan = signal(),
        GetPropertyChangedSignal = function(_, name) return properties[name] end,
        IsA = function(_, class) return class == "GuiButton" end}
end
local hud = {
    open = false,
    updateCrosshair = function() end,
    updateReloadProgress = function() end,
}
function hud:isSettingsOpen() return self.open end
function hud:toggleSettings() self.open = not self.open end

local currentWeaponId = "AssaultRifle"
local weapon = {}
local WeaponConfig = {get = function() return weapon end}
local AutomaticFireCadence = {waitSeconds = function() return 0.1 end, isAutomatic = function() return true end}
local queued = {}
local task = {spawn = function(fn) table.insert(queued, coroutine.create(fn)) end,
    wait = coroutine.yield, defer = function(fn) fn() end}
local function advanceFire()
    for i = #queued, 1, -1 do
        local thread = queued[i]
        local ok, result = coroutine.resume(thread)
        assert(ok, result)
        if coroutine.status(thread) == "dead" then table.remove(queued, i) end
    end
end

local shots, jumps, refreshes = 0, 0, 0
local scoped, sprinting, boosting = false, false, false
local fireWeapon = function() shots += 1 end
local setScoped = function(value) scoped = value end
local setSprinting = function(value) sprinting = value end
local stopBoosting = function() boosting = false end
local startBoosting = function() boosting = true end
local requestJumpMovement = function() jumps += 1 end
local clearHeldCombatInput, releaseTouchFire
local updateTouchVisibility = function() refreshes += 1 end
local function noop() end
local applyMenuMouseState, showLocalBody, tryStartWallRun, updateLocalWallRun = noop, noop, noop, noop
local applyBoostThrust, applyAirControl, applyFallGravity, updateCameraFeel = noop, noop, noop, noop
local humanoid = {Health = 100, MoveDirection = {Magnitude = 0}}
local grounded = false
local function getCharacterParts() return nil, humanoid end
local function isGrounded() return grounded end
local MovementConfig = {boostFuelMax = 100, boostFuelRegenPerSecond = 76}
local localBoostFuel = 100
function hud:setBoostFuel() end
local render
local RunService = {BindToRenderStep = function(_, _, _, fn) render = fn end}

local function press(key, device, processed)
    UserInputService.InputBegan:fire({KeyCode = Enum.KeyCode[key], UserInputType = Enum.UserInputType[device]}, processed)
end
local function openMenu()
    GuiService.MenuIsOpen = true
    GuiService.MenuOpened:fire()
end
local function closeMenu()
    GuiService.MenuIsOpen = false
    GuiService.MenuClosed:fire()
end
"""

checks = r"""
press("Unknown", "MouseButton1")
press("ButtonL2", "Gamepad1")
press("ButtonL3", "Gamepad1")
physicalSpace = true
press("Space", "Keyboard", true)
advanceFire()
render(0.016)
assert(shots == 1 and sprinting and boosting)

openMenu()
advanceFire()
render(0.016)
assert(shots == 1 and not scoped and not sprinting and not boosting,
    "Opening Roblox menu must release a held trigger, sprint and boost")

press("ButtonA", "Gamepad1", true)
press("ButtonR2", "Gamepad1")
press("ButtonL2", "Gamepad1")
press("M", "Keyboard")
UserInputService.JumpRequest:fire()
assert(shots == 1 and jumps == 0 and not hud.open and not scoped and refreshes == 1)

closeMenu()
render(0.016)
advanceFire()
assert(not boosting and shots == 1 and refreshes == 2, "Closing menu must require fresh input")

press("ButtonR2", "Gamepad1")
press("ButtonL2", "Gamepad1")
assert(shots == 2 and scoped, "New trigger and aim inputs work after closing")

releaseTouchFire = function() touchFireHeld = false end
beginHeldFire(false, true)
assert(touchFireHeld)
UserInputService.WindowFocusReleased:fire()
advanceFire()
assert(not touchFireHeld and not scoped and shots == 2)
physicalSpace = false
press("Space", "Keyboard", true)
render(0.016)
assert(boosting, "Native processed jump still arms keyboard boost")
UserInputService.InputEnded:fire({KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard})
render(0.016)
assert(not boosting)

duelOpen = true
UserInputService.JumpRequest:fire()
press("ButtonR2", "Gamepad1")
assert(shots == 2 and jumps == 0, "Duel lobby still blocks combat inputs")

duelOpen = false
local layoutChanges = 0
updateTouchLayout = function() layoutChanges += 1 end
local jump = newJumpButton()
playerGui.DescendantAdded:fire(jump)
jump:GetPropertyChangedSignal("AbsolutePosition"):fire()
jump:GetPropertyChangedSignal("AbsoluteSize"):fire()
assert(layoutChanges == 3, "Native button creation, movement and resize each refresh layout")
local function touchJump(button)
    local input = {UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin}
    button.InputBegan:fire(input)
    return input
end
local tap = touchJump(jump)
UserInputService.JumpRequest:fire()
now += 0.12
render(0.016)
UserInputService.TouchEnded:fire(tap)
assert(jumps == 1 and not boosting, "Brief touch still jumps without boosting")
local held = touchJump(jump)
local second = touchJump(jump)
grounded = true
now += 0.2
render(0.016)
assert(not boosting, "A hold cannot start boost before takeoff")
grounded = false
render(0.016)
UserInputService.TouchEnded:fire(second)
assert(boosting, "A separate finger cannot release the active jump hold")
UserInputService.TouchEnded:fire(held)
assert(not boosting, "The owning finger releases boost immediately")

local function holdJump(button)
    local input = touchJump(button)
    now += 0.2
    render(0.016)
    assert(boosting, "A fresh hold on an available native button boosts in air")
    return input
end

held = holdJump(jump)
held.UserInputState = Enum.UserInputState.Cancel
render(0.016)
assert(not boosting, "Cancelled touch releases boost before the next thrust")
holdJump(jump)
openMenu()
closeMenu()
render(0.016)
assert(not boosting, "Menu closure cannot resume an old held touch")
holdJump(jump)
lastDevice = Enum.UserInputType.Gamepad1
render(0.016)
lastDevice = Enum.UserInputType.Touch
render(0.016)
assert(not boosting, "Switching to controller releases the touch hold")
holdJump(jump)
phase = "DUEL_PREP"
render(0.016)
phase = "LIVE"
render(0.016)
assert(not boosting, "A new round cannot inherit a held touch from duel prep")
holdJump(jump)
humanoid = {Health = 100, MoveDirection = {Magnitude = 0}}
render(0.016)
assert(not boosting, "Replacing the character clears the old hold")
holdJump(jump)
playerGui.DescendantRemoving:fire(jump)
assert(not boosting, "Removing the native button releases its held input")
local changesAfterRemoval = layoutChanges
jump:GetPropertyChangedSignal("AbsoluteSize"):fire()
assert(layoutChanges == changesAfterRemoval, "A removed native button cannot refresh layout")
local replacement = newJumpButton()
playerGui.DescendantAdded:fire(replacement)
holdJump(replacement)
nativeGui.Enabled = false
render(0.016)
assert(not boosting, "Hiding the native touch GUI releases boost")
print("IRON YARD input lifecycle: keyboard, controller, tap, held jump, cancellation and native button replacement passed")
"""

guard = ""
if "local function combatInputBlocked()" in source:
    guard = section("local function combatInputBlocked()", "local function getCharacterParts()")
practice = (root / "src/shared/PracticeMode.luau").read_text(encoding="utf-8")
practice = practice.replace(
    'local WeaponConfig = if script then require(script.Parent:WaitForChild("WeaponConfig")) else require("./WeaponConfig")',
    "local WeaponConfig = DrillWeapons",
)
weapons = (root / "src/shared/WeaponConfig.luau").read_text(encoding="utf-8")
chunks = [
    fixture, "local DrillWeapons = (function()\n" + weapons + "\nend)()\n",
    "local PracticeMode = (function()\n" + practice + "\nend)()\n", "local GamepadCombatPolicy = (function()\n" + gamepad + "\nend)()\n", guard,
    section("local mouseFireHeld = false", "local function advanceFeedbackEpoch("),
    section('RunService:BindToRenderStep("IronYardClientCameraFeel"', "\nenforceFirstPerson()"),
    section("-- Observe the native jump button", "-- IRON YARD / SAFE AREA"),
    checks,
]
with TemporaryDirectory() as directory:
    script = Path(directory) / "test-combat-input-lifecycle.luau"
    script.write_text("\n".join(chunks), encoding="utf-8")
    subprocess.run([str(Path(sys.argv[1]).resolve()), str(script)], check=True)
