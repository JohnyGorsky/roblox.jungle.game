--!strict
-- RoleChip.local.luau — "you are manning a station, and here is what it's doing" (Job #075).
--
-- `RoleServer` has granted station bonuses since Job #034 — the engineer cuts fuel burn, the driver gets
-- sharper handling, the gunner a faster turret, the mechanic passive hull regen, the medic a crew heal —
-- and in every build since, **nothing has told the player any of it was happening.** GAME.md's whole
-- role design ("manning a station as your role gives an efficiency bonus — a reason to divide the crew")
-- was invisible, which makes it, functionally, not a mechanic. This is that missing half.
--
-- The numbers below are read from RoleServer, not invented here; if that file's multipliers change,
-- change these strings. They are deliberately phrased as the EFFECT ("−30% fuel burn"), not the
-- multiplier, because 0.7 is not something anyone should have to interpret mid-run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))
local HudState = require(RunUI:WaitForChild("HudState"))

type RoleInfo = { label: string, bonus: string }

-- role id -> what to say. Keys match HudState's role ids; icons come from Theme.roleIcon.
local ROLE: { [string]: RoleInfo } = {
	driver = { label = "Driver", bonus = "+15% turn authority" }, -- StationTurnMul 1.15
	gunner = { label = "Gunner", bonus = "+18% turret speed" }, -- StationGunMul 0.85 (a cooldown scale)
	engineer = { label = "Engineer", bonus = "−30% fuel burn" }, -- StationFuelMul 0.7
	mechanic = { label = "Mechanic", bonus = "+2.5 hull HP/s" }, -- RoleServer.REGEN
	medic = { label = "Medic", bonus = "+3 crew HP/s" }, -- RoleServer.MEDIC_REGEN
}

local player = Players.LocalPlayer

local gui = Components.screen("RoleChip", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0, 0.5)
holder.Position = UDim2.fromScale(0.015, 0.42)
holder.Size = UDim2.fromScale(0.18, 0.09)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Active = false

local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(150, 44)
clamp.MaxSize = Vector2.new(280, 76)
clamp.Parent = holder

holder.Parent = gui

local chip = RunComponents.roleChip(holder)
chip.instance.Size = UDim2.fromScale(1, 1)

local function render()
	-- A station bonus only exists while the run is on and you're aboard; showing the chip at the crash
	-- site would promise a bonus that RoleServer isn't applying yet.
	if HudState.current() ~= "ABOARD" then
		chip.hide()
		return
	end
	local role = HudState.role()
	local info = role and ROLE[role]
	if not role or not info then
		chip.hide()
		return
	end
	chip.show((Theme.roleIcon :: { [string]: string })[role] or "crew", info.label, info.bonus)
end

HudState.onRoleChange(render)
HudState.onChange(render)
render()
