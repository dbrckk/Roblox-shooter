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
        Connect = function(_, handler) table.insert(handlers, handler) end,
        fire = function(_, ...)
            for _, handler in ipairs(handlers) do handler(...) end
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
local GuiService = {MenuIsOpen = false, MenuOpened = signal(), MenuClosed = signal()}
local UserInputService = {
    InputBegan = signal(), InputEnded = signal(), JumpRequest = signal(),
    WindowFocusReleased = signal(), GamepadDisconnected = signal(),
}
local physicalSpace = false
function UserInputService:IsKeyDown() return physicalSpace end
function UserInputService:GetFocusedTextBox() return nil end

local duelOpen = false
local playerGui = {GetAttribute = function() return duelOpen end}
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
local task = {spawn = function(fn) table.insert(queued, coroutine.create(fn)) end, wait = coroutine.yield}
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
local function getCharacterParts() return nil, nil end
local function isGrounded() return false end
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
print("IRON YARD menu input lifecycle: mouse, gamepad, touch release and fresh boost passed")
"""

guard = ""
if "local function combatInputBlocked()" in source:
    guard = section("local function combatInputBlocked()", "local function getCharacterParts()")
chunks = [
    fixture, "local GamepadCombatPolicy = (function()\n" + gamepad + "\nend)()\n", guard,
    section("local mouseFireHeld = false", "local function advanceFeedbackEpoch("),
    section('RunService:BindToRenderStep("IronYardClientCameraFeel"', "\nenforceFirstPerson()"),
    checks,
]
with TemporaryDirectory() as directory:
    script = Path(directory) / "test-combat-input-lifecycle.luau"
    script.write_text("\n".join(chunks), encoding="utf-8")
    subprocess.run([str(Path(sys.argv[1]).resolve()), str(script)], check=True)
