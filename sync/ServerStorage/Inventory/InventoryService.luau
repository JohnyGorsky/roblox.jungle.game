--!strict
-- InventoryService.luau — authoritative inventory state for the player loadout (Job 015).
-- Job 067: the loadout is 4 slots by default and 6 with the Extra Inventory Slots pass, so "the 4-slot
-- loadout" is no longer true — every bound comes from ItemDefs.slotsFor(player).
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
local CollectionService = game:GetService("CollectionService")

local ServerStorage = game:GetService("ServerStorage")
local WeaponAssets = require(script.Parent:WaitForChild("WeaponAssets"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

-- Job 067: the loadout is no longer a fixed 4 — the Extra Inventory Slots pass raises it per player, so
-- every bound is asked for per player rather than read from one module-level constant.
local function slotsFor(player: Player): number
	return ItemDefs.slotsFor(player)
end

local InventoryService = {}

local function slotAttr(i: number): string
	return "Slot" .. i
end

-- ── the held item (Job #079) ──────────────────────────────────────────────────────────────────────
-- Was a coloured box per kind: a 0.25x4x0.25 "blade", a 0.4x0.6x1.2 "barrel", a Neon "torch tip".
-- Now every one of them is a real object: the Axe reused from roblox.defender, the guns from Meshy, and
-- the Torch BUILT from the `Campfire` recipe.
--
-- ⚠️ The greybox path SURVIVES as the fallback. `WeaponAssets.ART` with no `model` (or a model missing
-- from the library — `ServerStorage` is not Rojo-synced, so an unsaved place has none of them) drops
-- straight back to the coloured box rather than leaving empty hands.
local weaponLibrary: { [string]: BasePart } = {}
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local grp = lib and lib:FindFirstChild("Weapons")
	if grp then
		for _, m in ipairs(grp:GetChildren()) do
			if m:IsA("BasePart") then
				weaponLibrary[m.Name] = m
			end
		end
	end
end

-- Positional world audio on the item itself, per the `GameSoundscape` rule.
local function attachSound(parent: Instance, name: string, def: WeaponAssets.SoundDef)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.id
	s.Volume = def.volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = def.min
	s.RollOffMaxDistance = def.max
	s.Parent = parent
	return s
end

-- The torch: a stick with a flame on it. Built rather than sourced — see `WeaponAssets.TORCH`.
local function buildTorch(part: Part)
	local T = WeaponAssets.TORCH
	part.Size = T.shaft.size
	part.Color = T.shaft.color
	part.Material = Enum.Material.Wood

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = T.head.size
	head.Color = T.head.color
	head.Material = Enum.Material.Slate
	head.Anchored = false
	head.CanCollide = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = part.CFrame * CFrame.new(0, T.shaft.size.Y / 2, 0)
	local hw = Instance.new("WeldConstraint")
	hw.Part0 = part
	hw.Part1 = head
	hw.Parent = head
	head.Parent = part

	local fire = Instance.new("Fire")
	fire.Size = T.flame.size
	fire.Heat = T.flame.heat
	fire.Color = T.flame.color
	fire.SecondaryColor = T.flame.secondary
	fire.Parent = head

	local ember = Instance.new("ParticleEmitter")
	ember.Name = "Embers"
	ember.Texture = "rbxasset://textures/particles/fire_main.dds"
	ember.Rate = T.ember.rate
	ember.Speed = NumberRange.new(T.ember.speed[1], T.ember.speed[2])
	ember.Lifetime = NumberRange.new(T.ember.lifetime[1], T.ember.lifetime[2])
	ember.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, T.ember.size), NumberSequenceKeypoint.new(1, 0) })
	ember.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(198, 74, 30))
	ember.LightEmission = 0.85
	ember.Acceleration = Vector3.new(0, 4, 0)
	ember.SpreadAngle = Vector2.new(18, 18)
	ember.Parent = head

	attachSound(head, "Crackle", T.sound).Looped = true
	local c = head:FindFirstChild("Crackle") :: Sound
	c:Play()
	return head
end

-- ⚠️ THE CARRY POSE IS NOT PLAYED HERE, AND MUST NOT BE MOVED BACK.
-- It was, first: a cached track on the character's Animator, played from this module. It does not work —
-- a player's Animator is owned by that player's CLIENT, so a server-side `Play()` shows up in the
-- server's `GetPlayingAnimationTracks()` and never renders for the player it belongs to. Measured, not
-- assumed: server read `507768375 w1.00 Idle` while the owning client's list held only the default idle
-- and the arm hung at the hip on screen. `HeldPose.local.luau` owns it now (and the id lives in
-- `ItemDefs`, which the client can actually reach).
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

	local art = if id then WeaponAssets.ART[id] else nil
	local source = if art and art.model then weaponLibrary[art.model] else nil

	-- ── the hold rotation ────────────────────────────────────────────────────────────────────────
	-- ⚠️ SHARED BY BOTH BRANCHES, and it has to be: the torch is BUILT down the greybox path (a stick
	-- plus a flame, never a sourced model), so a rotation applied only to real models left it pointing
	-- wherever the hand pointed — which, once the carry pose went in, is straight forward. It read as a
	-- wand lying along the forearm.
	--
	-- 🔴 DERIVED FROM THE LIVE HAND, NOT STORED AS AN ANGLE. `holdInChar` says where the weapon should
	-- sit in CHARACTER space; the hand-relative offset that achieves it depends on where the carry
	-- animation currently has the wrist, so it is solved here, now:
	--     rot = handRotation⁻¹ · characterRotation · holdInChar
	-- Three earlier attempts stored a hand-relative Euler triple instead and all three failed silently
	-- (see the long note in `WeaponAssets`) — averaging across the ±180° wrap, terms vanishing on
	-- read-back, values that round-tripped perfectly and were still 67° off. This form has no angles to
	-- lose and needs no re-solving if the carry animation is ever changed.
	--
	-- The server sees the POSED hand (the owning client replicates its animated CFrames back), which is
	-- what makes solving it here work at all — verified: server-side `RightHand.UpVector` reads (0.21,
	-- 0.04, 0.98) while the pose is playing, not (0, 1, 0).
	local rot: CFrame
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if art and art.holdInChar and root then
		local handRot = hand.CFrame - hand.CFrame.Position
		local charRot = root.CFrame - root.CFrame.Position
		rot = handRot:Inverse() * charRot * art.holdInChar
	else
		rot = CFrame.Angles(0, math.rad((art and art.yawOffset) or 0), 0)
	end

	local part: BasePart
	if source then
		-- the real object
		local clone = source:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.Massless = true
		if art and art.scale and math.abs(art.scale - 1) > 1e-3 then
			-- ⚠️ Multiplies the CURRENT size. Attachments do not scale with `Size` on a part, so if a
			-- weapon ever gains one (a muzzle point, say) it must be scaled by hand — the same trap the
			-- creature eyes hit in Job #078.
			clone.Size *= art.scale
		end
		local grip = (art and art.gripOffset) or Vector3.zero
		-- ⚠️ The rotation is applied BEFORE the grip translation on purpose: `-grip` is expressed in the
		-- ROTATED frame, which is what keeps the model's grip point on the hand however it is angled.
		-- Swap the order and tilting the axe also slides it out of the fist.
		clone.CFrame = hand.CFrame * rot * CFrame.new(-grip.X, -grip.Y, -grip.Z)
		part = clone
	else
		-- greybox fallback, unchanged
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Color = def.color
		p.Material = Enum.Material.SmoothPlastic
		if def.kind == "Melee" then
			p.Size = Vector3.new(0.25, 4, 0.25)
			p.CFrame = hand.CFrame * rot * CFrame.new(0, -2, 0)
		elseif def.kind == "Light" then
			p.Size = Vector3.new(0.6, 1.2, 0.6)
			p.CFrame = hand.CFrame * rot * CFrame.new(0, 0.6, 0)
		else
			p.Size = Vector3.new(0.4, 0.6, if id == "Shotgun" then 2.4 else 1.2)
			p.CFrame = hand.CFrame * rot * CFrame.new(0, 0, -0.6)
		end
		part = p
	end
	part.Name = "HeldItem"

	if def.kind == "Light" then
		-- the torch is always built, model or not: it is a stick plus a flame
		local head = buildTorch(part :: Part)
		-- ⚠️ UNCHANGED WIRING (Job 037/038): the PointLight is tagged `NightLight`, so `LightController`
		-- switches it on at dusk and off at dawn. Do not start it enabled.
		local light = Instance.new("PointLight")
		light.Range = def.lightRange or 26
		light.Brightness = def.lightBrightness or 3
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Shadows = true
		light.Enabled = false
		CollectionService:AddTag(light, "NightLight")
		light.Parent = head
	elseif art then
		for name, sdef in pairs(art.sound) do
			attachSound(part, name, sdef)
		end
	end

	-- 🔴 Job #084: A MOTOR6D, NOT A WELDCONSTRAINT. Reported in play as *"weapon and lamp flys away from
	-- boat when move, they are like drifting"* — the gun and the torch lagged behind the character while
	-- the boat was under way.
	--
	-- ⚠️ The first suspicion was the parent-after-weld ordering below, and that was WRONG: `makeCarried`
	-- in `ExcursionServer` builds its weld in exactly the same order and the carried barrel rides
	-- perfectly. The real difference is WHAT is being welded to.
	--
	-- The carried crate welds to `HumanoidRootPart`. This welds to `RightHand` — an ANIMATED limb, moved
	-- every frame by the Animator through the rig's Motor6Ds. A `WeldConstraint` is a physics constraint
	-- resolved by the solver, so it is always chasing a limb whose motion comes from somewhere else; put
	-- that character on a moving platform and the error becomes visible drift.
	--
	-- A `Motor6D` is the engine's own answer: it IS a rig joint, transformed by the animation system
	-- alongside the limb rather than catching up to it afterwards. This is exactly how a Roblox `Tool`
	-- attaches its Handle (the "RightGrip" Motor6D) — the canonical mechanism, not a workaround.
	--
	-- Parented FIRST so the joint is built against parts that are both already in the DataModel.
	part.Parent = char

	local grip = Instance.new("Motor6D")
	grip.Name = "HeldGrip"
	grip.Part0 = hand
	grip.Part1 = part
	-- Preserve the pose solved above EXACTLY: Part0.CFrame * C0 == Part1.CFrame * C1, and C1 is identity,
	-- so C0 is the held item's current offset in the hand's frame. All the `holdInChar` work above
	-- survives untouched.
	grip.C0 = hand.CFrame:ToObjectSpace(part.CFrame)
	grip.Parent = hand
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
	-- Seed to MAX_SLOTS, not to this player's current count. The pass check is async (and can complete
	-- mid-run), so the extra slot attributes must already exist as "" when it lands — otherwise buying the
	-- pass would leave slots 5–6 as nil and the hotbar would render holes.
	for i = 1, ItemDefs.MAX_SLOTS do
		-- start with the Sword (slot 1) + a Torch (slot 2) for night visibility (Job 037; lootable later)
		player:SetAttribute(slotAttr(i), if i == 1 then "Axe" elseif i == 2 then "Torch" else "")
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
	if slot < 1 or slot > slotsFor(player) then
		return
	end
	if player:GetAttribute("ActiveSlot") == slot then
		player:SetAttribute("ActiveSlot", 0) -- re-click the active slot → deselect (empty hands / holster)
	else
		player:SetAttribute("ActiveSlot", slot)
	end
	InventoryService.refreshActive(player)
end

function InventoryService.drop(player: Player, slot: number)
	if typeof(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	if slot < 1 or slot > slotsFor(player) then
		return
	end
	if (player:GetAttribute(slotAttr(slot)) :: string?) == "Axe" then
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
	local slots = slotsFor(player)
	-- already own it → refill ammo
	for i = 1, slots do
		if (player:GetAttribute(slotAttr(i)) :: string?) == itemId then
			if def.ammoOnLoot then
				InventoryService.addAmmo(player, itemId, def.ammoOnLoot)
			end
			return true
		end
	end
	-- first free slot
	for i = 1, slots do
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
