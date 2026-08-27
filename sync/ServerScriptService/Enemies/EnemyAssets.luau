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
-- ── Water creatures don't need a skeleton ─────────────────────────────────────────────────────────
-- A crocodile in a river is HALF SUBMERGED, and the waterline hides exactly the parts a skeletal rig
-- would be animating — the legs and the belly. So a water creature is a static mesh plus:
--   · `sink`  — dropped so the waterline cuts it along the back
--   · `bob`   — a slow vertical rise and fall
--   · `sway`  — a slow roll, and a faster yaw wag that reads as a tail driving it
--   · a WAKE that only emits while it is actually moving, and a SPLASH burst when it strikes
--
-- That costs no credits, no rig, and no animation upload, and it sidesteps the real risk with Meshy's
-- auto-rigger: it is built for humanoids (t-pose, height in metres) and a 20-stud horizontal quadruped
-- is its worst case. Land creatures still want real animation — this is a water-only shortcut.
export type WaterMotion = {
	sink: number, -- studs the VISUAL drops below the hitbox centre so the waterline cuts it
	bobAmp: number,
	bobHz: number,
	rollDeg: number, -- slow roll, the swell
	rollHz: number,
	wagDeg: number, -- faster yaw wag — the tail
	wagHz: number,
}

-- VFX scale is derived from the creature's own `def.size`, so a hippo throws a bigger splash than a
-- piranha without anyone tuning two sets of numbers. These are MULTIPLIERS on that.
-- Land creatures reuse the rigs we already own from **roblox.defender**. Neither ships animation ids:
--   · `Wolf` is an R6-style rig whose bundled `Animate` script swings `Motor6D.DesiredAngle` off
--     `Humanoid.Running` — an event that NEVER FIRES here, because our creatures are anchored and moved
--     by `PivotTo`. So we do what that script does, from our own "is it moving" flag. `joints` below.
--   · `WesternBandit` is a full R15 rig, so it can just play Roblox's standard animation ids on the
--     Animator it already has. `anim` below.
export type JointSwing = {
	parts: { string }, -- Motor6D names to swing, alternating phase (front-left/back-right together)
	amplitude: number, -- radians at full stride
	hz: number,
}

export type CreatureVfx = {
	wakeRate: number, -- ripples per second while moving; 0 = no wake
	wakeScale: number,
	splashOnAttack: number, -- particles emitted in the strike burst; 0 = none
	splashScale: number,
	splashOnDeath: number,
}

export type CreatureArt = {
	model: string?, -- AssetLibrary model OR single MeshPart name; nil = keep the greybox
	scale: number?, -- corrective scale (library models are not authored for our stud sizes)
	yawOffset: number?, -- degrees, if the model was authored facing something other than -Z (its "forward")
	water: WaterMotion?, -- present = animate procedurally in water instead of with a skeleton
	joints: JointSwing?, -- present = swing these Motor6Ds while moving (land rigs with no animation ids)
	-- ⚠️ `false` = NO glowing eyes. Default (nil) is eyes ON, which is right for wildlife — the Job #039
	-- effect is a night-predator read. It is wrong twice over on a HUMAN: a raider with glowing eyes is a
	-- monster, and `addEyes`' no-attachment fallback derives the position from the HITBOX, which for the
	-- Bandit is the Panther's 5×4×11 quadruped box. On an upright biped that lands the eyes at knee
	-- height, 4.6 studs out in front of him. Seen in play 2026-08-16.
	eyes: boolean?,
	vfx: CreatureVfx?,
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
		-- ⚠️ The library asset is a single **MeshPart** named `Aligator` (the user's spelling), not a Model
		-- and not "Crocodile" — resolution is by the name in the library, so this string must match it.
		model = "Aligator",
		-- ⚠️ RE-MEASURED 2026-08-15 after the mesh was re-imported at a DIFFERENT size — 8.10 x 7.86 x 28.98
		-- against the previous 7.10 x 4.00 x 20.68, and NOT a uniform change (x1.14 / x1.97 / x1.40). Both
		-- the scale and the eye attachments had to be redone. If the mesh is ever re-imported, re-measure;
		-- do not assume the old numbers survive.
		-- 16 / 28.98 = 0.552 → 4.5 x 4.3 x 16.0 against a 6 x 3 x 16 hitbox.
		-- ⚠️ **+30% (0.552 → 0.718) on user direction 2026-08-16** — "scale enemies in water like 30%".
		-- → 5.8 x 5.6 x 20.8. The HITBOX is deliberately NOT scaled with it: `def.size` is what every
		-- aggro/bite/leash distance is tuned against (Jobs 006-009, 053, 058), and this file's rule is that
		-- the art hangs off the hitbox rather than becoming it. The art now overhangs, which is fine.
		scale = 0.718,
		-- 0 — the mesh is already authored head-at-**-Z**, which is our forward. MEASURED, after an earlier
		-- guess of 180 got it backwards: raycast cross-sections along the mesh show the +Z end tapering to
		-- 0.24 studs wide and drooping to y = -1.67 (a tail), while the -Z end stays blunt and level at
		-- 1.44 wide (a snout). Do not "fix" this from a screenshot — re-measure.
		yawOffset = 0,
		water = {
			-- ⚠️ 1.5, raised from 1.0 when the mesh was re-imported TALLER (4.3 studs vs 3.1). Sink is an
			-- absolute drop, so a taller mesh rides higher out of the water at the same value — re-check
			-- this whenever the model changes.
			-- ⚠️ 1.5 → 0.6 on user direction 2026-08-16 ("crocodile and hippo must be more out of water, i
			-- can barely see them"). Sink is an ABSOLUTE drop of the visual below the hitbox, so the +30%
			-- scale already lifted it ~0.65 studs; this takes it the rest of the way. Now the whole back and
			-- head ride clear of the surface instead of just the spine.
			sink = 0.6,
			bobAmp = 0.22,
			bobHz = 0.42,
			rollDeg = 4,
			rollHz = 0.27,
			wagDeg = 3.5,
			wagHz = 0.6,
		},
		vfx = {
			wakeRate = 22,
			wakeScale = 1.0,
			splashOnAttack = 28,
			splashScale = 1.15,
			splashOnDeath = 40,
		},
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
			-- `animal-hurt` / `animal-die` are GENERIC animal sounds, deliberately shared with the Wolf
			-- below rather than sourced twice (the registry's dedupe-by-id rule). Give either creature its
			-- own clip later and it just overrides this line.
			hurt = { id = "rbxassetid://137192983266942", volume = 0.5, min = 12, max = 80 },
			death = { id = "rbxassetid://120708334083507", volume = 0.6, min = 15, max = 110 },
		},
	} :: CreatureArt,

	-- ── Wolf — the riverbank ambusher (was Panther) ──────────────────────────────────────────────
	-- Reused wholesale from roblox.defender: rig, sounds and all. Its two bundled Sounds are named
	-- `Sound` (played on noticing a player) and `Growl` (played on hitting one) — mapped straight onto
	-- our aggro/attack slots so they do the same job here.
	Wolf = {
		model = "Wolf",
		-- measured: the rig is 1.7 x 4.2 x 6.2 studs against a 5 x 4 x 11 hitbox. 1.3 brings it to ~8 studs
		-- long — closer to the hitbox without turning a wolf into a horse. The hitbox stays generous on
		-- purpose (it is the Panther's, and Job #058 is tuned against it), so you are bitten from slightly
		-- further than the model reaches. Tune here, never in EnemyDefs.
		scale = 1.3,
		yawOffset = 0,
		-- R6-style joints. The bundled `Animate` script is REMOVED at build time (it depends on
		-- Humanoid.Running, which never fires here) and this replaces it.
		joints = {
			parts = { "Left Hip", "Right Hip", "Left Shoulder", "Right Shoulder" },
			amplitude = 0.6,
			hz = 2.2,
		},
		anim = NO_ANIM, -- no animation ids exist for this rig; the joint swing IS its animation
		sound = {
			idle = { id = "", volume = 0.3, min = 12, max = 70, looped = false },
			aggro = { id = "rbxassetid://1989743206", volume = 0.6, min = 20, max = 130 }, -- bundled `Sound`
			attack = { id = "rbxassetid://4064886644", volume = 0.55, min = 15, max = 90 }, -- bundled `Growl`
			hurt = { id = "rbxassetid://137192983266942", volume = 0.5, min = 12, max = 70 },
			death = { id = "rbxassetid://120708334083507", volume = 0.55, min = 15, max = 90 },
		},
	} :: CreatureArt,

	-- ── Bandit — the human raider guarding every camp ────────────────────────────────────────────
	-- A full R15 rig from roblox.defender, so unlike the wolf it CAN play animations: these are the
	-- standard Roblox ids Defender's `AnimationConstants` already uses, loaded onto the Animator the
	-- model ships with. Its six bundled Sounds cover the whole set with no new uploads.
	Bandit = {
		model = "WesternBandit",
		-- 1.0: it is a human and 5.6 studs tall is already right. The 5 x 4 x 11 hitbox is inherited from
		-- the Panther and is deliberately left alone — see EnemyDefs.
		scale = nil,
		yawOffset = 0,
		-- 🔴 THE ONLY CREATURE WITH NO GLOWING EYES, and it should stay that way. He is a person; the
		-- effect is for wildlife. He also has no `EyeLeft`/`EyeRight` attachments, so leaving it on sent
		-- `addEyes` down its hitbox fallback and put two red orbs at his knees — the thing that made this
		-- visible. Giving him attachments would fix the POSITION and still leave a bandit with glowing
		-- eyes, which is not the look.
		eyes = false,
		anim = {
			idle = "rbxassetid://123087002046013", -- AnimationConstants.idleAnimation.idle1
			move = "rbxassetid://913376220", -- runAnimation.first — it charges, it doesn't stroll
			attack = "rbxassetid://80792212061667", -- hitAnimation.hitAnimation1
			death = "",
		},
		sound = {
			idle = { id = "rbxassetid://7995127481", volume = 0.35, min = 12, max = 70, looped = false }, -- Laugh1
			aggro = { id = "rbxassetid://1454256125", volume = 0.6, min = 20, max = 130 }, -- EnemySpottedPlayer
			attack = { id = "rbxassetid://6108540937", volume = 0.55, min = 15, max = 90 }, -- EnemyScream1
			hurt = { id = "rbxassetid://9125652432", volume = 0.5, min = 12, max = 70 }, -- EnemyScream2
			death = { id = "rbxassetid://9125652949", volume = 0.55, min = 15, max = 90 }, -- EnemyScream3
		},
	} :: CreatureArt,

	-- ── RocketMan — the army soldier on the camp watchtower (Job #119) ───────────────────────────
	-- Creator Store `11927692797` "US Army Soldier", free, **0 scripts**. Chosen over eight other free
	-- soldier models for one reason that outranks looks: it is **R15**. Five of the nine candidates were
	-- R6, and an R6 rig in this file has no animations at all — it goes down the hand-swung `joints` path
	-- the Wolf and Boar use — which fails the owner's requirement of *"you need animations for that rocket
	-- man - for close combat"* outright. R15 + 15 Motor6D is the exact shape the Bandit path already
	-- drives, so every id below is a clip this game has already proven on a rig.
	--
	-- ⚠️ **THE MODEL IS STRIPPED AT IMPORT, NOT AT RUNTIME.** As it arrives it is 122 parts, of which a
	-- **37-part Mk18 EoTech carbine** is welded to `RightHand` — with its own `SurfaceGui` sight and 11
	-- gun-mechanism Sounds. He carries a Bazooka, so that subtree is deleted when the model is filed into
	-- `AssetLibrary.Enemies.ArmySoldier`, taking him to **85 parts** and taking the GUI and the sounds with
	-- it. The 39-part helmet and 30-part plate carrier are KEPT: they are most of what makes him read as
	-- "army" rather than as a man in green. If a real device ever complains, the helmet is the lever.
	--
	-- ⚠️ Its inner model ships named `" "` — a single space. It is renamed `ArmySoldier` on import, because
	-- resolution here is by NAME.
	RocketMan = {
		model = "ArmySoldier",
		-- 1.0: he is a human and 5.77 studs tall is already right — the same call the Bandit's entry makes,
		-- and the reason his hitbox was measured from the rig rather than inherited.
		scale = nil,
		-- 0, MEASURED not guessed: the rig's `HumanoidRootPart.CFrame.LookVector` reads (0, 0, -1) at
		-- identity, and -Z is our forward. Do not "fix" this from a screenshot (see the crocodile's note).
		yawOffset = 0,
		-- 🔴 NO GLOWING EYES, for exactly the Bandit's two reasons: he is a PERSON, and he carries no
		-- `EyeLeft`/`EyeRight` attachments, so leaving it on sends `addEyes` down its hitbox fallback and
		-- puts two red orbs somewhere around his knees.
		eyes = false,
		-- ── The animation set, Job #119. EVERY ID IS ALREADY OWNED — nothing was sourced. ───────────
		-- `EnemyRig` reuses the rig's own Animator when the model ships one (it does), because adding a
		-- second Animator alongside it silently plays nothing.
		anim = {
			-- ── 🔴 NO IDLE CLIP, AND THAT IS A MEASURED FIX, NOT AN OMISSION ─────────────────────────
			--
			-- This was `ItemDefs.HOLD_ANIM` (507768375), the player's own tool-carry pose. Measured in Play
			-- on 2026-08-25 it put the launcher **88° off — pointing at the sky**, and only on the CLIENT:
			--
			--                 RightHand (rel. root)        launcher pitch
			--   SERVER        (0.31,  0.01, -0.97)         +0.0°   dot-forward  1.00
			--   CLIENT        (0.31,  1.60, -0.78)         +88.0°  dot-forward -0.04
			--
			-- The cause is the one thing about NPCs that differs from players, and it is worth writing down
			-- because nothing else in this codebase hits it. `InventoryService` solves a held weapon's grip
			-- from the LIVE POSED HAND, and its comment explains why that works: *"The server sees the POSED
			-- hand (the owning client replicates its animated CFrames back)"*. **An NPC has no owning
			-- client.** The server-side Animator reports every track at weight 0.00 and holds the authored
			-- rest pose, while each client evaluates the clip and renders the raised forearm — so a grip
			-- solved server-side is solved against a pose no player ever sees. This is precisely the failure
			-- `WeaponAssets`' header describes ("the carry pose rotates the forearm ~90°, so anything
			-- authored against the old arms-down stance broke... both guns aimed ~80° off").
			--
			-- ⚠️ AND THE FIX IS NOT TO CHASE IT WITH AN OFFSET. This rig is a soldier who was published
			-- CARRYING AN M4 — its authored rest pose IS an arms-forward, two-handed weapon grip, which is
			-- exactly why the server reading is a perfect +0.0°. Playing a generic Roblox carry pose on top
			-- of it fights a pose that was already right. With no idle clip, client and server agree and the
			-- launcher sits level along his facing on both.
			--
			-- He is a sentry on a tower, so dead-still is a fair read. If he ever wants breathing, the clip
			-- must be one authored for a rifle carry — anything that moves the arms re-opens the above.
			idle = "",
			-- ⚠️ NO `move`, DELIBERATELY. He does not walk (see `EnemyDefs.RocketMan`), so a walk cycle would
			-- only ever play as a man jogging on the spot. `tickRocketMan` holds him on "idle" always.
			-- ── close combat: TWO swings, alternated ─────────────────────────────────────────────────
			-- This is the requirement-6 deliverable. Defender's `axeSlash` pair, which `MeleeServer` already
			-- alternates for the player's own swings "so repeated swings do not look canned" — the same
			-- trick, for the same reason, on the other side of the fight.
			attack = "rbxassetid://567480700",
			attack2 = "rbxassetid://567479941",
			-- ── 🔴 THE FIRE SLOT IS DELIBERATELY EMPTY. THIS IS THE ONE THING STILL MISSING. ─────────
			-- It briefly held Defender's `hitAnimation1` (80792212061667) as a stand-in recoil. That clip is
			-- a PUNCH: it swings the arm through roughly the same arc as the two melee slashes below, which
			-- on the arm holding a 6.5-stud shoulder launcher reads as him throwing the weapon rather than
			-- firing it. GROUND-RULES §4 is explicit that an empty slot beats a wrong one, because a wrong
			-- asset is much harder to notice than a missing one.
			--
			-- Nothing is lost by leaving it out: the launch is already carried by the rocket itself, the red
			-- ring, the whistle and the fire sound, all of which come from the player's own Bazooka.
			--
			-- What to source: a STANDING SHOULDER-FIRE / RPG RECOIL R15 clip, ~0.6-1.2 s, ONE-SHOT (not
			-- looped), that moves the torso and not the arms. Drop the id on this line; nothing else changes.
			fire = "",
			-- No death clip. The Bandit has none either; `EnemyRig.die` handles the fall-back.
			death = "",
		},
		-- The Bandit's own bundled set, shared deliberately: a human raider's voice on a human raider, and
		-- the registry's dedupe-by-id rule. ⚠️ His OWN 11 sounds are all gun-mechanism noises (bolt, mag,
		-- safety) attached to the carbine that gets stripped, so they leave with it — there is nothing of
		-- his to reuse.
		sound = {
			idle = { id = "", volume = 0.3, min = 12, max = 70, looped = false },
			-- Widest rolloff of the set on purpose: this is the "he has seen you" cue, and it has to carry
			-- across a 160-stud basin before the first shell lands.
			aggro = { id = "rbxassetid://1454256125", volume = 0.65, min = 25, max = 180 },
			attack = { id = "rbxassetid://6108540937", volume = 0.55, min = 15, max = 90 },
			hurt = { id = "rbxassetid://9125652432", volume = 0.5, min = 12, max = 80 },
			death = { id = "rbxassetid://9125652949", volume = 0.6, min = 15, max = 100 },
		},
	} :: CreatureArt,

	-- ── Piranha — sea, and the one that spawns in NUMBERS ────────────────────────────────────────
	-- ⚠️ Its VFX are deliberately the thinnest of any creature. `EnemyServer` allows up to 9 sea enemies
	-- at once and the piranha is the most heavily weighted of the three, so whatever it emits is emitted
	-- ~6 times over. A wake per fish at the crocodile's rate would be the single biggest particle cost
	-- in the game.
	Piranha = {
		model = "Piranha",
		-- measured: mesh 2.24 x 3.41 x 7.60; 4 / 7.60 = 0.526 → 1.2 x 1.8 x 4.0 against a 2 x 1.2 x 4 hitbox.
		-- Taller than the hitbox, which is correct — a piranha is laterally compressed.
		-- ⚠️ **+30% (0.526 → 0.684) on user direction 2026-08-16.** Its `sink` is left alone — at 0.35 it
		-- already shows its dorsal fin, and the bigger body shows more of it for free.
		scale = 0.684,
		-- head at -Z: the +Z end pinches to a 0.47-tall waist then flares tall with ZERO width — a caudal fin.
		yawOffset = 0,
		water = {
			sink = 0.35, -- barely under; a piranha shows its dorsal fin, not its back
			bobAmp = 0.1,
			bobHz = 0.9,
			rollDeg = 6,
			rollHz = 0.8,
			wagDeg = 9, -- fast and twitchy — it is a darting fish, not a drifting log
			wagHz = 2.4,
		},
		vfx = { wakeRate = 6, wakeScale = 0.6, splashOnAttack = 6, splashScale = 0.5, splashOnDeath = 10 },
		anim = NO_ANIM,
		-- 🔴 SILENT ON PURPOSE — do not "finish" this by adding a sound set.
		-- 1. Up to ~6 piranha are alive at once, so ANY per-creature cue plays six times over. That is
		--    exactly the stacking mistake `GameSoundscape`'s header documents with the cicadas.
		-- 2. The boat already has audio feedback when it is bitten: `boat_hit` (131954812341128) fires on
		--    hull damage with volume scaled to the bite. A piranha attack is therefore ALREADY audible.
		-- 3. A 2-stud fish has nothing to roar with. Its read is the swarm you can see plus the hull cue.
		-- If the swarm ever needs its own voice, the right answer is ONE shared 2D/positional "frenzy" bed
		-- owned by the spawn director, not five clips on every fish.
		sound = NO_SOUND,
	} :: CreatureArt,

	-- ── RiverHippo — sea, slow and heavy ─────────────────────────────────────────────────────────
	RiverHippo = {
		model = "RiverHippo",
		-- measured: mesh 6.04 x 6.70 x 11.40; 12 / 11.40 = 1.053 → 6.4 x 7.1 x 12.0 against an 8 x 5 x 12 hitbox.
		-- ⚠️ **DOUBLED AGAIN (1.369 → 2.738) on user direction 2026-08-16** — "increase hippo like twice".
		-- Compounded on the earlier +30%, so it is 2.6x its original 1.053. Rendered size is now
		-- **16.5 x 18.3 x 31.2 studs** — as long as the 32-stud boat hull. That is a deliberate boss-scale
		-- read, not a mistake; the HITBOX is still 8 x 5 x 12, so every aggro/bite/leash distance the AI
		-- was tuned against is untouched and the art simply overhangs it.
		scale = 2.738,
		-- head at -Z: the muzzle drops to y -0.32 and there is a clear NECK PINCH at z = -2.76 (width 3.98
		-- between 4.98 and 4.32) before the barrel body widens toward +Z.
		yawOffset = 0,
		water = {
			-- ⚠️ 1.9 → 0.8 → **1.6**, tracking the scale changes. Sink is an ABSOLUTE drop, so doubling the
			-- model without doubling this would have shoved a now-18-stud-tall hippo 9 studs into the air.
			-- 1.6 keeps the SUBMERGED FRACTION identical to the 0.8 version (41% of it shows), so it reads
			-- exactly as before, just twice the size.
			sink = 1.6,
			bobAmp = 0.3,
			bobHz = 0.22, -- slow, heavy swell
			rollDeg = 3,
			rollHz = 0.18,
			wagDeg = 1.5, -- barely wags; it wallows rather than swims
			wagHz = 0.3,
		},
		vfx = { wakeRate = 30, wakeScale = 1.5, splashOnAttack = 55, splashScale = 1.8, splashOnDeath = 80 },
		anim = NO_ANIM,
		-- Shares the CROCODILE's set (user decision, 2026-08-15). They are both big reptilian-sounding
		-- river threats and the clips are generic enough to carry it; the wider rolloff below is the only
		-- difference, because a hippo should be audible further out than a croc. Give it its own bellow
		-- later and these lines just get overridden.
		sound = {
			idle = { id = "rbxassetid://137066735880685", volume = 0.4, min = 20, max = 120, looped = false },
			aggro = { id = "rbxassetid://108958436464973", volume = 0.65, min = 25, max = 170 },
			attack = { id = "rbxassetid://94063943857259", volume = 0.7, min = 20, max = 130 },
			hurt = { id = "rbxassetid://137192983266942", volume = 0.55, min = 15, max = 100 },
			death = { id = "rbxassetid://120708334083507", volume = 0.7, min = 20, max = 140 },
		},
	} :: CreatureArt,

	-- ── Not yet in scope ─────────────────────────────────────────────────────────────────────────
	-- ── Boar — land pack hunter, reused from roblox.defender ─────────────────────────────────────
	-- The same shape of asset as the Wolf: an R6 rig with the identical five joint names, a bundled
	-- legacy `Animate` script and no animation ids. So it gets the identical treatment — script stripped
	-- at build, joints swung by hand.
	Boar = {
		model = "Boar",
		-- measured: the rig is 6.00 x 7.29 x 9.00 against a 4 x 3 x 7 hitbox. 0.778 puts its length on
		-- the hitbox; it stays taller than the box, which is fine (the box is invisible).
		scale = 0.778,
		yawOffset = 0,
		joints = {
			parts = { "Left Hip", "Right Hip", "Left Shoulder", "Right Shoulder" },
			-- faster and shorter than the wolf's stride: a boar trots and charges, it does not lope
			amplitude = 0.5,
			hz = 3.0,
		},
		anim = NO_ANIM,
		sound = {
			idle = { id = "", volume = 0.3, min = 12, max = 70, looped = false },
			aggro = { id = "rbxassetid://104582648268587", volume = 0.6, min = 20, max = 130 }, -- pig-noticed_me
			attack = { id = "rbxassetid://139588447817895", volume = 0.55, min = 15, max = 90 }, -- pig-attack
			hurt = { id = "rbxassetid://137192983266942", volume = 0.5, min = 12, max = 70 }, -- shared animal-hurt
			death = { id = "rbxassetid://125997883726975", volume = 0.55, min = 15, max = 90 }, -- pig-killed
		},
	} :: CreatureArt,
} :: { [string]: CreatureArt }

-- ── BanditBoss — the end-zone warlord (Job #121) ──────────────────────────────────────────────────
-- 🔴 DERIVED FROM `Bandit` AT LOAD, NOT COPY-PASTED, AND THAT IS DELIBERATE.
--
-- He is the same `WesternBandit` rig wearing the same six sounds and the same four animation ids; the only
-- thing that differs is how big he renders. Writing those tables out a second time would mean that the next
-- time someone retunes a bandit scream or swaps his run clip, the boss keeps the old one and nobody notices
-- for a month. `Bandit`'s entry is the single source; this is a shallow copy of it with `scale` overridden.
--
-- ⚠️ `scale = 1.6` and `EnemyRig` applies it as `visual:ScaleTo(visual:GetScale() * art.scale)` — RELATIVE,
-- see that function's own note. So 1.6 means "1.6× however a bandit already looks", which is what makes it
-- survive the model being re-imported at a different authored scale.
--
-- ⚠️ `Model:ScaleTo` moves Motor6D offsets and Attachments with the parts, which is why an R15 rig can be
-- scaled and still animate — the clips are rotational. This is the supported path; do NOT reach for
-- per-part `Size *=`, which would leave the joints where they were and tear the rig apart.
--
-- ⚠️ `eyes = false` comes along in the copy and must stay false, for the Bandit's own two reasons: he is a
-- PERSON, and the rig carries no `EyeLeft`/`EyeRight` attachments, so enabling it sends `addEyes` down its
-- hitbox fallback and puts two red orbs somewhere around his knees — now at 1.6× the size.
do
	local boss: CreatureArt = table.clone(EnemyAssets.ART.Bandit)
	boss.scale = 1.6
	EnemyAssets.ART.BanditBoss = boss
end

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
