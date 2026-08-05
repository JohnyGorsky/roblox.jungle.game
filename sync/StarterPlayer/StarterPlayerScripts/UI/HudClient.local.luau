--!strict
-- HudClient.local.luau — the boat's vitals: fuel, hull, and what's on the cargo deck (Job 010,
-- rebuilt on the design system in Job #075).
--
-- Reads the Boat model's replicated attributes. Everything here is about the BOAT, which is why it is
-- shown in CRASHSITE (dimmed — you want to see the tank you're setting off with) and ABOARD, and hidden
-- ASHORE, where `BoatStatusCard` takes over with the one boat fact that still matters on foot.
--
-- Two things the greybox version did that this one doesn't:
--   · the cargo line was a single formatted string, `"CARGO Gas 12 Metal 8 Ammo 40 (+18 rds)"`. Correct,
--     and unreadable at a glance while steering. It is three icon chips now.
--   · fuel and hull each open-coded their own low-threshold colour swap. That logic lives in
--     `RunComponents.gauge` now, so the two cannot drift apart — and it fires a warning cue once per
--     crossing instead of only changing colour.
--
-- The "next fuel" readout moved out entirely — it is the dock pin on `RiverProgress`'s track.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))
local HudState = require(RunUI:WaitForChild("HudState"))

local LOW_FUEL = 0.2
local LOW_HULL = 0.3
local TICK = 0.15 -- attributes replicate on the server's clock; polling faster just burns frames

local player = Players.LocalPlayer

local gui = Components.screen("BoatHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

-- ── fuel + hull, bottom-centre ───────────────────────────────────────────────────────────────────
-- Centre, not a corner: the hotbar owns bottom-left and the driver's throttle owns bottom-right, and
-- these have to stay clear of both (§6.11 — a panel never covers the core HUD).
local vitals = Instance.new("Frame")
vitals.Name = "Vitals"
vitals.AnchorPoint = Vector2.new(0.5, 1)
vitals.Position = UDim2.fromScale(0.5, 0.965)
vitals.Size = UDim2.fromScale(0.3, 0.1)
vitals.BackgroundTransparency = 1
vitals.BorderSizePixel = 0
vitals.Active = false

local vitalsClamp = Instance.new("UISizeConstraint")
vitalsClamp.MinSize = Vector2.new(190, 54)
vitalsClamp.MaxSize = Vector2.new(430, 104)
vitalsClamp.Parent = vitals

local vitalsLayout = Instance.new("UIListLayout")
vitalsLayout.FillDirection = Enum.FillDirection.Vertical
vitalsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
vitalsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
vitalsLayout.SortOrder = Enum.SortOrder.LayoutOrder
vitalsLayout.Padding = UDim.new(0, Theme.space.xs)
vitalsLayout.Parent = vitals

vitals.Parent = gui

local fuelGauge = RunComponents.gauge({
	icon = "fuel",
	color = Theme.color.gold,
	dangerBelow = LOW_FUEL,
	dangerSound = "lowFuel",
	size = UDim2.fromScale(1, 0.46),
	layoutOrder = 1,
	parent = vitals,
})

local hullGauge = RunComponents.gauge({
	icon = "hull",
	color = Theme.color.green,
	dangerBelow = LOW_HULL,
	dangerSound = "lowHull",
	size = UDim2.fromScale(1, 0.46),
	layoutOrder = 2,
	parent = vitals,
})

-- ── cargo deck, top-left ─────────────────────────────────────────────────────────────────────────
local cargo = Instance.new("Frame")
cargo.Name = "Cargo"
cargo.AnchorPoint = Vector2.new(0, 0)
cargo.Position = UDim2.fromScale(0.015, 0.02)
cargo.Size = UDim2.fromScale(0.27, 0.05)
cargo.BackgroundTransparency = 1
cargo.BorderSizePixel = 0
cargo.Active = false

local cargoClamp = Instance.new("UISizeConstraint")
cargoClamp.MinSize = Vector2.new(180, 30)
cargoClamp.MaxSize = Vector2.new(400, 48)
cargoClamp.Parent = cargo

local cargoLayout = Instance.new("UIListLayout")
cargoLayout.FillDirection = Enum.FillDirection.Horizontal
cargoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cargoLayout.SortOrder = Enum.SortOrder.LayoutOrder
cargoLayout.Padding = UDim.new(0, Theme.space.xs)
cargoLayout.Parent = cargo

cargo.Parent = gui

local function makeCargoChip(icon: string, tint: Color3, order: number)
	local chip = RunComponents.statChip(icon, tint, cargo)
	chip.instance.Size = UDim2.fromScale(0.32, 1)
	chip.instance.LayoutOrder = order
	return chip
end

-- The three loot resources, in the order GAME.md names them: gasoline (move), metal (repair),
-- ammo (fight). Each tinted with the accent that already means that thing elsewhere in the UI.
local gasChip = makeCargoChip("fuel", Theme.color.gold, 1)
local metalChip = makeCargoChip("metal", Theme.color.blue, 2)
local ammoChip = makeCargoChip("ammoBox", Theme.color.cream, 3)

-- ── drive it ─────────────────────────────────────────────────────────────────────────────────────

local function ratio(cur: number?, max: number?): number
	if not cur or not max or max <= 0 then
		return 0
	end
	return math.clamp(cur / max, 0, 1)
end

local function num(inst: Instance, name: string): number
	return (inst:GetAttribute(name) :: number?) or 0
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	local state = HudState.current()
	local boat = HudState.boat()

	-- ASHORE hands the boat story to BoatStatusCard; with no boat at all there is nothing to say.
	local showVitals = boat ~= nil and state ~= "ASHORE"
	vitals.Visible = showVitals
	cargo.Visible = boat ~= nil and state == "ABOARD"

	if not boat or not showVitals then
		return
	end

	-- Before the run, these are information rather than pressure — shown, but not shouting.
	fuelGauge.setDimmed(state == "CRASHSITE")
	hullGauge.setDimmed(state == "CRASHSITE")

	local fuel = ratio(num(boat, "Fuel"), num(boat, "MaxFuel"))
	fuelGauge.set(fuel, ("FUEL  %d%%"):format(math.floor(fuel * 100 + 0.5)))

	local hull = ratio(num(boat, "HP"), num(boat, "MaxHP"))
	hullGauge.set(hull, ("BOAT  %d%%"):format(math.floor(hull * 100 + 0.5)))

	if cargo.Visible then
		gasChip.setValue(tostring(math.floor(num(boat, "Gasoline"))))
		metalChip.setValue(tostring(math.floor(num(boat, "Metal"))))

		-- ONE number: how many shots the turret actually has left.
		--
		-- This chip used to read "3+0", then "2+11" after the first shot, because the boat tracks ammo in
		-- two places — `Ammo` is CRATES on the deck and `Rounds` is what's loaded in the turret, and
		-- GunServer silently spends a crate for 12 rounds when the turret runs dry. Showing both as
		-- "crates+rounds" put an arithmetic problem on the HUD and made the total appear to jump around.
		--
		-- The player only ever wants the total, and it is exact (a crate is exactly
		-- TURRET_ROUNDS_PER_CRATE rounds, no remainder), so it goes down by one per shot and never jumps.
		-- The gunner's own readout under the reticle keeps the crates/rounds breakdown, in words, where
		-- there is room for it.
		local crates = math.floor(num(boat, "Ammo"))
		local rounds = math.floor(num(boat, "Rounds"))
		local shots = rounds + crates * ItemDefs.TURRET_ROUNDS_PER_CRATE
		ammoChip.setValue(tostring(shots))
		ammoChip.setAlert(shots <= 0)
	end
end)
