--!strict
-- WeaponAssets.luau — the HELD-ITEM art + audio table (Job #079).
--
-- THE ONE PLACE A WEAPON'S MODEL, SOUNDS AND ANIMATIONS ARE LISTED. `ItemDefs` (ReplicatedStorage) owns
-- the STATS — damage, range, fire interval, ammo — and is replicated because the client reasons about
-- them. This file owns the ART and is server-only, because nothing on the client needs an asset id.
-- Same split `EnemyAssets`/`EnemyRig` and `CampDefs`/`ExcursionServer` have.
--
-- ── Everything degrades ───────────────────────────────────────────────────────────────────────────
-- No `model` → `InventoryService` keeps the coloured greybox part it has always drawn. No sound id →
-- silence. So this table can be filled one weapon at a time without ever breaking the inventory.
--
-- ⚠️ Model names resolve against `ServerStorage.AssetLibrary.Weapons`, BY NAME.

local WeaponAssets = {}

export type SoundDef = { id: string, volume: number, min: number, max: number }

export type HeldArt = {
	model: string?, -- AssetLibrary.Weapons entry; nil = keep the greybox
	scale: number?, -- multiplies the CURRENT size (see the note in InventoryService)
	yawOffset: number?, -- degrees about Y, to point the model the way the greybox pointed
	-- Degrees about X/Y/Z. Present = it REPLACES `yawOffset`'s yaw-only rotation, for a weapon that has
	-- to sit at a compound angle in the hand rather than just be spun about the vertical.
	holdAngles: Vector3?,
	gripOffset: Vector3?, -- where the hand grabs it, relative to the model's origin
	anim: { [string]: string },
	sound: { [string]: SoundDef },
}

-- ── The carry pose ────────────────────────────────────────────────────────────────────────────────
-- 🔴 ROBLOX'S OWN `toolnone` ANIMATION — the same asset the default `Animate` LocalScript plays, read
-- straight out of a live character's `Animate.toolnone.ToolNoneAnim` (2026-08-16).
--
-- Why we play it ourselves rather than shipping a real `Tool`: `Animate` only poses the arm when the
-- character has a **`Tool` that is a direct child of the Character AND has a child named `Handle`** —
--     local tool = Character:FindFirstChildOfClass("Tool")
--     if tool and tool:FindFirstChild("Handle") then animateTool() ... else stopToolAnimations()
-- Our held item is a welded Part, so that branch never ran and the crew stood arms-down with an axe by
-- their knees. A real Tool would work, but it drags in Roblox's Backpack UI (which `IntroHudGate`
-- re-enables after the intro, so it WOULD render under our own hotbar), drop-on-Backspace, and
-- `Tool.Activated` racing `MeleeClient`'s input. Playing the same asset directly costs none of that and
-- is identical on screen — it is literally the animation a Tool would have played.
--
-- ⚠️ R15 only (the R6 equivalent is 182393478). This game is R15, verified on a live character; the
-- loader is pcall'd, so anything else degrades to the old arms-down hold rather than erroring.
WeaponAssets.HOLD_ANIM = "rbxassetid://507768375"

-- ⚠️ ORIENTATION, MEASURED NOT GUESSED.
-- The greybox gun was a box whose length ran along **Z**, pointing -Z (the way a character faces).
-- Both Meshy guns are authored with their barrel along **+X** — verified by profiling the mesh height
-- along X: the pistol is 2.02 studs tall at x=-1.22 (grip + slide) and tapers to 0.12 at x=+1.82 (the
-- muzzle); the shotgun is thickest at x=-2.28 (the stock). A 90° yaw turns +X into -Z.
local BARREL_X_TO_MINUS_Z = 90

WeaponAssets.ART = {
	-- ── Axe — the starting weapon, reused wholesale from roblox.defender ─────────────────────────
	-- Its `Handle` there was a plain Part + SpecialMesh, so nothing had to be copied between places:
	-- the part is rebuilt in `AssetLibrary.Weapons.Axe` from mesh 145815658 / texture 186913315 /
	-- decal 4657174543. Defender's `ToolScript` was deliberately NOT brought across.
	Axe = {
		model = "Axe",
		scale = 1,
		yawOffset = 0,
		-- ⚠️ TUNED ON SCREEN AGAINST THE CARRY POSE, not derived. The right angle depends on where
		-- `HOLD_ANIM` puts the forearm, so this had to be set after that animation was playing — with the
		-- old arms-down stance any value here would have been wrong.
		-- At (0,0,0) the haft stands dead vertical in the fist (what the axe looked like before this) and
		-- the head sits in front of the face. Pitching back 40° lays it diagonally across the body; the
		-- **negative** roll is what swings the head OUT past the shoulder instead of across the face —
		-- +30 was tried first and put the blade over the character's nose.
		holdAngles = Vector3.new(-40, 0, -30),
		-- Defender's `Tool.Grip` was (0, -1.089, 0.026): the hand grabs the haft just below the head.
		gripOffset = Vector3.new(0, -1.089, 0.026),
		anim = {
			-- Defender alternates these two per swing; `AnimationConstants.axeSlash`
			slash1 = "rbxassetid://567480700",
			slash2 = "rbxassetid://567479941",
		},
		sound = {
			swing = { id = "rbxassetid://210946558", volume = 0.45, min = 8, max = 60 }, -- AxeSwing
			hit = { id = "rbxassetid://8936215056", volume = 0.55, min = 8, max = 70 }, -- AxeChop
			-- ⚠️ Defender authors this at Volume = 10.0, which is absurd for a first-person cue.
			-- Wired far lower here on purpose; do not "restore" it from Defender.
			equip = { id = "rbxassetid://2304904662", volume = 0.35, min = 6, max = 40 },
		},
	} :: HeldArt,

	-- ── Pistol ──────────────────────────────────────────────────────────────────────────────────
	Pistol = {
		model = "Pistol",
		-- measured 3.80 x 2.22 x 0.55; the greybox barrel it replaces was 1.20 long -> 1.20/3.80
		scale = 0.316,
		yawOffset = BARREL_X_TO_MINUS_Z,
		gripOffset = Vector3.new(-0.35, -0.30, 0), -- grip end is -X before the yaw
		anim = {},
		sound = {
			-- ✅ uploaded and owned since 2026-08-02, and never wired until now (ASSETS.md §3.2)
			fire = { id = "rbxassetid://138178318678571", volume = 0.5, min = 10, max = 160 },
			empty = { id = "rbxassetid://75733077651437", volume = 0.4, min = 6, max = 40 },
		},
	} :: HeldArt,

	-- ── Shotgun ─────────────────────────────────────────────────────────────────────────────────
	Shotgun = {
		model = "Shotgun",
		-- measured 5.70 x 1.33 x 0.34; the greybox barrel was 2.40 long -> 2.40/5.70
		scale = 0.421,
		yawOffset = BARREL_X_TO_MINUS_Z,
		gripOffset = Vector3.new(-0.6, -0.15, 0),
		anim = {},
		sound = {
			-- its own report rather than the pistol's: 6 pellets for 72 damage should not sound like a
			-- 20-damage sidearm. Creator Store, free, approved 2026-08-15.
			fire = { id = "rbxassetid://129597576449946", volume = 0.55, min = 12, max = 200 },
			-- the rack between shots — this is what makes a pump-action read as one
			pump = { id = "rbxassetid://113837896417526", volume = 0.4, min = 8, max = 60 },
			empty = { id = "rbxassetid://75733077651437", volume = 0.4, min = 6, max = 40 },
		},
	} :: HeldArt,
}

-- ── The boat's mounted turret ─────────────────────────────────────────────────────────────────────
-- Not a held item, so it is not in `ART` — but its ids belong in the same file, because "the one place a
-- weapon's sounds are listed" is the whole point of this module.
--
-- ⚠️ The turret is the ONLY weapon in the game with a real RELOAD moment: it feeds from boat cargo and
-- swallows a whole `Ammo` crate when its rounds run out. Handheld guns have no magazine — their ammo is
-- a counter topped up by loot — so `gun_reload` has nowhere else to play.
WeaponAssets.TURRET = {
	fire = { id = "rbxassetid://138178318678571", volume = 0.55, min = 15, max = 200 }, -- gun_shot
	-- `gun_empty_clip` rather than the handheld `empty_gun`: a belt-fed turret running dry should not
	-- click like a pistol.
	empty = { id = "rbxassetid://135106168511714", volume = 0.45, min = 8, max = 60 },
	reload = { id = "rbxassetid://134765294816468", volume = 0.5, min = 10, max = 80 }, -- gun_reload
}

-- ── Torch — BUILT, not sourced ────────────────────────────────────────────────────────────────────
-- It is a stick plus a flame, and Job #077 already established that recipe in `Campfire.luau`
-- (`Fire` + ember `ParticleEmitter` + `PointLight`). Building it costs nothing, stays on-palette, and
-- reuses wiring that is already correct: the torch branch of `updateHeldVisual` ALREADY creates the
-- `PointLight` and tags it `NightLight`, so `LightController` switches it at dusk (17.5 h) with no
-- new code at all.
WeaponAssets.TORCH = {
	shaft = { size = Vector3.new(0.16, 1.5, 0.16), color = Color3.fromRGB(76, 55, 37) }, -- Theme woodDark
	head = { size = Vector3.new(0.30, 0.34, 0.30), color = Color3.fromRGB(38, 30, 24) }, -- charred wrap
	flame = { size = 3.2, heat = 6, color = Color3.fromRGB(255, 168, 74), secondary = Color3.fromRGB(214, 90, 24) },
	ember = { rate = 5, speed = { 1.5, 3.5 }, lifetime = { 0.6, 1.3 }, size = 0.14 },
	-- reuses the campfire crackle the camps already play — owned, and it is the same fire
	sound = { id = "rbxassetid://113774133604878", volume = 0.22, min = 4, max = 22 },
}

return WeaponAssets
