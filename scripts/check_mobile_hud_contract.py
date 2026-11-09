#!/usr/bin/env python3
"""Offline UI-wiring regression for private, touch-safe public combat HUD.

Luau layout tests exercise actual geometry; these source contracts verify
that the live Roblox controls consume those positions and settings.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(name):
    return (root / name).read_text(encoding="utf-8")

layout = read("src/shared/TouchLayout.luau")
boost_policy = read("src/shared/BoostMeterPolicy.luau")
controller = read("src/client/HudController.luau")
client = read("src/client/init.client.luau")
match = read("src/client/MatchHud.client.luau")
briefing = read("src/client/Briefing.client.luau")

for needle in (
    'Layout.PRESETS = { "COMPACT", "STANDARD", "LARGE" }',
    "Layout.SETTINGS_BUTTON =",
    'local factor = FACTORS[preset or "STANDARD"]',
    'assert(factor, "Unknown touch size preset")',
    'if intersects(r, settings) then',
):
    assert needle in layout, f"Broken mobile geometry/preset: {needle}"

for needle in (
    'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TouchLayout"))',
    'self.touchSizeIndex = 2',
    'self.player:SetAttribute("IronYardTouchSizePreset"',
    'self.touchSizeValueLabel = self:_makeStepper(panel, "BUTTON SIZE"',
    'self.sensitivityValueLabel = self:_makeStepper(panel, "MOUSE SENS"',
    'local settingsRect = TouchLayout.SETTINGS_BUTTON',
    'self.gui.DisplayOrder = open and 50 or self.defaultDisplayOrder',
    'SetAttribute("IronYardSettingsOpen", open)',
):
    assert needle in controller, f"Mobile settings wiring missing: {needle}"

for needle in (
    'local preset = player:GetAttribute("IronYardTouchSizePreset")',
    "TouchLayout.compute(viewport.X, viewport.Y, preset)",
    'player:GetAttributeChangedSignal("IronYardTouchSizePreset"):Connect(layoutControls)',
    "TouchLayout.check(viewport.X, viewport.Y, positions)",
    'if not valid then',
    'touchGui.Enabled = enabled',
):
    assert needle in client, f"Touch control sizing not wired: {needle}"

for needle in (
    'top.Visible = playerGui:GetAttribute("IronYardBriefingOpen") ~= true',
    'playerGui:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(update)',
):
    assert needle in match, f"Score overlay still collides with briefing: {needle}"

for needle in (
    'panel.Position = UDim2.new(0.5, 0, 0, 8)',
    'playerGui:GetAttribute("IronYardSettingsOpen") == true',
    'playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(',
    'setCardVisible(false)',
):
    assert needle in briefing, f"Briefing obstructs mobile controls: {needle}"

for needle in (
    'WaitForChild("BoostMeterPolicy")',
    'BoostMeterPolicy.shouldDraw(',
    'if not draw then return end',
    'self.lastBoostUpdateAt = now',
    'if self.lastBoostZone ~= zone then',
    'if self.boostTween then self.boostTween:Cancel() end',
    'TweenService:Create(self.boostFill,',
):
    assert needle in controller, f"Boost HUD rendering still allocates per-frame: {needle}"
for needle in ('Policy.MIN_INTERVAL = 0.1',
               'Policy.MIN_DELTA = 0.005',
               'zone ~= Policy.zone(previousRatio)',
               'if ratio == 0 or ratio == 1'):
    assert needle in boost_policy, f"Boost update scheduler lost urgency/budget: {needle}"
assert 'hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)' in client, (
    "Client fuel remains driven by real local movement, not placeholders")
print("IRON YARD mobile presets, modal layering and bounded boost Tweens: OK")
