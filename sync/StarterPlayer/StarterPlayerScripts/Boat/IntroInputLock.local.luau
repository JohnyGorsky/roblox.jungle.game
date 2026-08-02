--!strict
-- IntroInputLock.local.luau — take the controls away for the plane intro (Job 072).
--
-- Players could press jump while strapped into the plane, which UNSEATS the character and drops them
-- into the jungle mid-flight. `PlaneServer.lockPassenger` disables the Humanoid's Jumping state as the
-- authoritative fix; this script is the front half of the same lock — it sinks the input on the client
-- so the jump never fires at all, which also kills the mobile jump button and any control-scheme
-- rebinds. Movement is sunk too: "disable input till we land".
--
-- Runs only while `Workspace.IntroActive` is true, and hands the controls straight back at the wake-up.
-- Inert if there's no intro (IntroActive never set), so the normal spawn path is untouched.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local ACTION = "IntroInputLock"

-- PlayerActions cover the bound gameplay controls (keyboard, gamepad AND the touch buttons) rather than
-- raw KeyCodes, so this holds regardless of the player's device or control scheme.
local BLOCKED = {
	Enum.PlayerActions.CharacterJump,
	Enum.PlayerActions.CharacterForward,
	Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft,
	Enum.PlayerActions.CharacterRight,
}

local locked = false

local function sink(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function setLocked(on: boolean)
	if on == locked then
		return
	end
	locked = on
	if on then
		-- `true` for createTouchButton would ADD an on-screen button; we want the opposite, so it's false
		ContextActionService:BindActionAtPriority(ACTION, sink, false, Enum.ContextActionPriority.High.Value, table.unpack(BLOCKED))
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

-- wait briefly for the server to claim the intro; if there's none, never touch the controls
local t0 = os.clock()
while Workspace:GetAttribute("IntroActive") == nil and os.clock() - t0 < 5 do
	task.wait()
end
if not Workspace:GetAttribute("IntroActive") then
	return
end

setLocked(true)

Workspace:GetAttributeChangedSignal("IntroActive"):Connect(function()
	setLocked(Workspace:GetAttribute("IntroActive") == true)
end)

-- Safety net: if the character is ever replaced (death/respawn) or the player leaves mid-intro, the
-- binding must not outlive the intro — a stuck sink would leave the player unable to move at the camp.
player.CharacterAdded:Connect(function()
	setLocked(Workspace:GetAttribute("IntroActive") == true)
end)
