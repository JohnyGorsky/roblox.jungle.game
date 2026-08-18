--!strict
-- InventoryHud.local.luau — the loadout hotbar (Job 015, restyled onto the design system in Job #075).
--
-- Mobile-first, scale-based. One row of slot buttons at the bottom-left: tap a slot to equip it (one
-- item active at a time). The active slot is highlighted; guns show their ammo. Reads the player's
-- replicated inventory attributes (Slot1..N / ActiveSlot / ActiveItem / Ammo*). Keyboard 1-N + Q (drop)
-- are conveniences for Studio testing.
--
-- Job 067: the bar is 4 slots by default and 6 with the Extra Inventory Slots pass. ALL slot buttons are
-- built up front and the surplus ones are hidden, because `Owns_extraSlots` arrives asynchronously
-- (UserOwnsGamePassAsync on join) and can land after this script has already drawn — so the bar must
-- react to it changing rather than sample it once at startup.
--
-- Job #075: slots are `RunComponents.slot` (icon art, not the item's name as button text), and the
-- "HANDS FULL" banner became a warning card that no longer overlaps the first slot at phone widths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local RunUI = ReplicatedStorage:WaitForChild("RunUI")
local RunComponents = require(RunUI:WaitForChild("RunComponents"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("InventoryCmd") :: RemoteEvent
local MAX_SLOTS = ItemDefs.MAX_SLOTS

local TOUCH = UserInputService.TouchEnabled

local function visibleSlots(): number
	return ItemDefs.slotsFor(player)
end

local gui = Components.screen("InventoryHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local bar = Instance.new("Frame")
bar.Name = "Hotbar"
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.fromScale(0.015, 0.975)
-- ⚠️ Job #099 — on touch the hotbar slides RIGHT, out of the movement thumbstick. Measured on a real
-- touch canvas (666x316): the stick owns x 29..103, y 223..297, and the hotbar sat at x 10..250,
-- y 262..308 — slots 1 and 2 were literally underneath the player's left thumb. 0.225 puts its left edge
-- at x=150, clear of the stick, and it still ends well short of the fire button at x=526.
if UserInputService.TouchEnabled then
	-- ⚠️ Corrected in the same job: 0.225 (x=150) was measured against `ThumbstickStart`, the stick's
	-- RESTING dot at x 29..103. The real reservation is `DynamicThumbstickFrame`, x -100..266 — the
	-- dynamic stick spawns wherever the thumb lands, so the whole band up to x=266 is movement.
	-- 0.415 puts the bar's left edge at x=276, genuinely clear of it.
	bar.Position = UDim2.fromScale(0.415, 0.975)
end
bar.Size = UDim2.fromScale(0.36, 0.1)
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0

-- Slots are square (UIAspectRatioConstraint), so the row's HEIGHT decides how wide the whole bar ends
-- up. Clamping height is therefore what keeps six slots from marching off the side of a phone.
local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(0, 46)
clamp.MaxSize = Vector2.new(10000, 76)
clamp.Parent = bar

-- ⚠️ Job #099 — on touch this is a GRID, not a row, and the arithmetic forces it. On a 666x316 phone
-- canvas the movement frame reserves everything left of x=266 and the fire button owns x=526 onward,
-- leaving ~260 px of bottom band. Six slots at the 58 px thumb floor need 388 px in a single row — they
-- do not fit, and shrinking them to 46 px (which is what shipped) puts every slot under the floor.
-- Wrapping into 3x2 keeps all six at full size inside 190 px. Same answer as the lobby's entry rail.
if UserInputService.TouchEnabled then
	local g = Instance.new("UIGridLayout")
	g.FillDirection = Enum.FillDirection.Horizontal
	g.FillDirectionMaxCells = 3
	g.CellSize = UDim2.fromOffset(58, 58)
	g.CellPadding = UDim2.fromOffset(Theme.space.sm, Theme.space.sm)
	g.VerticalAlignment = Enum.VerticalAlignment.Bottom
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = bar
	-- Sized in `refresh()` from how many slots are actually populated, so an empty inventory takes no
	-- room and a full one wraps to two rows.
	bar.Size = UDim2.fromOffset(58, 58)
else
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Bottom
	l.HorizontalAlignment = Enum.HorizontalAlignment.Left
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, Theme.space.sm)
	l.Parent = bar
end

bar.Parent = gui

-- "hands full" — you're carrying a fuel can / loot crate, so items are unusable
local carry = RunComponents.card({
	name = "HandsFull",
	anchor = Vector2.new(0, 1),
	-- ⚠️ Job #084: STACKED ON THE HEALTH BAR at the old 0.855. `HealthHud`'s holder is anchored
	-- bottom-left at y=0.845 and is 0.042 tall, so it occupies 0.803–0.845; this card is 0.036 tall, so
	-- at 0.855 it covered 0.819–0.855 and sat straight over the HEALTH gauge and the bandage chip.
	-- 0.797 puts its bottom edge just clear of the health row's top. Left column, bottom-up:
	-- hotbar 0.865–0.975 · health 0.803–0.845 · THIS 0.761–0.797 · DropHint 0.733–0.756 · RoleChip 0.42.
	-- ⚠️ Job #086 added the DropHint row. It is a CHILD of this card positioned above it, so moving this
	-- card moves the hint with it — but anything new in 0.733–0.797 now collides with one of the two.
	position = if UserInputService.TouchEnabled then UDim2.fromScale(0.225, 0.797) else UDim2.fromScale(0.015, 0.797),
	size = UDim2.fromScale(0.2, 0.036),
	accent = Theme.color.yellow,
	parent = gui,
})
carry.Visible = false

local carryIcon = Components.icon({ name = "crate", size = UDim2.fromScale(0.14, 0.7), chip = false, parent = carry })
carryIcon.AnchorPoint = Vector2.new(0, 0.5)
carryIcon.Position = UDim2.fromScale(0.04, 0.5)

local carryLabel = Instance.new("TextLabel")
carryLabel.Name = "Label"
carryLabel.AnchorPoint = Vector2.new(1, 0.5)
carryLabel.Position = UDim2.fromScale(0.96, 0.5)
carryLabel.Size = UDim2.fromScale(0.78, 0.66)
carryLabel.TextXAlignment = Enum.TextXAlignment.Left
Components.applyText(carryLabel, Theme.text.caption, Theme.font.button)
carryLabel.TextColor3 = Theme.color.yellow
-- Job #084: names the CONSEQUENCE, not the state. "CARRYING" was accurate and useless — it restated
-- the crate already visible on your head, while the thing the player actually needed to know (the
-- pistol and the axe are both disabled) went unsaid. Reported in the 2026-08-16 playtest as "the
-- pistol does not fire"; the gate was `Busy` the whole time.
carryLabel.Text = "HANDS FULL — CAN'T FIGHT"
carryLabel.Parent = carry

-- ── Job #084: the chip IS the drop button ─────────────────────────────────────────────────────────
-- Carrying disables the gun and the axe, and before this the only way out was a successful deposit —
-- so a full cargo deck could soft-lock a run with no way to put the crate down.
--
-- Putting the action ON this card rather than in a new HUD element or a ProximityPrompt is deliberate:
-- the card already appears only while carrying and already states the problem, so the thing telling you
-- you are encumbered becomes the thing that un-encumbers you. It also dodges the prompt collision a
-- world prompt would cause — the crate rides on your head, inside the Deposit prompt's 26-stud reach
-- and on top of camp LootPrompts.
--
-- Mobile-first: a tap target, with G as the desktop convenience (matching the 1-N / Q pattern above).
local dropRemote = ReplicatedStorage:WaitForChild("DropCarried") :: RemoteEvent

local dropBtn = Instance.new("TextButton")
dropBtn.Name = "DropButton"
dropBtn.Size = UDim2.fromScale(1, 1)
-- ⚠️ Job #099 / finding #0009 — this fills the HandsFull card, which is 0.036 of screen height: about
-- 23 px on a phone, well under the 58 px thumb floor. It is the ONLY way to put cargo down, and a
-- carrying player cannot shoot or swing an axe, so failing to hit it is close to being stuck. The card
-- itself stays visually small; the BUTTON grows past it, which is invisible and entirely the point.
local dropFloor = Instance.new("UISizeConstraint")
dropFloor.MinSize = Vector2.new(0, 58)
dropFloor.Parent = dropBtn
dropBtn.BackgroundTransparency = 1
dropBtn.Text = ""
dropBtn.AutoButtonColor = false
dropBtn.ZIndex = 5
dropBtn.Parent = carry

local dropHint = Instance.new("TextLabel")
dropHint.Name = "DropHint"
-- ⚠️ Job #086: ABOVE the card, not below it. It used to hang under the card at (0.5, 1.05) anchored
-- top-centre, which put it at 0.799–0.821 in screen scale — straight over the HEALTH row at
-- 0.803–0.845 (reported in the 2026-08-16 playtest, and the arithmetic confirms it). Job #084 moved
-- the card itself clear of the health bar but never budgeted a row for the hint it added underneath.
-- Anchored BOTTOM-centre just above the card's top edge, it now sits at ~0.733–0.756: clear of the
-- card at 0.761 and of everything else up to the RoleChip at 0.42. Keeps the left column stacking
-- upward, which is the convention the budget comment above describes.
dropHint.AnchorPoint = Vector2.new(0.5, 1)
dropHint.Position = UDim2.fromScale(0.5, -0.15)
dropHint.Size = UDim2.fromScale(1, 0.62)
dropHint.ZIndex = 5 -- chosen, not incidental: matches `dropBtn` so the hint is never buried by it
dropHint.BackgroundTransparency = 1
dropHint.TextXAlignment = Enum.TextXAlignment.Center
Components.applyText(dropHint, Theme.text.caption, Theme.font.button)
dropHint.TextColor3 = Theme.color.cream
dropHint.TextTransparency = 0.25
dropHint.Text = if UserInputService.TouchEnabled then "TAP TO DROP" else "TAP OR [G] TO DROP"
dropHint.Parent = carry

local function requestDrop()
	if player:GetAttribute("Busy") == true then
		dropRemote:FireServer() -- server owns the decision; no payload to forge
	end
end

dropBtn.Activated:Connect(requestDrop)

-- ── slots ────────────────────────────────────────────────────────────────────────────────────────

local slots: { RunComponents.Slot } = {}
for i = 1, MAX_SLOTS do
	slots[i] = RunComponents.slot(i, function()
		remote:FireServer("equip", i)
	end, bar)
end

-- Manning the helm or the turret disables every loadout item: `WeaponClient:83`, `MeleeClient:26`,
-- `WeaponServer` and `MeleeServer` all refuse to fire while `SeatPart` is DriverSeat or GunSeat (GAME.md:
-- "the driver can't shoot"). Showing the bar there offers four buttons that provably do nothing — and on
-- a phone it also sits exactly where the driver's left thumb needs to be for the steer control.
local function inControlSeat(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return seat ~= nil and (seat.Name == "DriverSeat" or seat.Name == "GunSeat")
end

local function refresh()
	local active = (player:GetAttribute("ActiveSlot") :: number?) or 1
	local shown = visibleSlots()

	bar.Visible = not inControlSeat()

	-- ⚠️ Job #099 — ON TOUCH, SHOW ONLY SLOTS THAT HOLD SOMETHING.
	--
	-- On desktop every UNLOCKED slot is drawn, empty ones included: they advertise the inventory you own
	-- and cost nothing on a big screen. On a phone they cost a great deal — six boxes forced the bar to
	-- wrap to two rows and take a block out of the middle of the play area, and four of those boxes were
	-- empty rectangles with a number in them.
	--
	-- A player typically carries two or three things, so this usually collapses to a single short row.
	-- The grid still wraps if someone really is carrying six. STYLEGUIDE §6.11: show only what matters
	-- while playing.
	local populated = 0
	if TOUCH then
		for i = 1, MAX_SLOTS do
			if ((player:GetAttribute("Slot" .. i) :: string?) or "") ~= "" then
				populated += 1
			end
		end
	end

	for i = 1, MAX_SLOTS do
		local slot = slots[i]
		local id = (player:GetAttribute("Slot" .. i) :: string?) or ""
		-- UIListLayout/UIGridLayout skip invisible children, so hiding the surplus closes the gap rather
		-- than leaving a hole.
		local visible = if TOUCH then id ~= "" else i <= shown
		slot.setVisible(visible)
		if not visible then
			continue
		end

		local def = ItemDefs.get(id)
		local iconKey = if id ~= "" then (Theme.itemIcon :: { [string]: string })[id] else nil
		local label = if def then string.upper(def.name) else ""
		local ammo = if def and def.ammoAttr
			then tostring((player:GetAttribute(def.ammoAttr) :: number?) or 0)
			else ""

		slot.set(iconKey, label, ammo, i == active and id ~= "")
	end

	-- Resize the touch block to exactly what is on screen: 1..3 items = one row, 4..6 = two.
	if TOUCH then
		local cols = math.min(math.max(populated, 1), 3)
		local rows = math.max(math.ceil(populated / 3), 1)
		local gap = Theme.space.sm
		bar.Size = UDim2.fromOffset(cols * 58 + (cols - 1) * gap, rows * 58 + (rows - 1) * gap)
	end

	carry.Visible = player:GetAttribute("Busy") == true
end

-- react to any inventory/ammo/state change
for i = 1, MAX_SLOTS do
	player:GetAttributeChangedSignal("Slot" .. i):Connect(refresh)
end
player:GetAttributeChangedSignal("ActiveSlot"):Connect(refresh)
player:GetAttributeChangedSignal("ActiveItem"):Connect(refresh)
player:GetAttributeChangedSignal("Busy"):Connect(refresh)
-- the pass check completes asynchronously on join (and a mid-session purchase fires this too)
player:GetAttributeChangedSignal("Owns_extraSlots"):Connect(refresh)
for _, def in pairs(ItemDefs.Items) do
	if def.ammoAttr then
		player:GetAttributeChangedSignal(def.ammoAttr):Connect(refresh)
	end
end

-- sitting down / standing up changes whether the bar is usable at all
local function watchSeat(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		hum:GetPropertyChangedSignal("SeatPart"):Connect(refresh)
	end
	refresh()
end
if player.Character then
	watchSeat(player.Character)
end
player.CharacterAdded:Connect(watchSeat)

-- keyboard shortcuts (testing convenience; mobile uses the buttons)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.G then
		requestDrop() -- Job #084: desktop twin of tapping the HANDS FULL chip
		return
	end
	local NUMBER: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
	}
	local slot = NUMBER[key]
	if slot then
		remote:FireServer("equip", slot)
	elseif key == Enum.KeyCode.Q then
		remote:FireServer("drop", (player:GetAttribute("ActiveSlot") :: number?) or 1)
	end
end)

refresh()
