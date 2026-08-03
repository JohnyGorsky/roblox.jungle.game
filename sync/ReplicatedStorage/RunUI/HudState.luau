--!strict
-- HudState.luau — the in-run HUD's state machine (Job #075). CLIENT-ONLY, presentational.
--
-- ⚠️ WHY THIS FOLDER AND NOT `UI/`: `sync/ReplicatedStorage/UI/` and `lobby/sync/ReplicatedStorage/UI/`
-- are BYTE-IDENTICAL BY CONTRACT (see Theme.luau's header). Run-only modules would break that, so the
-- game place gets its own `RunUI/` folder that the lobby never receives.
--
-- The run has three contexts, and the HUD should show a different set of things in each:
--
--   CRASHSITE  the run hasn't started   → board the boat, crew count, untie
--   ABOARD     running, you're on deck  → fuel, hull, cargo, river progress, your station
--   ASHORE     running, you're not      → your ammo/bandages, and how the boat is doing without you
--
-- Every screen SUBSCRIBES here instead of re-deriving the answer. Before this, six client scripts each
-- polled `Workspace.RunStarted` on RenderStepped; they now share one 5 Hz Heartbeat loop.
--
-- Nothing here is authoritative. A HUD state is a drawing decision — a client that lies to itself
-- about which bars to draw has gained nothing — so it needs no server round-trip.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local player = Players.LocalPlayer

local HudState = {}

export type State = "CRASHSITE" | "ABOARD" | "ASHORE"

-- How long a candidate state must hold before it is published. Without this, walking the gangplank or
-- hopping on deck strobes the entire HUD as the raycast flickers between hull and dock.
local SETTLE = 0.4
local TICK = 0.2 -- 5 Hz; the states change on human timescales, not frame ones

-- Station part name -> role id. The parts are built by CargoServer/BoatServer and manned by proximity
-- (RoleServer.MAN_RANGE); we only mirror that for display.
local STATIONS: { [string]: string } = {
	["Fuel Station"] = "engineer",
	["Repair Station"] = "mechanic",
	["Medic Station"] = "medic",
}
local MAN_RANGE = 11 -- MUST match RoleServer.MAN_RANGE, or the chip lies about the bonus being live

-- ── observable plumbing ──────────────────────────────────────────────────────────────────────────

local stateEvent = Instance.new("BindableEvent")
local roleEvent = Instance.new("BindableEvent")

local currentState: State = "CRASHSITE"
local currentRole: string? = nil -- "driver" | "gunner" | "engineer" | "mechanic" | "medic" | nil

function HudState.current(): State
	return currentState
end

function HudState.onChange(fn: (new: State, old: State) -> ()): RBXScriptConnection
	-- fire immediately so a late subscriber isn't blank until the next transition
	task.defer(function()
		fn(currentState, currentState)
	end)
	return stateEvent.Event:Connect(fn)
end

function HudState.role(): string?
	return currentRole
end

function HudState.onRoleChange(fn: (role: string?) -> ()): RBXScriptConnection
	task.defer(function()
		fn(currentRole)
	end)
	return roleEvent.Event:Connect(function(role: string)
		-- BindableEvents cannot carry nil, so "" is the wire form of "no station"
		fn(if role == "" then nil else role)
	end)
end

function HudState.isDriver(): boolean
	return currentRole == "driver"
end

function HudState.isGunner(): boolean
	return currentRole == "gunner"
end

-- Show `object` only in the listed states. The workhorse — most screens need nothing else.
function HudState.bind(object: GuiObject | ScreenGui, states: { State })
	local allowed: { [string]: boolean } = {}
	for _, s in ipairs(states) do
		allowed[s] = true
	end
	local function apply(state: State)
		local visible = allowed[state] == true
		if object:IsA("ScreenGui") then
			object.Enabled = visible
		else
			(object :: GuiObject).Visible = visible
		end
	end
	HudState.onChange(apply)
	apply(currentState)
end

-- ── reading the world ────────────────────────────────────────────────────────────────────────────

local function boat(): Model?
	local b = Workspace:FindFirstChild("Boat")
	return if b and b:IsA("Model") then b else nil
end

HudState.boat = boat

function HudState.runStarted(): boolean
	return Workspace:GetAttribute("RunStarted") == true
end

function HudState.runEnded(): boolean
	return Workspace:GetAttribute("RunEnded") == true
end

function HudState.isNight(): boolean
	return Workspace:GetAttribute("Phase") == "night"
end

-- The on-boat test, copied deliberately from StagingServer.isOnBoat (:234-240) — including WHY it is a
-- downward raycast and not a bounding box:
--
--   "A bounding box overlaps the pier when the boat is docked ~2 studs off it, wrongly counting
--    pier-standers."
--
-- That failure mode is exactly the ABOARD/ASHORE boundary this state machine turns on, so the two must
-- stay the same rule. If one changes, change both.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

local function onBoat(theBoat: Model): boolean
	local char = player.Character
	if not char then
		return false
	end

	-- A seated player is aboard by definition. Checked first because a driver's downward ray can slip
	-- between hull parts and briefly report ASHORE while they're steering — the worst possible moment
	-- to swap the HUD out from under them.
	local hum = char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsDescendantOf(theBoat) then
		return true
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	rayParams.FilterDescendantsInstances = { theBoat }
	return Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams) ~= nil
end

HudState.onBoat = function(): boolean
	local b = boat()
	return b ~= nil and onBoat(b)
end

-- Which station is this player manning? Mirrors RoleServer's presence test so the chip only claims a
-- bonus that is actually being applied server-side.
local function computeRole(theBoat: Model?): string?
	local char = player.Character
	if not char or not theBoat or char:GetAttribute("Downed") == true then
		return nil
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat then
		if seat.Name == "DriverSeat" then
			return "driver"
		elseif seat.Name == "GunSeat" then
			return "gunner"
		end
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	for partName, role in pairs(STATIONS) do
		local part = theBoat:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= MAN_RANGE then
			return role
		end
	end
	return nil
end

-- ── the loop ─────────────────────────────────────────────────────────────────────────────────────

local function computeState(): State
	if not HudState.runStarted() then
		return "CRASHSITE"
	end
	local b = boat()
	if b and onBoat(b) then
		return "ABOARD"
	end
	return "ASHORE"
end

local candidate: State = currentState
local candidateSince = 0
local acc = 0

RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0

	local want: State = computeState()
	if want ~= candidate then
		candidate = want
		candidateSince = os.clock()
	elseif want ~= currentState and (os.clock() - candidateSince) >= SETTLE then
		local old = currentState
		currentState = want
		stateEvent:Fire(currentState, old)
	end

	-- The role chip is allowed to be twitchy-free without a settle window: stepping off a station
	-- SHOULD drop the bonus indicator immediately, because the server has already dropped the bonus.
	local role = computeRole(boat())
	if role ~= currentRole then
		currentRole = role
		roleEvent:Fire(role or "")
	end
end)

-- Studio-only: shout about any HUD art/audio still on a Job #075 placeholder, so it can't quietly ship.
if RunService:IsStudio() then
	task.defer(function()
		Theme.reportPendingIcons()
		Theme.reportPendingSounds()
	end)
end

return HudState
