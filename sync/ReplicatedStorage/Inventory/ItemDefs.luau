--!strict
-- ItemDefs.luau — the item catalog for the 4-slot loadout (Job 015).
--
-- Shared by client (hotbar UI) and server (inventory + weapon logic). One "what am I holding?" model:
-- Sword is the default fallback; Pistol/Shotgun are looted at camps; each gun has its OWN per-player
-- ammo pool (attribute `ammoAttr`). Numbers here are greybox/functional — tune in a later balance pass.

export type ItemDef = {
	name: string,
	kind: "Melee" | "Gun" | "Light",
	color: Color3, -- greybox held-item colour
	-- light-only fields (Job 037):
	lightRange: number?,
	lightBrightness: number?,
	-- gun-only fields:
	ammoAttr: string?, -- Player attribute holding this gun's ammo (per-player)
	damage: number?,
	range: number?,
	pellets: number?, -- rays per shot (shotgun spread)
	spread: number?, -- cone half-angle in radians for extra pellets
	fireInterval: number?, -- min seconds between shots
	-- ── burst guns (Job #117) ───────────────────────────────────────────────────────────────────
	-- PRESENCE of `burstDuration` is what makes a gun a burst gun. Nothing branches on the item id, so
	-- a second burst weapon is data only.
	burstDuration: number?, -- seconds of continuous fire from ONE trigger pull, costing ONE round
	burstInterval: number?, -- seconds between bullets inside the burst
	-- ── projectile guns (Job #118) ──────────────────────────────────────────────────────────────
	-- PRESENCE of `flightTime` is what makes a gun fire a PROJECTILE instead of a hitscan ray. As with
	-- burst above, nothing branches on the item id, so a second rocket weapon is data only.
	flightTime: number?, -- seconds from the trigger to the blast, ALWAYS the same whatever the distance
	cooldown: number?, -- the reload. 🔴 NOT `fireInterval` — see the Bazooka's note on why
	blastDamage: number?, -- damage at the centre of the blast (NOT `damage`, and see the Bazooka's note)
	blastRadius: number?, -- studs
	blastInner: number?, -- fraction of the radius that takes FULL damage (0.5 = the inner half)
	blastMinFactor: number?, -- fraction of blastDamage still dealt at the very rim
	ammoOnLoot: number?, -- ammo granted when you first loot the gun
	ammoPerCrate: number?, -- ammo granted per ammo pickup
	-- melee-only fields:
	meleeRange: number?,
	swingInterval: number?,
}

local ItemDefs = {}

-- Loadout size. BASE is what everyone gets; the Extra Inventory Slots game pass (Job 067) raises a
-- player to MAX. Read `ItemDefs.slotsFor(player)` rather than these constants — the count is per-player
-- now, not global.
ItemDefs.SLOT_COUNT = 4 -- base (kept as the original name: it is what an unpaid player has)
ItemDefs.MAX_SLOTS = 6 -- with the Extra Inventory Slots pass

-- How many rounds the MOUNTED TURRET gets from one ammo crate. Lived as a local `ROUNDS_PER_AMMO` in
-- GunServer until Job #075: the HUD has to total "how many shots do I actually have" across crates and
-- loaded rounds, and a second hand-copied 12 on the client would drift the moment this is tuned.
-- (Distinct from `ammoPerCrate` above, which is a HANDHELD gun picking up an ammo crate.)
ItemDefs.TURRET_ROUNDS_PER_CRATE = 12

-- 🔴 THE CARRY POSE — Roblox's own `toolnone`, the animation the default `Animate` LocalScript plays when
-- a character holds a Tool. Without it the crew stand arms-down and a held axe hangs by their knees.
--
-- ⚠️ IT LIVES HERE, IN REPLICATED STORAGE, BECAUSE ONLY THE CLIENT CAN PLAY IT.
-- A player's character Animator is owned by that player's client: an `Animator:LoadAnimation():Play()`
-- run on the SERVER shows up in the server's `GetPlayingAnimationTracks()` and never renders for the
-- owning player. That was measured, not assumed — the track read `507768375 w1.00 Idle` on the server
-- while the client's own list held only the default idle, and the arm hung down on screen.
-- So `HeldPose.local.luau` plays it, and the id cannot sit in `WeaponAssets` (ServerStorage, unreachable
-- from the client). One copy, here, rather than the same id hand-written into two files.
--
-- ⚠️ R15 only (R6's equivalent is 182393478). This game is R15, verified on a live character.
ItemDefs.HOLD_ANIM = "rbxassetid://507768375"

-- How many slots this player has. Convenience only — more room to carry, no damage/health/speed change,
-- which is what keeps it on the right side of GAME.md's "core power stays earnable" rule.
--
-- Reads the `Owns_extraSlots` attribute MonetizationServer publishes. That attribute arrives
-- ASYNCHRONOUSLY (UserOwnsGamePassAsync on join), so anything that renders slots must react to it
-- changing rather than sampling it once — see InventoryHud.
function ItemDefs.slotsFor(player: Player): number
	if player:GetAttribute("Owns_extraSlots") == true then
		return ItemDefs.MAX_SLOTS
	end
	return ItemDefs.SLOT_COUNT
end

ItemDefs.Items = {
	-- Job #079: the starting weapon. RENAMED from `Sword` — the model is roblox.defender's Rusty Axe,
	-- reused whole. Damage stays 15 deliberately (Defender's axe does 20): every other weapon is meant
	-- to be an upgrade on this, and Jobs 015/058 tuned the on-foot camp raid against 15.
	Axe = {
		name = "Axe",
		kind = "Melee",
		color = Color3.fromRGB(200, 205, 215),
		damage = 15,
		meleeRange = 9, -- short range only — pure fallback
		swingInterval = 0.6,
	},
	Torch = {
		name = "Torch",
		kind = "Light",
		color = Color3.fromRGB(255, 175, 80),
		lightRange = 30, -- studs the torch lights around you
		lightBrightness = 3,
	},
	Pistol = {
		name = "Pistol",
		kind = "Gun",
		color = Color3.fromRGB(60, 60, 70),
		ammoAttr = "AmmoPistol",
		damage = 20,
		range = 220,
		pellets = 1,
		spread = 0,
		fireInterval = 0.22,
		ammoOnLoot = 24,
		ammoPerCrate = 18,
	},
	Shotgun = {
		name = "Shotgun",
		kind = "Gun",
		color = Color3.fromRGB(80, 55, 40),
		ammoAttr = "AmmoShotgun",
		-- Job #104: 12 -> 24 per pellet, a straight 2x (user: "shotgun must be 2x stronger").
		-- A full 6-pellet hit is 144, so what actually changes is MARGIN, not what it can kill: at 12 a
		-- point-blank hit (72) already killed every land threat (Bandit/Boar/Wolf are 50-55 HP), but it
		-- needed 5 of 6 pellets to connect. Now 3 is enough. The one real threshold crossed is the
		-- RiverHippo (120 HP) — two shells to one. Priced against that: `ammoPerCrate` shells cost 90
		-- salvage at the trading post, i.e. 15/shell against the pistol's 3.3/round (ShopDefs).
		damage = 24, -- per pellet (close range = big total)
		range = 95,
		pellets = 6,
		spread = 0.14,
		fireInterval = 0.7,
		ammoOnLoot = 8,
		ammoPerCrate = 6,
	},
	-- ── M16 — Job #117. The first weapon sold for Robux, and the first BURST gun ─────────────────
	-- One trigger pull = 2 s of continuous fire = 20 bullets = ONE round. 30 rounds means 30 bursts.
	--
	-- 🔴 `fireInterval` IS NOT THE LOCKOUT, AND MUST NOT BE TREATED AS ONE.
	-- `WeaponServer` scales it by `0.965 ^ SkillGun` (Gun Discipline), so at MAX_LEVEL 10 a 2.0 here
	-- becomes 1.401 s — two bursts overlapping for 0.6 s, ~6 extra bullets, ~84 extra damage, silently,
	-- on the most expensive weapon in the game. The real lockout is a burst-owned latch in
	-- `WeaponServer`; this value only makes the cheap pre-burst gate reject a mashed trigger.
	-- ⚠️ The M16 is EXEMPT from Gun Discipline by decision (Job #117) — see the note in `SkillDefs`.
	--
	-- Damage is per BULLET: 14 x 20 = 280 a burst, 140 dps against the Shotgun's 206 (at 95 studs) and
	-- the Pistol's 91 (at 220). It wins on range and on not having to close, not on raw dps.
	M16 = {
		name = "M16",
		kind = "Gun",
		color = Color3.fromRGB(52, 56, 50), -- greybox fallback only; the real art is a MeshPart
		ammoAttr = "AmmoM16",
		damage = 14,
		range = 250,
		pellets = 1,
		-- A little scatter, deliberately. 20 rays down an identical vector is a laser beam, and reads as
		-- one — far tighter than the shotgun's 0.14 cone, wide enough that a 2 s burst looks like a burst.
		spread = 0.012,
		fireInterval = 2.0, -- see the 🔴 above: a cheap pre-gate, NOT the lockout
		burstDuration = 2.0,
		burstInterval = 0.10, -- -> 20 bullets
		ammoOnLoot = 30, -- one "round" = one 2 s burst, so this is 30 BURSTS
		-- ── 🔴 Job #123: THIS FIELD USED TO BE ABSENT, AND ITS ABSENCE WAS THE POWER CAP ─────────────
		-- Read this before tuning it. Until Job #123 there was no `ammoPerCrate` here, deliberately: it
		-- is what prices a gun's ammo at the trading post (`ShopDefs.perBox`), so leaving it unset made
		-- 30 bursts a hard per-run cap with **no way to buy more**, and that cap was the only thing
		-- holding the line on a `power = true` Robux purchase (see MonetizationDefs).
		--
		-- Job #123 sells the M16 for Salvage at landing 2, so the cap is now a **PRICE, not an absence**.
		-- 10 bursts a box at 350 Salvage = 35 a burst, which is 0.125 Salvage per damage (280 a burst)
		-- against the Shotgun's 0.104 — dearer per damage, which is the intended shape for the premium
		-- gun. ⚠️ It is also deliberately cheaper per burst than re-buying the 1,250 gun (41.7 a burst),
		-- because `InventoryService.grant` tops up ammo on an owned gun — that is the Job #104 pistol
		-- exploit, and it is priced out rather than blocked.
		--
		-- ⚠️ SO THE LEVER IS THIS PRICE (and `ShopDefs.m16Ammo.cost`), NOT `damage`. Unchanged from #117.
		-- ⚠️ AND THIS DOES NOT PUT M16 AMMO IN CAMP CRATES. A camp `Kind == "Ammo"` crate reads
		-- `ammoPerCrate` for its own `weaponId`, and that is only ever Pistol/Shotgun
		-- (`ExcursionServer`'s `weaponId = if tier % 2 == 0 ...`). Checked, not assumed.
		ammoPerCrate = 10, -- BURSTS per bought box — see above before changing
	},
	-- ── Bazooka — Job #118. The first PROJECTILE weapon in the game ─────────────────────────────
	-- One trigger pull = one rocket = one round. It flies a visible arc and lands on the point you
	-- marked after EXACTLY 4 seconds, whatever the distance, then blasts a 30-stud radius.
	--
	-- 🔴 THE BLAST NUMBER IS `blastDamage`, AND `damage` IS DELIBERATELY ABSENT.
	-- `WeaponServer`'s single-shot path is a fall-through: any `kind == "Gun"` that no earlier branch
	-- claims ends up in hitscan `volley()`, which reads `def.damage` and `def.range`. Put 300 in `damage`
	-- and the day someone moves, reorders or forgets the projectile branch, this ships as a **300-damage
	-- instant-hit 300-stud sniper rifle** — which looks exactly like the weapon working, so nobody finds
	-- it. With `damage` unset that same mistake produces `volley`'s default of 20: still broken, but
	-- obviously and cheaply broken. The failure mode is chosen rather than left to luck.
	--
	-- 🔴 AND THE RELOAD IS `cooldown`, NOT `fireInterval`, FOR THE REASON THE M16 ABOVE DOCUMENTS.
	-- `WeaponServer` scales `fireInterval` by `0.965 ^ SkillGun`, so a 5.0 there would quietly become
	-- **3.503 s at SkillGun 10** against a requirement of "a hard 5-second reload, identical for every
	-- player". Rather than carry the same number in two fields and let them drift, `fireInterval` is
	-- simply not set: the unscaled latch in `WeaponServer` reads `cooldown`, and the cheap anti-mash
	-- pre-gate falls back to its 0.22 s default, which is harmless because the latch is checked first and
	-- is five seconds long. ⚠️ Exempt from Gun Discipline by decision — see `SkillDefs`.
	--
	-- Balance: 300 in a 30-stud radius one-shots every land threat in the game (Piranha 15 … RiverHippo
	-- 120) and a Generator (150) — and still does at the rim, where 25% is 75. What it costs is TIME: a
	-- 4 s flight the whole crew can see coming, and a 5 s reload, the longest cycle of any weapon here.
	Bazooka = {
		name = "Bazooka",
		kind = "Gun",
		color = Color3.fromRGB(64, 68, 58), -- greybox fallback only; the real art is a MeshPart
		ammoAttr = "AmmoBazooka",
		range = 300, -- max target distance; aiming past it clamps the impact point to 300 studs
		pellets = 1,
		spread = 0,
		flightTime = 4.0, -- presence of this is what makes it a projectile
		cooldown = 5.0,
		blastDamage = 300,
		blastRadius = 30,
		blastInner = 0.5, -- the inner 15 studs take the full 300
		blastMinFactor = 0.25, -- and the rim still takes 75
		ammoOnLoot = 6, -- ROCKETS. `RifleGrant`'s startup check fails loudly if the shop disagrees
		-- ── 🔴 Job #123: ALSO PREVIOUSLY ABSENT, for exactly the reason the M16's was ────────────────
		-- See the M16's block above — the whole argument applies here and is not repeated. 6 rockets was
		-- a hard per-run cap because rockets could not be bought at any price; Job #123 sells the Bazooka
		-- for Salvage at landing 3, so that cap is now a price.
		--
		-- 2 rockets a box at 500 Salvage = **250 a rocket, the most expensive shot in the game** — and
		-- deliberately so, because this is the round that one-shots every land threat in a 30-stud radius.
		-- Still under the 300-a-rocket cost of re-buying the 1,800 gun, which is what closes the Job #104
		-- top-up exploit.
		--
		-- ⚠️ THE LEVER IS THIS PRICE, NOT `blastDamage`. Unchanged from #118.
		ammoPerCrate = 2, -- ROCKETS per bought box — see above before changing
	},
} :: { [string]: ItemDef }

function ItemDefs.get(id: string?): ItemDef?
	if not id then
		return nil
	end
	return ItemDefs.Items[id]
end

return ItemDefs
