--!strict
-- IntroHudGate.local.luau — hide the in-run HUD during the plane intro (Job 055, todo 0010).
-- The objective banner + fuel/boat/cargo bars + hotbar + gold/salvage shouldn't show while you're flying in
-- on the plane — only once you WAKE UP at the crash site. While Workspace.IntroActive is true, this force-
-- hides the persistent HUD ScreenGuis + core GUI each frame (a LATE BindToRenderStep, so it wins over any
-- script that re-enables them → no flicker); when the intro ends it restores them once. Inert if there's no
-- intro (IntroActive never set).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- persistent in-run HUD elements to hide during the intro (transient/contextual GUIs are left alone)
local HUD = { "BoatHud", "GoldHud", "InventoryHud", "StagingHint", "RunGui", "UntieButton" }

local function setHudEnabled(enabled: boolean)
	for _, name in HUD do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") then
			g.Enabled = enabled
		end
	end
end

local function setCore(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, enabled)
	end)
end

local wasIntro = false

RunService:BindToRenderStep("IntroHudGate", Enum.RenderPriority.Last.Value, function()
	local intro = Workspace:GetAttribute("IntroActive") == true
	if intro then
		setHudEnabled(false) -- re-assert hidden each frame (overrides any HUD re-enabling), cheap
	end
	if intro ~= wasIntro then
		setCore(not intro) -- toggle core GUI once on the transition
		if not intro then
			setHudEnabled(true) -- intro just ended (wake-up) → restore the HUD once
		end
		wasIntro = intro
	end
end)
