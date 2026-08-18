--!strict
-- TouchFire.luau — the shared on-screen FIRE control for touch (Job #096, finding #0006).
--
-- ── Why this exists ───────────────────────────────────────────────────────────────────────────────
-- Both combat clients used to fire on any `Touch` `InputBegan`. On a phone, dragging to look around IS
-- a touch, so the camera and the trigger were the same gesture and every look cost a round of the
-- boat's shared, scavenged ammo. Job #096 makes aiming a DRAG (`GunClient`, finding #0007), which makes
-- a tap/drag discriminator the only thing separating look from shoot — so the trigger gets its own
-- button instead, and the ambiguity disappears.
--
-- ── Why a module, and why it is local ─────────────────────────────────────────────────────────────
-- Two different scripts need the same button: `GunClient` (mounted turret) and `WeaponClient`
-- (handheld). One button shared between them beats two that must be kept in the same corner by hand.
-- Same reasoning and same shape as `UI/UIBus` — a purely LOCAL BindableEvent. Round-tripping through
-- the server so two client scripts can talk would add latency and hand an exploiter a remote, for
-- nothing. The actual shot still goes through each client's own server remote, unchanged.
--
-- ── Why both clients may connect at once ──────────────────────────────────────────────────────────
-- They cannot both act. `WeaponServer.canShoot` refuses a handheld shot from the driver's seat, the
-- GunSeat, or while Busy; `GunClient` only fires while seated at the turret; `WeaponClient.fire`
-- self-gates on `reticleShown()`. The roles are mutually exclusive by the server's own rules, so both
-- listeners can stay connected and exactly one will do anything. Visibility is ref-counted per owner
-- for the same reason: whoever currently wants the trigger asks for it, and the button is up if anyone
-- does.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UI = ReplicatedStorage:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components"))
local RunComponents = require(script.Parent:WaitForChild("RunComponents"))

local TouchFire = {}

local event = Instance.new("BindableEvent")
event.Name = "TouchFirePressed"

-- Optional value, not plain boolean: `setVisible(owner, false)` REMOVES the entry rather than storing
-- false, so the "does anyone want the trigger" scan below stays a plain truthiness check.
local owners: { [string]: boolean? } = {}
local holder: Frame? = nil

-- Nothing is built on a device that can't touch — a keyboard player must not pay for this at all, and
-- must keep their existing mouse trigger untouched.
local function build(): Frame?
	if not UserInputService.TouchEnabled then
		return nil
	end
	if holder then
		return holder
	end

	local player = Players.LocalPlayer
	local gui = Components.screen("TouchFire", player:WaitForChild("PlayerGui"))
	-- Same order as the driving controls: above the readouts, below banners and modals.
	gui.DisplayOrder = 9

	local frame = Instance.new("Frame")
	frame.Name = "Fire"
	-- Deliberately the THROTTLE's footprint (see TouchControls). Driving and shooting are mutually
	-- exclusive, so this corner is free whenever the trigger is up — and reusing the exact rectangle
	-- means the right thumb always rests in the same place, and the overlap harness only has to prove
	-- one geometry rather than two.
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.fromScale(0.98, 0.96)
	frame.Size = UDim2.fromScale(0.19, 0.16)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	-- Fire on PRESS, not on release, and one shot per tap: this mirrors what a click already does on PC
	-- rather than inventing hold-to-autofire, which would be a balance change smuggled in as a control.
	local button = RunComponents.touchButton("◉", function()
		event:Fire()
	end, function() end, frame)
	-- `touchButton` sizes itself 0.48 wide for the steer/throttle PAIRS. This one is alone, so it takes
	-- the whole holder; its UIAspectRatioConstraint keeps it square.
	button.instance.Size = UDim2.fromScale(1, 1)

	holder = frame
	return frame
end

local function refresh()
	local frame = build()
	if not frame then
		return
	end
	local any = false
	for _, wants in pairs(owners) do
		if wants then
			any = true
			break
		end
	end
	frame.Visible = any
end

-- Ask for the trigger to be on screen. `owner` is the requesting script's own name, so two callers
-- can't clobber each other's state.
function TouchFire.setVisible(owner: string, visible: boolean)
	owners[owner] = visible or nil
	refresh()
end

-- Listen for a trigger pull. The callback is responsible for its own gating (ammo, seat, Busy) exactly
-- as the mouse path already is — this module decides WHEN THE BUTTON IS UP, never whether a shot is legal.
function TouchFire.onFire(fn: () -> ()): RBXScriptConnection
	return event.Event:Connect(fn)
end

-- True when this control is the active trigger, so a client can skip its legacy tap-anywhere path
-- without having to re-derive whether the device is touch.
function TouchFire.isActive(): boolean
	return UserInputService.TouchEnabled
end

return TouchFire
