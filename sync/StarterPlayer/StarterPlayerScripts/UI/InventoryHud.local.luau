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

local function visibleSlots(): number
	return ItemDefs.slotsFor(player)
end

local gui = Components.screen("InventoryHud", player:WaitForChild("PlayerGui"))
gui.DisplayOrder = 6

local bar = Instance.new("Frame")
bar.Name = "Hotbar"
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.fromScale(0.015, 0.975)
bar.Size = UDim2.fromScale(0.36, 0.1)
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0

-- Slots are square (UIAspectRatioConstraint), so the row's HEIGHT decides how wide the whole bar ends
-- up. Clamping height is therefore what keeps six slots from marching off the side of a phone.
local clamp = Instance.new("UISizeConstraint")
clamp.MinSize = Vector2.new(0, 46)
clamp.MaxSize = Vector2.new(10000, 76)
clamp.Parent = bar

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, Theme.space.sm)
layout.Parent = bar

bar.Parent = gui

-- "hands full" — you're carrying a fuel can / loot crate, so items are unusable
local carry = RunComponents.card({
	name = "HandsFull",
	anchor = Vector2.new(0, 1),
	-- ⚠️ Job #084: STACKED ON THE HEALTH BAR at the old 0.855. `HealthHud`'s holder is anchored
	-- bottom-left at y=0.845 and is 0.042 tall, so it occupies 0.803–0.845; this card is 0.036 tall, so
	-- at 0.855 it covered 0.819–0.855 and sat straight over the HEALTH gauge and the bandage chip.
	-- 0.797 puts its bottom edge just clear of the health row's top. Left column, bottom-up:
	-- hotbar 0.865–0.975 · health 0.803–0.845 · THIS 0.761–0.797 · RoleChip 0.42.
	position = UDim2.fromScale(0.015, 0.797),
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
dropBtn.BackgroundTransparency = 1
dropBtn.Text = ""
dropBtn.AutoButtonColor = false
dropBtn.ZIndex = 5
dropBtn.Parent = carry

local dropHint = Instance.new("TextLabel")
dropHint.Name = "DropHint"
dropHint.AnchorPoint = Vector2.new(0.5, 0)
dropHint.Position = UDim2.fromScale(0.5, 1.05)
dropHint.Size = UDim2.fromScale(1, 0.62)
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

	for i = 1, MAX_SLOTS do
		local slot = slots[i]
		-- UIListLayout skips invisible children, so hiding the surplus closes the gap rather than
		-- leaving a hole where slots 5-6 would be.
		slot.setVisible(i <= shown)
		if i > shown then
			continue
		end

		local id = (player:GetAttribute("Slot" .. i) :: string?) or ""
		local def = ItemDefs.get(id)
		local iconKey = if id ~= "" then (Theme.itemIcon :: { [string]: string })[id] else nil
		local label = if def then string.upper(def.name) else ""
		local ammo = if def and def.ammoAttr
			then tostring((player:GetAttribute(def.ammoAttr) :: number?) or 0)
			else ""

		slot.set(iconKey, label, ammo, i == active and id ~= "")
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
