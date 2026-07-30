--!strict
-- SkillShop.local.luau — LOBBY skill-tree UI (Job 024; restyled to the design system in Job 065).
-- Lists the 10 skills grouped Boat / Crew with level (n/10), the next level's Gold cost, and the per-level
-- stat gain. Buys go through the `Skills` RemoteFunction; the server validates and persists.
--
-- Job 065 changes:
--   · design system (Theme/Components) — no colour or font literals here
--   · per-skill icons + Boat/Crew group headers (ONE shop, two groups — plan decision F; the mockup's
--     "gold shop vs small shop" split does not exist in the data)
--   · a progress bar per skill (level n of MAX_LEVEL), not just text
--   · `+%` stat delta shown per §6.5 (SkillDefs already carries `per` and `unit`)
--   · CONFIRM POPUP before Gold is spent — the job's one deliberate behaviour change. The server
--     contract is untouched: the popup only gates when the client calls InvokeServer("buy").
--   · sound + VFX on every outcome (§12 juice rule): purchase/upgrade cue + toast on success,
--     fail cue + a visible row flash on refusal
--
-- The server remains authoritative — it re-checks gold and level and can still refuse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UISound = require(UI:WaitForChild("UISound"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any
local rf = ReplicatedStorage:WaitForChild("Skills") :: RemoteFunction

local panel = Components.panel({
	name = "SkillShop",
	title = "Skills",
	icon = "star",
	size = UDim2.fromScale(0.56, 0.8),
	parent = playerGui,
})

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Size = UDim2.fromScale(1, 1)
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

type RowEntry = { refresh: (gold: number, level: number) -> () }
local rows: { [string]: RowEntry } = {}
local refreshAll: (gold: number, skills: { [string]: number }) -> ()

local order = 0

local function header(text: string, iconKey: string)
	order += 1
	local holder = Instance.new("Frame")
	holder.Name = "Header_" .. text
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, 34)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0

	local ico = Components.icon({ name = iconKey, size = UDim2.fromScale(0.06, 1), parent = holder })
	ico.AnchorPoint = Vector2.new(0, 0.5)
	ico.Position = UDim2.fromScale(0.005, 0.5)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.075, 0)
	label.Size = UDim2.fromScale(0.7, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Components.applyText(label, Theme.text.h2, Theme.font.heading)
	label.TextColor3 = Theme.color.creamDim
	label.Text = string.upper(text) .. " SKILLS"
	label.Parent = holder

	holder.Parent = list
end

local function makeRow(id: string)
	local def = SkillDefs.get(id)
	if not def then
		return
	end

	order += 1
	local row = Components.row({
		icon = (Theme.skillIcon :: { [string]: string })[id],
		title = def.name,
		blurb = def.blurb,
		actionText = "…",
		withBar = true,
		layoutOrder = order,
		parent = list,
	})
	row.instance.Size = UDim2.new(1, 0, 0, Theme.rowHeight)

	local currentLevel = 0

	local function refresh(gold: number, level: number)
		currentLevel = level
		-- §6.5: show the gain, not just the level — SkillDefs already carries per/unit
		row.setBlurb(string.format("%s   ·   +%s%s per level", def.blurb, tostring(def.per), def.unit))
		if row.bar then
			row.bar.setFill(level / SkillDefs.MAX_LEVEL)
			row.bar.setText(string.format("Lv %d / %d", level, SkillDefs.MAX_LEVEL))
		end

		if level >= SkillDefs.MAX_LEVEL then
			row.action.setText("MAX")
			row.action.setEnabled(false)
			return
		end

		local cost = SkillDefs.cost(level + 1)
		row.action.setText(string.format("%d G", cost))
		row.action.setEnabled(gold >= cost)
	end

	local function commitBuy()
		row.action.setText("…")
		local ok, res = pcall(function()
			return rf:InvokeServer("buy", id)
		end)
		if ok and type(res) == "table" and res.gold ~= nil then
			local newLevel = ((res.skills or {})[id] :: number?) or currentLevel
			local bought = newLevel > currentLevel
			refreshAll(res.gold, res.skills or {})
			if bought then
				UISound.play("upgrade")
				Components.burst(row.instance, Theme.color.gold)
				Components.toast(playerGui, (Theme.skillIcon :: { [string]: string })[id], "Skill upgraded!", string.format("%s  Lv %d", def.name, newLevel))
			else
				-- server refused (gold changed under us, level cap, etc.)
				UISound.play("fail")
				row.flashFail()
			end
		else
			UISound.play("fail")
			row.flashFail()
			refreshAll((player:GetAttribute("Gold") :: number?) or 0, {})
		end
	end

	-- Gold is only ever spent behind a confirm (Job 065 decision)
	row.action.instance.Activated:Connect(function()
		if not row.action.instance.Active then
			return
		end
		if currentLevel >= SkillDefs.MAX_LEVEL then
			return
		end
		local cost = SkillDefs.cost(currentLevel + 1)
		Components.confirm({
			parent = playerGui,
			icon = (Theme.skillIcon :: { [string]: string })[id],
			title = def.name,
			body = string.format("Upgrade to level %d  ·  +%s%s", currentLevel + 1, tostring(def.per), def.unit),
			costText = string.format("%d GOLD", cost),
			onConfirm = commitBuy,
		})
	end)

	rows[id] = { refresh = refresh }
end

refreshAll = function(gold: number, skills: { [string]: number })
	for id, entry in pairs(rows) do
		entry.refresh(gold, (skills[id] :: number?) or 0)
	end
end

-- group headers in SkillDefs.Order sequence, so Boat skills then Crew skills
local seenGroup: { [string]: boolean } = {}
for _, id in ipairs(SkillDefs.Order) do
	local def = SkillDefs.get(id)
	if def and not seenGroup[def.group] then
		seenGroup[def.group] = true
		header(def.group, (Theme.groupIcon :: { [string]: string })[def.group] or "star")
	end
	makeRow(id)
end

local function openShop()
	local ok, res = pcall(function()
		return rf:InvokeServer("list")
	end)
	local gold = (ok and type(res) == "table" and res.gold) or (player:GetAttribute("Gold") :: number?) or 0
	local skills = (ok and type(res) == "table" and res.skills) or {}
	refreshAll(gold, skills)
	panel.setOpen(true)
end

-- kiosk (server) and client-side entry both open this panel
local openPanel = ReplicatedStorage:WaitForChild("OpenPanel") :: RemoteEvent
openPanel.OnClientEvent:Connect(function(which)
	if which == "skills" then
		openShop()
	end
end)
UIBus.onOpen(function(id)
	if id == "skills" then
		openShop()
	end
end)
