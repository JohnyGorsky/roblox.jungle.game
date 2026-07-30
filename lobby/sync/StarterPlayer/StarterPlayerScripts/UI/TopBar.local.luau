--!strict
-- TopBar.local.luau — the lobby's persistent HUD bar (Job 065, STYLEGUIDE §6.3).
--
-- Replaces the lobby's old GoldHud (a bare gold pill). Shows: avatar · name · RANK TIER · River Score
-- progress to the next tier · Gold chip · a `+` that opens the Robux shop.
--
-- RANK, NOT XP: §6.3 sketches a LEVEL nn + XP bar, but this game has no XP or levels. It has River
-- Score driving the RankDefs ladder, so the bar is fed from that instead of inventing a system
-- (intake decision #6). At River Legend there is no next tier, so RankDefs.progressFor switches to
-- progress toward the next prestige star.
--
-- DELIBERATE DIVERGENCE: the game-place `sync/.../GoldHud.local.luau` stays a plain gold readout and is
-- NOT kept identical to this file. In-run HUD is mandatory-info-only (§6.11) — rank belongs in the
-- lobby, not on screen while you're fighting the river.
--
-- Data is read from replicated player attributes (`Gold`, `RiverScore`) that Profiles mirrors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local UIBus = require(UI:WaitForChild("UIBus"))
local RankDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("RankDefs")) :: any

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Components.screen("TopBar", playerGui)
gui.DisplayOrder = 2

-- ── left cluster: avatar · name · tier · progress ─────────────────────────────────────────────────

local left = Instance.new("Frame")
left.Name = "Identity"
left.Position = UDim2.fromScale(0.012, 0.02)
left.Size = UDim2.fromScale(0.3, 0.085)
left.BackgroundColor3 = Theme.color.panel
left.BackgroundTransparency = 0.15
left.BorderSizePixel = 0
Components.corner(Theme.radius.control, left)
Components.stroke(Theme.color.wood, Theme.strokeWidth.control, left)

local sizeClamp = Instance.new("UISizeConstraint")
sizeClamp.MinSize = Vector2.new(210, 52)
sizeClamp.MaxSize = Vector2.new(460, 104)
sizeClamp.Parent = left

-- avatar, framed (§6.3 "circular avatar (framed)")
local avatarHolder = Instance.new("Frame")
avatarHolder.Name = "Avatar"
avatarHolder.AnchorPoint = Vector2.new(0, 0.5)
avatarHolder.Position = UDim2.fromScale(0.02, 0.5)
avatarHolder.Size = UDim2.fromScale(0.9, 0.78)
avatarHolder.BackgroundColor3 = Theme.color.sunken
avatarHolder.BorderSizePixel = 0
Components.corner(Theme.radius.pill, avatarHolder)
Components.stroke(Theme.color.gold, Theme.strokeWidth.control, avatarHolder)
local avatarRatio = Instance.new("UIAspectRatioConstraint")
avatarRatio.AspectRatio = 1
avatarRatio.Parent = avatarHolder

local avatar = Instance.new("ImageLabel")
avatar.Name = "Image"
avatar.Size = UDim2.fromScale(1, 1)
avatar.BackgroundTransparency = 1
avatar.BorderSizePixel = 0
Components.corner(Theme.radius.pill, avatar)
avatar.Parent = avatarHolder
avatarHolder.Parent = left

-- GetUserThumbnailAsync yields and can fail (offline/moderation) — never let it break the bar
task.spawn(function()
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok and content then
		avatar.Image = content
	end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "PlayerName"
nameLabel.Position = UDim2.fromScale(0.2, 0.1)
nameLabel.Size = UDim2.fromScale(0.62, 0.34)
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(nameLabel, Theme.text.h2, Theme.font.bodyBold)
nameLabel.Text = player.DisplayName
nameLabel.Parent = left

-- tier colour dot + tier name. The ladder's colours (teal/purple/magenta) are outside the §4 palette,
-- so the NAME stays cream and the ladder colour appears only as a small accent dot. Flagged for review
-- at the phase-2 gate — swapping to a fully tier-coloured name is a one-line change.
local tierDot = Instance.new("Frame")
tierDot.Name = "TierDot"
tierDot.AnchorPoint = Vector2.new(0, 0.5)
tierDot.Position = UDim2.fromScale(0.2, 0.62)
tierDot.Size = UDim2.fromScale(0.028, 0.16)
tierDot.BackgroundColor3 = Theme.color.gold
tierDot.BorderSizePixel = 0
Components.corner(Theme.radius.pill, tierDot)
local dotRatio = Instance.new("UIAspectRatioConstraint")
dotRatio.AspectRatio = 1
dotRatio.Parent = tierDot
tierDot.Parent = left

local tierLabel = Instance.new("TextLabel")
tierLabel.Name = "Tier"
tierLabel.Position = UDim2.fromScale(0.245, 0.46)
tierLabel.Size = UDim2.fromScale(0.58, 0.3)
tierLabel.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(tierLabel, Theme.text.caption, Theme.font.bodyBold)
tierLabel.Text = "—"
tierLabel.Parent = left

local rankBar = Components.progressBar(left)
rankBar.instance.Position = UDim2.fromScale(0.2, 0.8)
rankBar.instance.Size = UDim2.fromScale(0.76, 0.13)

-- ── right cluster: Gold chip + `+` ────────────────────────────────────────────────────────────────

-- The cluster is a fixed-height, right-anchored strip. The chip sizes ITSELF to its number
-- (Components.chip measures the text), and the `+` is then placed to the chip's left. Everything is
-- laid out explicitly from the strip's height — no AutomaticSize and no aspect constraints, which
-- collapse to zero when their driving axis isn't resolved yet.
local right = Instance.new("Frame")
right.Name = "Currency"
right.AnchorPoint = Vector2.new(1, 0)
right.Position = UDim2.fromScale(0.988, 0.02)
right.Size = UDim2.fromScale(0.3, 0.07)
right.BackgroundTransparency = 1
right.BorderSizePixel = 0

local goldChip = Components.chip("coin", right)
goldChip.instance.AnchorPoint = Vector2.new(1, 0.5)
-- final X set in layoutCluster(), which parks it left of the `+`

-- `+` → the Robux shop. A convenience affordance, not a power sale (GAME.md: paid = convenience), so it
-- sits beside the balance as a small square — deliberately quieter than the balance itself.
local plus = Components.button({
	text = "+",
	variant = "gold",
	size = UDim2.fromOffset(36, 36),
	sound = "open",
	parent = right,
	onActivated = function()
		UIBus.open("robux")
	end,
})
plus.instance.AnchorPoint = Vector2.new(1, 0.5)

-- keep the `+` square, proportional to the strip, and tucked just left of the chip as it grows
local function placePlus()
	local height = right.AbsoluteSize.Y
	if height <= 0 then
		return
	end
	local side = math.floor(height * 0.72)
	plus.instance.Size = UDim2.fromOffset(side, side)
	plus.instance.Position = UDim2.new(1, -goldChip.instance.AbsoluteSize.X - Theme.space.sm, 0.5, 0)
end
right:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlus)
goldChip.instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlus)
task.defer(placePlus)

right.Parent = gui
left.Parent = gui

-- ── data ──────────────────────────────────────────────────────────────────────────────────────────

local function formatNumber(n: number): string
	-- 25450 -> "25,450"; keeps long balances readable at a glance
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	formatted = formatted:gsub("^,", "")
	return formatted
end

local function renderGold()
	local gold = player:GetAttribute("Gold")
	goldChip.setValue(formatNumber(typeof(gold) == "number" and gold or 0))
end

local function renderRank()
	local score = player:GetAttribute("RiverScore")
	score = typeof(score) == "number" and score or 0

	local tier = RankDefs.tierFor(score)
	local alpha, into, span = RankDefs.progressFor(score)
	local nextTier = RankDefs.nextTierFor(score)

	tierDot.BackgroundColor3 = tier.color
	tierLabel.Text = string.upper(tier.name)
	rankBar.setFill(alpha)

	if nextTier then
		rankBar.setText(string.format("%s / %s to %s", formatNumber(into), formatNumber(span), nextTier.name))
	else
		local stars = RankDefs.legendStars(score)
		rankBar.setText(string.format("%s ★  ·  %s / %s to next", tostring(stars), formatNumber(into), formatNumber(span)))
	end
end

player:GetAttributeChangedSignal("Gold"):Connect(renderGold)
player:GetAttributeChangedSignal("RiverScore"):Connect(renderRank)
renderGold()
renderRank()

-- warm the sound cache so the first tap isn't silent
require(UI:WaitForChild("UISound")).preload()
