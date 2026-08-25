--!strict
-- AdminClient.local.luau — admin panel UI (Job 031, on the design system in Job #075). Only builds for
-- allowlisted users. Pick a target (yourself or another player) and grant Gold / River Score / Salvage /
-- all modules / max skills. The server re-checks the allowlist on every action.
--
-- ⚠️ THIS CLAIMED "IDENTICAL COPY IN BOTH TREES" UNTIL JOB #117, AND IT WAS ALREADY FALSE.
-- The GAME copy (`sync/...`) has diverged ON PURPOSE and documents why in its own header: `tpFirstCamp`
-- (Job #107), `tpEndBase` (Job #114) and the Job #112 cheat toggles all need `Workspace.EndBase`, the boat
-- or the run, none of which exist in this place. The stale instruction was actively dangerous, because
-- this is the header you read if you open the LOBBY file first — and "copy to the other" in this
-- direction deletes ~280 lines of game-only tooling.
-- What must stay in step is the SHARED GRANTS: gold, river score, salvage, modules, skills, and the
-- Job #117 `m16Charge`. Nothing else.
--
-- Styled like everything else, but deliberately kept PLAIN: it is a dev tool, not a player-facing
-- screen, so it gets the design system's components and none of its flourish — no burst, no toast, no
-- celebratory sound on a grant. It should never be mistaken for something a player is meant to find.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
if not AdminDefs.isAdmin(player.UserId) then
	return -- not an admin → no UI at all
end

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local rf = ReplicatedStorage:WaitForChild("Admin") :: RemoteFunction

-- ── open button ──────────────────────────────────────────────────────────────────────────────────

local launcher = Components.screen("AdminLauncher", player:WaitForChild("PlayerGui"))
launcher.DisplayOrder = 60

-- Job #099: not on a phone. Admin is a desk tool — it is allowlist-gated dev UI, and on a 666x374
-- canvas its button sits in the bottom-right corner competing with the jump button for a control no
-- player will ever press. Desktop keeps it exactly as it was.
if game:GetService("UserInputService").TouchEnabled then
	launcher.Enabled = false
end

local openHolder = Instance.new("Frame")
openHolder.Name = "Holder"
openHolder.AnchorPoint = Vector2.new(1, 1)
-- Raised off the bottom-right corner: in the GAME place that corner is the driver's throttle cluster
-- (TouchControls). Sitting above it keeps an admin from fat-fingering a grant while steering.
openHolder.Position = UDim2.fromScale(0.98, 0.78)
openHolder.Size = UDim2.fromScale(0.1, 0.045)
openHolder.BackgroundTransparency = 1
openHolder.BorderSizePixel = 0

local openClamp = Instance.new("UISizeConstraint")
openClamp.MinSize = Vector2.new(90, 58) -- Job #095: 32 px was under the thumb floor (dev-only, but free)
openClamp.MaxSize = Vector2.new(170, 48)
openClamp.Parent = openHolder

openHolder.Parent = launcher

-- ── panel ────────────────────────────────────────────────────────────────────────────────────────

local panel = Components.panel({
	name = "AdminPanel",
	title = "Admin panel",
	icon = "wrench",
	size = UDim2.fromScale(0.46, 0.62),
	parent = player.PlayerGui,
})
panel.gui.DisplayOrder = 61

-- ── target selector (cycles Me + current players) ────────────────────────────────────────────────

local targets: { { name: string, userId: number } } = {}
local targetIdx = 1

local targetButton = Components.button({
	text = "TARGET: (LOADING…)",
	variant = "secondary",
	icon = "crew",
	size = UDim2.fromScale(1, 0.12),
	parent = panel.content,
	onActivated = function()
		if #targets == 0 then
			return
		end
		targetIdx = (targetIdx % #targets) + 1
	end,
})
targetButton.instance.Position = UDim2.fromScale(0, 0)

local function showTarget()
	local t = targets[targetIdx]
	targetButton.setText(if t then ("TARGET: %s  ›"):format(string.upper(t.name)) else "TARGET: —")
end

-- rebuilt each open: the player list changes between openings
local function refreshTargets()
	targets = { { name = player.DisplayName .. " (me)", userId = player.UserId } }
	local ok, res = pcall(function()
		return rf:InvokeServer("players")
	end)
	if ok and type(res) == "table" and res.players then
		for _, p in ipairs(res.players) do
			if p.userId ~= player.UserId then
				targets[#targets + 1] = { name = p.name, userId = p.userId }
			end
		end
	end
	if targetIdx > #targets then
		targetIdx = 1
	end
	showTarget()
end

-- The cycle handler above changes the index; the label follows it here rather than inside the handler,
-- so both the cycle and a refresh go through one place.
targetButton.instance.Activated:Connect(showTarget)

-- ── actions ──────────────────────────────────────────────────────────────────────────────────────

type AdminAction = { label: string, icon: string, kind: string?, amount: number?, action: string? }

local actions: { AdminAction } = {
	{ label = "+1000 Gold", icon = "coin", kind = "gold", amount = 1000 },
	{ label = "+10000 River Score", icon = "trophy", kind = "score", amount = 10000 },
	{ label = "+1000 Salvage (in-run)", icon = "salvage", kind = "salvage", amount = 1000 },
	{ label = "Unlock ALL Modules", icon = "boat", kind = "allModules", amount = 0 },
	{ label = "MAX ALL Skills", icon = "star", kind = "maxSkills", amount = 0 },
	-- Job #117. The LOBBY half of testing the M16: bank a per-run charge on the profile, launch a run, and
	-- check the gun arrives on the other side. There is deliberately no "give M16 now" here — this place
	-- has no loadout to put it in (see AdminServer: the lobby copy must not require InventoryService).
	{ label = "Bank M16 charge (next run)", icon = "rifle", kind = "m16Charge", amount = 1 },
	-- Job #118. ⚠️ Only the CHARGE half is here: there is no loadout in the lobby to grant a weapon into,
	-- and the game tree's "Give Bazooka" needs a ServerStorage this place does not map.
	{ label = "Bank Bazooka charge (next run)", icon = "rocketAmmo", kind = "bazookaCharge", amount = 1 },
	{ label = "TP to First Camp", icon = "pin", action = "tpFirstCamp" }, -- self-teleport (no target); Job 053
}

local list = Instance.new("ScrollingFrame")
list.Name = "Actions"
list.Position = UDim2.fromScale(0, 0.16)
list.Size = UDim2.fromScale(1, 0.84)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Theme.color.wood
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel.content

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.sm)
layout.Parent = list

for i, a in ipairs(actions) do
	local button
	button = Components.button({
		text = string.upper(a.label),
		variant = "gold",
		icon = a.icon,
		size = UDim2.new(1, 0, 0, 44),
		layoutOrder = i,
		parent = list,
		onActivated = function()
			button.setEnabled(false)
			button.setText("…")

			-- self-actions (e.g. teleport) take no target and close the panel so you see the result
			if a.action then
				pcall(function()
					rf:InvokeServer(a.action)
				end)
				button.setText(string.upper(a.label))
				button.setEnabled(true)
				panel.setOpen(false)
				return
			end

			local tgt = targets[targetIdx]
			if tgt then
				pcall(function()
					rf:InvokeServer("give", { targetUserId = tgt.userId, kind = a.kind, amount = a.amount })
				end)
			end
			button.setText(string.upper(a.label))
			button.setEnabled(true)
		end,
	})
end

-- The panel owns its own way out (X + tap-outside), so opening is all that's left to wire.
Components.button({
	text = "ADMIN",
	variant = "secondary",
	size = UDim2.fromScale(1, 1),
	parent = openHolder,
	onActivated = function()
		refreshTargets() -- the player list changes between openings
		panel.setOpen(true)
	end,
})
