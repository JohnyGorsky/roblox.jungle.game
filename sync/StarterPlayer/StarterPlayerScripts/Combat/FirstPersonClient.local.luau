--!strict
-- FirstPersonClient.local.luau — make first person usable (Job #092).
--
-- Two complaints, one place, because they are both "what the local player sees of themselves":
--
--   1. *"mouse and cursor is in same place"* — Roblox draws the OS mouse icon pinned to the centre of
--      the screen in first person, directly on top of our own crosshair. Two pointers, one of them
--      meaningless. The icon is hidden; the game's reticle is the only pointer.
--
--   2. *"maybe we can show like weapon?"* — the weapon is INVISIBLE in first person, and the reason is
--      structural rather than a missing feature:
--
--      🔴 Roblox blanks the local character in first person by setting `LocalTransparencyModifier` on
--      its parts. It makes an exception for a `Tool`'s `Handle` — which is how every stock FPS shows
--      its weapon. **Our held item is not a Tool.** `HeldPose` documents that decision at length
--      (a real Tool drags in the Backpack UI under our own hotbar, drop-on-Backspace, and
--      `Tool.Activated` racing `MeleeClient`) and it is the right call — but it means `HeldItem`, a
--      plain welded Part, is treated as ordinary character geometry and vanishes with the rest of it.
--
--      So the exception has to be re-applied by hand: force `LocalTransparencyModifier = 0` on
--      `HeldItem` and on the right arm every frame, and the axe/pistol/shotgun show up in view held in
--      a visible hand. `LocalTransparencyModifier` is client-only and affects nobody else's screen.
--
-- ⚠️ EVERY FRAME, not once. Roblox re-applies the character's transparency continuously while the
-- camera is in first person, so a one-off write is gone by the next frame. This is the same shape as
-- the fix in `GunClient`, which already does exactly this for the turret camera.
--
-- ⚠️ The UI owns the mouse when a panel is open. `InputMode.uiOpen()` is checked before touching the
-- icon so this never fights `Components.panel` for it — that panel-open path is what makes the shop
-- closable in first person at all, and quietly re-hiding the cursor here would undo it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputMode = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("InputMode"))

local player = Players.LocalPlayer

-- The right arm holds the item (`HeldGrip` is a Motor6D to `RightHand`), so these are the parts that
-- have to stay visible for the weapon to read as *held* rather than floating.
-- R15 names; a missing one is simply skipped, so an R6 character degrades to "weapon visible, no arm".
local ARM_PARTS = { "RightHand", "RightLowerArm", "RightUpperArm" }

local iconHidden = false

local function setIconHidden(hide: boolean)
	if iconHidden == hide then
		return -- don't write UserInputService every frame; it is a global and other systems read it
	end
	iconHidden = hide
	UserInputService.MouseIconEnabled = not hide
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then
		setIconHidden(false)
		return
	end

	-- A panel is up: the mouse belongs to the UI, and `InputMode` has already forced the camera out of
	-- first person so the pointer can reach the close button. Nothing to do here.
	if InputMode.uiOpen() then
		setIconHidden(false)
		return
	end

	if not InputMode.isFirstPerson() then
		setIconHidden(false)
		return
	end

	setIconHidden(true)

	-- Re-assert visibility on the weapon and the hand holding it (see the header: Roblox clears these
	-- every frame in first person, and only makes an exception for a real Tool's Handle).
	local held = char:FindFirstChild("HeldItem")
	if held then
		if held:IsA("BasePart") then
			held.LocalTransparencyModifier = 0
		end
		for _, d in ipairs(held:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
	for _, name in ipairs(ARM_PARTS) do
		local limb = char:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limb.LocalTransparencyModifier = 0
		end
	end
end)

-- Leaving first person (or dying) must hand the cursor back, even if the loop above stops matching.
player.CharacterRemoving:Connect(function()
	setIconHidden(false)
end)
