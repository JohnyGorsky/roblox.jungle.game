--!strict
-- IntroHudGate.local.luau — hide the in-run HUD during the plane intro (Job 055, todo 0010).
-- The objective banner + fuel/boat/cargo bars + hotbar + gold/salvage shouldn't show while you're flying in
-- on the plane — only once you WAKE UP at the crash site. While Workspace.IntroActive is true, this force-
-- hides the persistent HUD ScreenGuis + core GUI each frame (a LATE BindToRenderStep, so it wins over any
-- script that re-enables them → no flicker); when the intro ends it restores them once. Inert if there's no
-- intro (IntroActive never set).
--
-- It ALSO hides world-space BillboardGuis (Job 072). The MEDIC crate tag and the ROBUX SHOP kiosk tag are
-- `AlwaysOnTop = true`, so they render THROUGH the terrain and the fuselage — during the cold open you saw
-- them floating over the jungle from the plane. They're in Workspace, not PlayerGui, so the ScreenGui sweep
-- above never touched them. Disabling them here is client-local (no replication), so it can't disturb the
-- server's copies or other players.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- persistent in-run HUD elements to hide during the intro (transient/contextual GUIs are left alone).
-- DockShop carries the always-visible SALVAGE pill (not just the shop panel), so it's included.
local HUD = { "BoatHud", "GoldHud", "InventoryHud", "StagingHint", "RunGui", "UntieButton", "DockShop", "ObjectiveHud" }

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

-- ── world-space billboards ───────────────────────────────────────────────────────────────────────────
-- Only ones WE disabled are restored, so a billboard that was already off (or gets destroyed mid-intro)
-- is left exactly as we found it. A one-off scan plus a DescendantAdded hook covers billboards created
-- while the intro is still running — CargoServer and StartShopServer both build theirs at server start,
-- which can land after this script begins. A per-frame Workspace:GetDescendants() sweep would be the
-- obvious alternative and is far too expensive for a whole game world.
local hiddenBillboards: { BillboardGui } = {}
local billboardConn: RBXScriptConnection? = nil

local function hideBillboard(inst: Instance)
	if inst:IsA("BillboardGui") and inst.Enabled then
		inst.Enabled = false
		table.insert(hiddenBillboards, inst)
	end
end

local function setBillboardsHidden(hidden: boolean)
	if hidden then
		if billboardConn then
			return
		end
		for _, d in ipairs(Workspace:GetDescendants()) do
			hideBillboard(d)
		end
		billboardConn = Workspace.DescendantAdded:Connect(hideBillboard)
	else
		if billboardConn then
			billboardConn:Disconnect()
			billboardConn = nil
		end
		for _, bb in ipairs(hiddenBillboards) do
			if bb.Parent then
				bb.Enabled = true
			end
		end
		table.clear(hiddenBillboards)
	end
end

local wasIntro = false

RunService:BindToRenderStep("IntroHudGate", Enum.RenderPriority.Last.Value, function()
	local intro = Workspace:GetAttribute("IntroActive") == true
	if intro then
		setHudEnabled(false) -- re-assert hidden each frame (overrides any HUD re-enabling), cheap
	end
	if intro ~= wasIntro then
		setCore(not intro) -- toggle core GUI once on the transition
		setBillboardsHidden(intro)
		if not intro then
			setHudEnabled(true) -- intro just ended (wake-up) → restore the HUD once
		end
		wasIntro = intro
	end
end)
