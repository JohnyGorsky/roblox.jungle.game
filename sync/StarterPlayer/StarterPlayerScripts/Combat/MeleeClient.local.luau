--!strict
-- MeleeClient.local.luau — tap-to-swing when the Sword is the active item (Job 015).
--
-- Only requests a swing when the active loadout item is the Sword; the guns are handled by WeaponClient.
-- The server does all validation + hit detection (see MeleeServer). This also plays a quick local swing
-- ARC so the swing reads clearly — greybox demo feedback; a real rigged animation is a later pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")


local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SwordSwing") :: RemoteEvent

local SWING_TIME = 0.22
local swinging = false

local function swordActive(): boolean
	if player:GetAttribute("ActiveItem") ~= "Axe" or player:GetAttribute("Busy") == true then
		return false
	end
	-- can't swing while driving the boat or manning the mounted gun
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and (hum.SeatPart.Name == "DriverSeat" or hum.SeatPart.Name == "GunSeat") then
		return false
	end
	return true
end

-- Gate one swing per input. The VISUALS live on the server now (real model + slash animation +
-- whoosh, Job #079); this only stops a held mouse button firing the remote every frame.
local function beginSwing()
	if swinging then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return
	end
	swinging = true

	-- ⚠️ THE CREAM NEON ARC IS GONE (Job #079), and it should not come back.
	--
	-- Job #075 drew a 0.25 x 4 x 0.6 `SwingFx` slab in `Theme.color.cream`, Material Neon, swept across
	-- the front on every swing. That was a GREYBOX stand-in for swing feedback at a time when the melee
	-- was an invisible-ish coloured stick with no animation and no sound.
	--
	-- All three of those now exist: the axe has a real model, alternating `slash1`/`slash2` animations on
	-- the character's own Animator, and an `AxeSwing` whoosh. The slab is not just redundant on top of
	-- them, it reads in play as "a white object flying past" — which is exactly how it was reported.
	--
	-- The timer below still runs, because `swinging` gates the input so one tap is one swing.
	task.delay(SWING_TIME, function()
		swinging = false
	end)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- tap landed on a GUI button (e.g. the hotbar)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if swordActive() then
			remote:FireServer()
			beginSwing()
		end
	end
end)
