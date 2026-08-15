--!strict
-- EnemyAssets.luau — the creature ART table (Job #078).
--
-- THE ONE PLACE AN ENEMY'S MODEL, ANIMATIONS AND SOUNDS ARE LISTED. `EnemyDefs` (ReplicatedStorage) owns
-- the STATS — hp, speed, damage, aggro — and is replicated because the client reasons about threats.
-- This file owns the ART and is server-only, because nothing on the client needs to know an asset id.
-- Same split `CampDefs`/`FoliageDefs` have with their servers: if a croc looks or sounds wrong, the fix
-- is a number or an id in this file, never a line in `EnemyServer`.
--
-- ── Everything degrades ───────────────────────────────────────────────────────────────────────────
-- A blank id is not an error, it is "not sourced yet". A creature with no model falls back to the
-- greybox body it has always had, a creature with no animation simply doesn't animate, and a creature
-- with no sound is silent. That means this table can be filled in one creature at a time without ever
-- breaking the spawn director.
--
-- ⚠️ MODEL NAMES resolve against `ServerStorage.AssetLibrary`, searched across ALL its group folders
-- (the library groups models into Foliage/Props/Structures/Characters/… and there is no Enemies group
-- yet — put creature models wherever you like, the lookup is by NAME).

local EnemyAssets = {}

export type SoundDef = { id: string, volume: number, min: number, max: number, looped: boolean? }
export type CreatureArt = {
	model: string?, -- AssetLibrary model name; nil = keep the greybox
	scale: number?, -- corrective scale (library models are not authored for our stud sizes)
	yawOffset: number?, -- degrees, if the model was authored facing something other than -Z (its "forward")
	anim: { [string]: string }, -- idle / move / attack / death → rbxassetid://
	sound: { [string]: SoundDef },
}

-- ⚠️ THE MODEL'S FORWARD IS -Z. `EnemyServer` drives every creature with
-- `PivotTo(CFrame.lookAt(newPos, newPos + dir))`, and the greybox puts its `Snout` at `-Z`. A model
-- authored facing +Z swims backwards down the river; that is what `yawOffset = 180` is for.

local NO_SOUND: { [string]: SoundDef } = {}
local NO_ANIM: { [string]: string } = {}

EnemyAssets.ART = {
	-- ── Crocodile — the signature river threat, and the pipeline's test case ──────────────────────
	Crocodile = {
		model = "Crocodile",
		scale = nil, -- set once the real model is measured against def.size (6 x 3 x 16)
		yawOffset = 0,
		anim = {
			idle = "", -- floating, waiting
			move = "", -- swim
			attack = "", -- lunge + bite
			death = "",
		},
		sound = {
			-- uploaded 2026-08-15 from assets/Objects/Monsters/Aligator/aligator_hissing.mp3
			idle = { id = "rbxassetid://137066735880685", volume = 0.35, min = 15, max = 90, looped = false },
			-- uploaded 2026-08-15 as `aligator_aggro`. Widest rolloff of the five on purpose: this is the
			-- "it's coming" cue and it has to carry over the boat engine.
			aggro = { id = "rbxassetid://108958436464973", volume = 0.55, min = 20, max = 140 },
			-- uploaded 2026-08-15 from assets/Objects/Monsters/monster_bite_1.mp3 — a GENERIC monster bite,
			-- not gator-specific. Fine for now, and swappable for an `alligator bite` clip later.
			attack = { id = "rbxassetid://94063943857259", volume = 0.6, min = 15, max = 100 },
			-- `animal-hurt` / `animal-die` are GENERIC animal sounds, deliberately shared with the Panther
			-- below rather than sourced twice (the registry's dedupe-by-id rule). Give either creature its
			-- own clip later and it just overrides this line.
			hurt = { id = "rbxassetid://137192983266942", volume = 0.5, min = 12, max = 80 },
			death = { id = "rbxassetid://120708334083507", volume = 0.6, min = 15, max = 110 },
		},
	} :: CreatureArt,

	-- ── Panther — the land ambusher, and the same def the CampGuard uses ──────────────────────────
	Panther = {
		model = "Panther",
		anim = { idle = "", move = "", attack = "", death = "" },
		sound = {
			idle = { id = "", volume = 0.3, min = 12, max = 70, looped = false },
			aggro = { id = "", volume = 0.6, min = 20, max = 130 },
			attack = { id = "", volume = 0.55, min = 15, max = 90 },
			-- shared with the Crocodile — same generic `animal-hurt` / `animal-die` uploads
			hurt = { id = "rbxassetid://137192983266942", volume = 0.5, min = 12, max = 70 },
			death = { id = "rbxassetid://120708334083507", volume = 0.55, min = 15, max = 90 },
		},
	} :: CreatureArt,

	-- ── Not yet in scope (Job #078 ships Crocodile + Panther first) ───────────────────────────────
	-- Left declared rather than absent so the shape of the work is visible and adding one is a fill-in,
	-- not a new structure.
	Piranha = { model = nil, anim = NO_ANIM, sound = NO_SOUND } :: CreatureArt,
	RiverHippo = { model = nil, anim = NO_ANIM, sound = NO_SOUND } :: CreatureArt,
	Boar = { model = nil, anim = NO_ANIM, sound = NO_SOUND } :: CreatureArt,
} :: { [string]: CreatureArt }

-- ── Glowing eyes (Job 039) ────────────────────────────────────────────────────────────────────────
-- The eye system is ALREADY attachment-aware and needs no change: `addEyes` looks for `EyeLeft` and
-- `EyeRight` Attachments anywhere in the model and places Neon spheres at their `WorldCFrame`, falling
-- back to an offset derived from `def.size` when they are absent.
--
-- ⚠️ SO EVERY SOURCED MODEL MUST CARRY THOSE TWO ATTACHMENTS, on the head, at the eyes. It is two
-- Attachments per creature and it is the difference between eyes that track the head and eyes that
-- float in front of the chest.
EnemyAssets.EYE = {
	leftName = "EyeLeft",
	rightName = "EyeRight",
	size = 0.5,
	color = Color3.fromRGB(255, 45, 45),
}

-- How far a creature has to be from its target before `move` gives way to `idle`, and how close before
-- `attack` fires. Purely presentational — the AI's own ranges are in `EnemyDefs`.
EnemyAssets.ANIM_TUNING = {
	moveSpeedEpsilon = 0.6, -- studs/frame below which it counts as standing still
	attackFade = 0.1,
	crossFade = 0.25,
}

return EnemyAssets
