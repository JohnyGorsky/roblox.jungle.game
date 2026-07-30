--!strict
-- RetentionClient.local.luau — LOBBY daily-reward popup + BOUNTIES panel (Job 028; restyled Job 065).
-- The daily reward is auto-granted server-side; this only NOTIFIES. Bounties are viewed and claimed here
-- through the `Weekly` RemoteFunction.
--
-- NAMING (Job 065): the feature is called **BOUNTIES** everywhere a player can see it — the building
-- sign, the entry button and this panel. It used to carry three different names (BOUNTIES on the
-- building, WEEKLY on the button, WEEKLY OBJECTIVES in the panel). INTERNAL ids are unchanged: the
-- OpenPanel id is still "weekly", the remote is still `Weekly`, and RetentionDefs is untouched — this is
-- a player-facing string change only, with no server or data migration.
--
-- Job 065 also adds: design system, panel/row icons, claim VFX + stinger, and an empty state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dailyRemote = ReplicatedStorage:WaitForChild("DailyReward") :: RemoteEvent
local weeklyRF = ReplicatedStorage:WaitForChild("Weekly") :: RemoteFunction

-- ── daily reward popup ────────────────────────────────────────────────────────────────────────────
-- Server-granted; this is purely the notification. Built on demand, destroyed on Collect.
dailyRemote.OnClientEvent:Connect(function(data)
	local daily = Components.panel({
		name = "DailyReward",
		title = "Daily reward",
		icon = "calendar",
		size = UDim2.fromScale(0.34, 0.36),
		parent = playerGui,
	})

	local streak = Instance.new("TextLabel")
	streak.Position = UDim2.fromScale(0, 0.04)
	streak.Size = UDim2.fromScale(1, 0.2)
	Components.applyText(streak, Theme.text.body, Theme.font.body)
	streak.TextColor3 = Theme.color.creamDim
	streak.Text = string.format("Day %d  ·  Streak %d", (data and data.day) or 1, (data and data.streak) or 1)
	streak.Parent = daily.content

	local amount = Instance.new("TextLabel")
	amount.Position = UDim2.fromScale(0, 0.28)
	amount.Size = UDim2.fromScale(1, 0.28)
	Components.applyText(amount, Theme.text.display, Theme.font.display)
	amount.TextColor3 = Theme.color.gold
	amount.Text = string.format("+ %d GOLD", (data and data.gold) or 0)
	amount.Parent = daily.content

	local collect = Components.button({
		text = "COLLECT",
		variant = "primary",
		size = UDim2.fromScale(0.5, 0.2),
		parent = daily.content,
		onActivated = function()
			daily.setOpen(false)
			task.defer(function()
				daily.gui:Destroy()
			end)
		end,
	})
	collect.instance.AnchorPoint = Vector2.new(0.5, 1)
	collect.instance.Position = UDim2.fromScale(0.5, 0.98)

	daily.setOpen(true)
	UISound.play("rank")
	Components.burst(daily.frame, Theme.color.gold)
end)

-- ── bounties panel ────────────────────────────────────────────────────────────────────────────────

local panel = Components.panel({
	name = "Bounties",
	title = "Bounties",
	icon = "bounty",
	size = UDim2.fromScale(0.56, 0.72),
	parent = playerGui,
})

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromScale(0, 0)
subtitle.Size = UDim2.fromScale(1, 0.07)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(subtitle, Theme.text.caption, Theme.font.body)
subtitle.TextColor3 = Theme.color.creamDim
subtitle.Text = "Resets weekly"
subtitle.Parent = panel.content

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Position = UDim2.fromScale(0, 0.09)
list.Size = UDim2.fromScale(1, 0.91)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Theme.color.wood
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.lg) -- row art breaks out of its row
layout.Parent = list
list.Parent = panel.content

local render: (objectives: { any }?) -> ()

render = function(objectives)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	-- empty state: say so, rather than rendering a blank box (audit gap B)
	if not objectives or #objectives == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.Size = UDim2.new(1, 0, 0, 60)
		Components.applyText(empty, Theme.text.body, Theme.font.body)
		empty.TextColor3 = Theme.color.creamDim
		empty.Text = "No bounties available right now."
		empty.Parent = list
		return
	end

	for index, o in ipairs(objectives) do
		local complete = o.progress >= o.target
		local claimable = complete and not o.claimed

		local row = Components.row({
			icon = o.claimed and "check" or (complete and "trophy" or "bounty"),
			title = o.name,
			blurb = string.format("+%d Gold  ·  +%d River Score", o.gold, o.score),
			actionText = o.claimed and "CLAIMED" or (complete and "CLAIM" or "IN PROGRESS"),
			variant = claimable and "gold" or "secondary",
			withBar = true,
			layoutOrder = index,
			parent = list,
		})
		row.instance.Size = UDim2.new(1, 0, 0, Theme.rowHeight + 6)

		local prog = math.min(o.progress, o.target)
		if row.bar then
			row.bar.setFill(prog / o.target, false)
			row.bar.setText(string.format("%d / %d", prog, o.target))
		end

		row.action.setEnabled(claimable)

		if claimable then
			row.action.instance.Activated:Connect(function()
				if not row.action.instance.Active then
					return
				end
				row.action.setText("…")
				row.action.setEnabled(false)

				local claimOk = pcall(function()
					weeklyRF:InvokeServer("claim", o.id)
				end)
				local ok, res = pcall(function()
					return weeklyRF:InvokeServer("list")
				end)

				if claimOk and ok then
					UISound.play("rank")
					Components.burst(row.instance, Theme.color.gold)
					Components.toast(playerGui, "trophy", "Bounty complete!", string.format("+%d Gold", o.gold))
				else
					UISound.play("fail")
					row.flashFail()
				end

				if ok and type(res) == "table" then
					render(res.objectives)
				end
			end)
		end
	end
end

local function openBounties()
	local ok, res = pcall(function()
		return weeklyRF:InvokeServer("list")
	end)
	render(ok and type(res) == "table" and res.objectives or nil)
	panel.setOpen(true)
end

-- kiosk (server) and client-side entry both open this panel; the id stays "weekly" internally
local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "weekly" then
		openBounties()
	end
end)
UIBus.onOpen(function(id)
	if id == "weekly" then
		openBounties()
	end
end)
