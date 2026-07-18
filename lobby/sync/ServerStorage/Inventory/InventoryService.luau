--!strict
-- InventoryService.luau — authoritative inventory state for the 4-slot loadout (Job 015).
--
-- SERVER-ONLY shared module (ServerStorage). Both InventoryServer (remotes/seeding) and ExcursionServer
-- (weapon/ammo crate grants) require it — server-side `require` is cached, so they share this one module.
--
-- State lives on PLAYER attributes (not the character) so it survives death/respawn within a run, like
-- Bandages in PlayerCombat:
--   Slot1..SlotN : string item id ("" = empty)     ActiveSlot : number (1..N)
--   ActiveItem   : string (mirror of Slot[ActiveSlot], read by the weapon scripts)
--   <ammoAttr>   : per-gun ammo (e.g. AmmoPistol, AmmoShotgun)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local SLOTS = ItemDefs.SLOT_COUNT

local InventoryService = {}

local function slotAttr(i: number): string
	return "Slot" .. i
end

-- (re)build the greybox held-item visual welded to the character's right hand
local function updateHeldVisual(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("HeldItem")
	if old then
		old:Destroy()
	end
	local id = player:GetAttribute("ActiveItem") :: string?
	local def = ItemDefs.get(id)
	if not def then
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "HeldItem"
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	if def.kind == "Melee" then
		part.Size = Vector3.new(0.25, 4, 0.25) -- blade
		part.CFrame = hand.CFrame * CFrame.new(0, -2, 0)
	else
		part.Size = Vector3.new(0.4, 0.6, if id == "Shotgun" then 2.4 else 1.2) -- barrel
		part.CFrame = hand.CFrame * CFrame.new(0, 0, -0.6)
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	part.Parent = char
end

-- refresh ActiveItem from the active slot + rebuild the held visual
function InventoryService.refreshActive(player: Player)
	local slot = (player:GetAttribute("ActiveSlot") :: number?) or 1
	local id = (player:GetAttribute(slotAttr(slot)) :: string?) or ""
	player:SetAttribute("ActiveItem", id)
	updateHeldVisual(player)
end

-- seed a fresh loadout ONCE per run (sword only). Persists across respawns for the whole run.
function InventoryService.seed(player: Player)
	if player:GetAttribute("InvSeeded") == true then
		return
	end
	player:SetAttribute("InvSeeded", true)
	for i = 1, SLOTS do
		player:SetAttribute(slotAttr(i), if i == 1 then "Sword" else "")
	end
	player:SetAttribute("ActiveSlot", 1)
	for _, def in pairs(ItemDefs.Items) do
		if def.ammoAttr and player:GetAttribute(def.ammoAttr) == nil then
			player:SetAttribute(def.ammoAttr, 0)
		end
	end
	InventoryService.refreshActive(player)
end

function InventoryService.equip(player: Player, slot: number)
	if typeof(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	if slot < 1 or slot > SLOTS then
		return
	end
	player:SetAttribute("ActiveSlot", slot)
	InventoryService.refreshActive(player)
end

function InventoryService.drop(player: Player, slot: number)
	if typeof(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	if slot < 1 or slot > SLOTS then
		return
	end
	if (player:GetAttribute(slotAttr(slot)) :: string?) == "Sword" then
		return -- the sword is the permanent fallback; can't drop it
	end
	player:SetAttribute(slotAttr(slot), "")
	InventoryService.refreshActive(player)
end

function InventoryService.addAmmo(player: Player, itemId: string, amount: number)
	local def = ItemDefs.get(itemId)
	if not def or not def.ammoAttr then
		return
	end
	player:SetAttribute(def.ammoAttr, ((player:GetAttribute(def.ammoAttr) :: number?) or 0) + amount)
end

-- grant a looted item into the first free slot. If already owned, top up its ammo instead. Returns
-- true if handled, false if the inventory is full (caller keeps the crate so the player can free a slot).
function InventoryService.grant(player: Player, itemId: string): boolean
	local def = ItemDefs.get(itemId)
	if not def then
		return false
	end
	-- already own it → refill ammo
	for i = 1, SLOTS do
		if (player:GetAttribute(slotAttr(i)) :: string?) == itemId then
			if def.ammoOnLoot then
				InventoryService.addAmmo(player, itemId, def.ammoOnLoot)
			end
			return true
		end
	end
	-- first free slot
	for i = 1, SLOTS do
		if ((player:GetAttribute(slotAttr(i)) :: string?) or "") == "" then
			player:SetAttribute(slotAttr(i), itemId)
			if def.ammoOnLoot then
				InventoryService.addAmmo(player, itemId, def.ammoOnLoot)
			end
			InventoryService.refreshActive(player)
			return true
		end
	end
	return false -- full
end

function InventoryService.activeItem(player: Player): string?
	return player:GetAttribute("ActiveItem") :: string?
end

-- re-apply the held visual after a respawn (state on the Player already persists)
function InventoryService.onCharacterAdded(player: Player)
	task.defer(function()
		InventoryService.refreshActive(player)
	end)
end

return InventoryService
