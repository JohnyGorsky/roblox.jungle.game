--!strict
-- LobbyClient.local.luau — lobby hint banner (Job 017; restyled to the design system in Job 065).
-- The pad signs + Start prompt are server-built; this is the short instruction that tells a new player
-- what the airfield is for.
--
-- Styled as a wood-bordered field notice (§6.1) rather than a floating dark slab, with the party icon so
-- it reads at a glance. Informational only — it never blocks input (§6.11).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Components.screen("LobbyHint", playerGui)
gui.DisplayOrder = 1

local panel = Instance.new("Frame")
panel.Name = "Hint"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.02)
-- ⚠️ Job #095 — 0.32, not 0.44. At 0.44 this panel spanned x 0.28–0.72 and the TopBar identity block
-- reaches x 0.312, so the two overlapped by up to 42x63 px on a phone. Both are opaque, so it was real
-- paint over paint — and it is INVISIBLE at desktop aspect (both hit their MaxSize caps and the gap
-- reopens), which is exactly why it shipped. 0.32 spans 0.34–0.66, clearing the identity block by ~0.028.
--
-- This panel yields rather than the top bar because it is a transient instruction with no tap targets,
-- whereas the bar carries the avatar, name, tier and the `+` button. Same test Job #094 used: never
-- shrink the side that holds the tap targets.
--
-- ⚠️ Job #099 — HEIGHT raised 0.085 -> 0.115, because #095's narrowing above had a consequence it did
-- not check. `applyText` sets TextScaled with a 12 px MinTextSize FLOOR, so text cannot shrink its way
-- out of a box that is too small — it wraps, and anything past the box is simply cut. Narrowing the
-- panel from 0.44 to 0.32 made the title wrap to two lines, and 0.085 only had room for one. Reported
-- from a real phone as "STEP ON A LAUNCH PAD TO" / "First on a pad leads — hold Start to launch the",
-- both severed mid-sentence.
--
-- #095 checked that the narrowed panel no longer COLLIDED. It never checked that the text still FIT.
panel.Size = UDim2.fromScale(0.32, 0.115)
panel.BackgroundColor3 = Theme.color.panel
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Active = false -- informational: never eats a tap
Components.corner(Theme.radius.panel, panel)
Components.stroke(Theme.color.wood, Theme.strokeWidth.control, panel)

local sizeClamp = Instance.new("UISizeConstraint")
-- Job #099: the height floor rises with it. 54 px could not hold two wrapped lines at the 12 px text
-- floor; 96 px can. This is the clamp that actually bites on a phone, where the scale value resolves
-- smaller than the floor.
sizeClamp.MinSize = Vector2.new(260, 96)
sizeClamp.MaxSize = Vector2.new(760, 150)
sizeClamp.Parent = panel

local icon = Components.icon({ name = "party", size = UDim2.fromScale(0.09, 0.62), parent = panel })
icon.AnchorPoint = Vector2.new(0, 0.5)
icon.Position = UDim2.fromScale(0.025, 0.5)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromScale(0.14, 0.12)
title.Size = UDim2.fromScale(0.82, 0.42)
title.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(title, Theme.text.h2, Theme.font.heading)
title.TextColor3 = Theme.color.gold -- an accent that means "do this" (§4)
title.Text = "STEP ON A LAUNCH PAD TO FORM A PARTY"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Name = "Subtitle"
sub.Position = UDim2.fromScale(0.14, 0.55)
sub.Size = UDim2.fromScale(0.82, 0.34)
sub.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(sub, Theme.text.caption, Theme.font.body)
sub.TextColor3 = Theme.color.creamDim
sub.Text = "First on a pad leads — hold Start to launch the run (up to 6)"
sub.Parent = panel

panel.Parent = gui
