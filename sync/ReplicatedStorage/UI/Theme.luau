--!strict
-- Theme.luau — the design system's TOKENS (Job 065). Client/server safe, no instances created here.
--
-- This is the ONLY file where a colour, font, size or asset id for the UI is written down. Screens read
-- `Theme.*` and nothing else — a raw Color3.fromRGB or Enum.Font left in a screen file is a bug.
-- Values are STYLEGUIDE.md §4 (palette), §5 (typography) and §6 (UI) verbatim; asset ids come from the
-- shared registry (roblox.workspace/Assets/registry/{images,audio}.md), all Studio-verified 2026-07-30.
--
-- ⚠️ THIS FILE EXISTS TWICE — `lobby/sync/ReplicatedStorage/UI/` and `sync/ReplicatedStorage/UI/` — and
-- the two copies are BYTE-IDENTICAL BY CONTRACT (Job #074 ported it to the game place for the Robux
-- shop). Same deal as MonetizationDefs / BoatParts / BoatPaint: two Rojo trees, no shared package layer.
-- Edit one, copy it to the other in the same commit; `diff -r` between the two UI folders must be silent.

local Theme = {}

-- ── Colour (STYLEGUIDE §4) ────────────────────────────────────────────────────────────────────────
-- Accents MEAN something: gold = major progression, green = confirm/positive, blue = utility,
-- red = danger/cancel, yellow = warning. An accent used decoratively is a bug.
Theme.color = {
	-- jungle
	jungleDark = Color3.fromRGB(27, 52, 28), -- #1B341C
	jungleMain = Color3.fromRGB(49, 85, 43), -- #31552B
	palmLeaf = Color3.fromRGB(71, 113, 58), -- #47713A
	-- surfaces
	panel = Color3.fromRGB(36, 53, 45), -- #24352D  panel fill (green-tinted)
	panelAlt = Color3.fromRGB(36, 53, 66), -- #243542  alt/cooler surface
	sunken = Color3.fromRGB(24, 34, 29), -- darker inset: bar tracks, icon chips, rows
	scrim = Color3.fromRGB(8, 12, 10), -- modal dim behind popups
	-- wood / metal (borders + physical accents)
	wood = Color3.fromRGB(128, 97, 66), -- #806142  the UI border tone
	woodDark = Color3.fromRGB(76, 55, 37), -- #4C3725
	metal = Color3.fromRGB(78, 82, 70), -- #4E5246
	metalDark = Color3.fromRGB(53, 58, 53), -- #353A35
	-- accents
	gold = Color3.fromRGB(214, 155, 34), -- #D69B22  major progression / gold tier
	green = Color3.fromRGB(75, 122, 43), -- #4B7A2B  primary buttons / positive
	blue = Color3.fromRGB(53, 107, 154), -- #356B9A  secondary / utility
	red = Color3.fromRGB(168, 75, 60), -- #A84B3C  danger / cancel
	yellow = Color3.fromRGB(213, 161, 43), -- #D5A12B  warning / highlight
	-- text
	cream = Color3.fromRGB(243, 230, 194), -- #F3E6C2  primary text — NEVER pure white
	creamDim = Color3.fromRGB(188, 178, 150), -- muted body / captions
	stroke = Color3.fromRGB(15, 22, 17), -- dark text stroke + outlines
}

-- party pad colours, by pad name (STYLEGUIDE §6.9 — always distinct, never hidden)
Theme.padColor = {
	Blue = Theme.color.blue,
	Red = Theme.color.red,
	Green = Theme.color.green,
	Yellow = Theme.color.yellow,
}

-- ── Typography (STYLEGUIDE §5) ────────────────────────────────────────────────────────────────────
-- All faces are built into Roblox — zero uploads. Physical/decorative faces (sign, marker) are for the
-- 3D world and hero headings ONLY; small UI text stays Builder Sans.
-- GOTCHA: Font.fromName("Special Elite") FAILS — the family name has no space. Use the enum (as here)
-- or Font.fromName("SpecialElite").
Theme.font = {
	display = Enum.Font.BuilderSansExtraBold,
	heading = Enum.Font.BuilderSansExtraBold,
	button = Enum.Font.BuilderSansBold,
	body = Enum.Font.BuilderSansMedium,
	bodyBold = Enum.Font.BuilderSansBold,
	sign = Enum.Font.SpecialElite, -- physical world signs only (decision #1)
	marker = Enum.Font.PermanentMarker, -- improvised crate/warning labels
	mono = Enum.Font.RobotoMono, -- optional stat readouts
}

-- Size caps, mobile-first: always TextScaled = true inside a sized box, clamped by a
-- UITextSizeConstraint. { max, min } — max is the desktop-equivalent cap, min the phone floor.
export type TextSize = { max: number, min: number }
Theme.text = {
	display = { max = 56, min = 28 } :: TextSize,
	h1 = { max = 30, min = 20 } :: TextSize,
	h2 = { max = 23, min = 18 } :: TextSize,
	button = { max = 22, min = 16 } :: TextSize,
	body = { max = 17, min = 14 } :: TextSize,
	caption = { max = 14, min = 12 } :: TextSize,
}

-- ── Metrics ───────────────────────────────────────────────────────────────────────────────────────
Theme.space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }
Theme.radius = { panel = 12, control = 8, pill = 999 }
Theme.strokeWidth = { panel = 3, control = 2, hairline = 1 }

-- Height of a list row, in pixels. Offset (not scale) because rows live inside a ScrollingFrame with
-- AutomaticCanvasSize, which needs a definite height per item. Text inside still uses TextScaled with a
-- min-size clamp, so it stays legible when the panel narrows on a phone. Verified in the Device
-- Emulator during the mobile pass — change here, not in a screen.
Theme.rowHeight = 66

-- ── Motion (STYLEGUIDE §6.2 states, §8) ───────────────────────────────────────────────────────────
Theme.tween = {
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	normal = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	slow = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	toast = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	pop = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

-- ── Icons (registry images.md → "Lobby UI icon set", verified 2026-07-30) ────────────────────────
-- Semantic key -> asset id. Trailing comment = the uploaded asset name.
-- NOTE: these are FULL-COLOUR flat icons, not mono silhouettes — ImageColor3 multiplies and would
-- muddy them, so they are seated on a dark chip instead of tinted (ASSETS.md §1.9 colour note).
Theme.icon = {
	close = "rbxassetid://140590179467868", -- close
	coin = "rbxassetid://77292050689166", -- coin
	shop = "rbxassetid://113169065974317", -- shop
	star = "rbxassetid://123611506595607", -- star
	wrench = "rbxassetid://90679964955780", -- wrench
	party = "rbxassetid://103042204848069", -- user_group
	calendar = "rbxassetid://78068320446462", -- calendar
	check = "rbxassetid://108692155956143", -- check
	bounty = "rbxassetid://106187109040565", -- target_bounty
	engine = "rbxassetid://94903113819644", -- cogwheel_gear
	hull = "rbxassetid://111545806353192", -- shield
	fuel = "rbxassetid://128001249531842", -- fuel-station
	crate = "rbxassetid://123909056802404", -- box_Create
	tools = "rbxassetid://109933399936454", -- tools
	boat = "rbxassetid://79958224084386", -- motorboat
	crew = "rbxassetid://108066459106452", -- navy_crew
	wheel = "rbxassetid://124599807882020", -- ship-wheel
	medkit = "rbxassetid://87252065857781", -- first-aid-kit
	gun = "rbxassetid://120983452101559", -- machine-gun
	spotlight = "rbxassetid://111067444220887", -- spotlight
	loot = "rbxassetid://121749397596257", -- money-bag
	trophy = "rbxassetid://72442029972402", -- winner_trophy
	robux = "rbxassetid://100088930369566", -- roblox

	-- ── Job #075's in-run HUD set — ✅ ALL 16 LANDED 2026-08-16 ──────────────────────────────────
	-- Uploaded in one batch, same Flaticon author as the 23 above (ASSETS.md §1.9's "one pack, one
	-- author" rule). These were the last empty ids in this file; `iconFallback` is now empty and
	-- `reportPendingIcons` prints nothing, which is the intended end state and not a broken check.
	--
	-- ⚠️ `machete` IS GONE — the key is `axe`. Job #079 made the starting melee an axe, and the old key
	-- only survived because the art hadn't landed. `itemIcon.Axe` points here now.
	salvage = "rbxassetid://132515599590557", -- salvage — Salvage currency chip
	metal = "rbxassetid://108134748683437", -- metal — cargo chip, repair resource
	ammoBox = "rbxassetid://124618084720086", -- ammo_box — cargo chip, ammo readout
	heart = "rbxassetid://80874640548406", -- heart — player health bar
	axe = "rbxassetid://103330813920018", -- axe — hotbar slot (the starting weapon)
	pistol = "rbxassetid://114130100634737", -- pistol — hotbar slot
	bandage = "rbxassetid://92778620303649", -- bandage — hotbar slot
	flag = "rbxassetid://74100920362068", -- flag — END marker on the river bar
	warning = "rbxassetid://134738155945948", -- warning — low fuel, boat under attack
	sun = "rbxassetid://135456974401661", -- sun — day phase
	moon = "rbxassetid://133722357110403", -- crescent-moon — night phase
	skull = "rbxassetid://124574187863147", -- skull — downed overlay, crew-lost result
	shotgun = "rbxassetid://114671213665544", -- shotgun — hotbar slot
	rope = "rbxassetid://93692735532470", -- rope — untie affordance
	pin = "rbxassetid://74040077993361", -- mapp_pin — dock marker on the river bar
	clipboard = "rbxassetid://128096944326660", -- clipboardt — objectives tab

	-- ── Job #104: the trading post's two ammo rows ───────────────────────────────────────────────
	-- User's own uploads, delivered with the job and verified in Studio 2026-08-23 via
	-- `GetProductInfo` → name match + AssetTypeId 1 (Image), creator `johnygorsky10`. Source PNGs are
	-- `assets/Images/clip.png` / `bullets.png`.
	--
	-- ⚠️ These are DELIBERATELY NOT `ammoBox`. That glyph is a crate and is already the boat turret's
	-- ammo (cargo chip + the "Turret Ammo" row); three rows sharing one crate icon is how a player ends
	-- up buying turret belts for the gun in their hand — which is the bug this job exists to fix.
	pistolAmmo = "rbxassetid://98656594796808", -- clip — Pistol Ammo row
	shotgunAmmo = "rbxassetid://107222226747372", -- bullets — Shotgun Ammo row (two shells)

	-- ── Job #117: the M16 ────────────────────────────────────────────────────────────────────────
	-- User's own uploads, delivered with the job (`assets/Enemies/M16/assault-rifle.png` and
	-- `bullet.png`). Both are 512x512 **RGBA** — checked in the PNG headers.
	rifle = "rbxassetid://87494055704448", -- assault-rifle — hotbar slot + BOTH M16 shop rows' fallback
	-- ⚠️ CURRENTLY UNUSED, kept on purpose. It was the "M16 (one run)" row's badge until the user asked
	-- for the rifle there instead (see productIcon below). Left registered because it is the natural glyph
	-- for an M16 ammo row if the trading post ever sells rifle rounds — the same slot `pistolAmmo` and
	-- `shotgunAmmo` fill. Delete it if that never happens.
	rifleAmmo = "rbxassetid://134307949592665", -- bullet (three rifle rounds)

	-- ── Job #118: the Bazooka ────────────────────────────────────────────────────────────────────
	-- User's own uploads (`assets/Enemies/Bazooka/bazooka_icon.png` and `missile.png`), verified in
	-- Studio via `GetProductInfo` → AssetTypeId 1 (Image), creator `johnygorsky10`. Both 512x512
	-- **RGBA** — read from the PNG IHDR (colour type 6), not assumed.
	--
	-- ⚠️ THESE TWO ARE USED AS A PAIR AND MEAN DIFFERENT THINGS. `bazooka` is the WEAPON (hotbar slot,
	-- and the lifetime pass row: you are buying the launcher forever). `rocketAmmo` is ONE ROCKET (the
	-- one-run row: you are buying a run's worth of ammunition). The two shop rows sit adjacent and both
	-- titles start with "Bazooka", so they have to be tellable apart at badge size — the same problem the
	-- two M16 rows had, solved here with meaning rather than with a second upload.
	bazooka = "rbxassetid://76642882799637", -- bazooka_icon — hotbar slot + the lifetime pass row
	rocketAmmo = "rbxassetid://100284588876499", -- missile — the one-run charge row
}

-- Which §075 keys are still awaiting art. Delete a row when its id lands above.
-- ✅ EMPTY as of 2026-08-16 — every icon in the game is real art.
Theme.iconPending = {}

-- Stand-in art for a pending key -> an EXISTING key from the verified 23. Chosen so the substitute is
-- semantically close enough to read correctly in a screenshot, never so close that we forget to
-- replace it. `Components.icon` consults this only when the real id is empty.
Theme.iconFallback = {
	-- ✅ EMPTY as of 2026-08-16. Every key that used to need a stand-in now has real art, and the file's
	-- own rule was "delete that key's row from BOTH iconPending and iconFallback" when the id lands.
	--
	-- ⚠️ THE TABLE STAYS, EMPTY, ON PURPOSE. `Components.icon` indexes it for every icon it draws; an
	-- empty table is a clean miss, a nil table is a crash. It is also the mechanism to reach for the
	-- next time a key is added ahead of its art — that is what it is for, and it worked.
}

-- Studio-only nag so a placeholder can't quietly ship. Called once by HudState on start-up.
function Theme.reportPendingIcons()
	local missing = {}
	for _, key in ipairs(Theme.iconPending) do
		if (Theme.icon :: { [string]: string })[key] == "" then
			table.insert(missing, key)
		end
	end
	if #missing > 0 then
		warn(`[Theme] {#missing} PLACEHOLDER icons still unresolved (Job #075): {table.concat(missing, ", ")}`)
	end
end

-- skill id -> icon key (SkillDefs.Order)
Theme.skillIcon = {
	motors = "engine",
	rudder = "wheel",
	hull = "hull",
	diesel = "fuel",
	cargo = "crate",
	repair = "tools",
	refuel = "fuel",
	medic = "medkit",
	gun = "gun",
	scavenge = "loot",
}

-- boat module id -> icon key (ModuleDefs.Order)
Theme.moduleIcon = {
	motor2 = "engine",
	hullkit = "hull",
	searchlight = "spotlight",
	fueltank = "fuel",
	trailer = "crate",
	gunupgrade = "gun",
	ramps = "boat", -- Job 067: ramp bow / hull shape — it's a hull change, so the hull silhouette reads best
}

-- skill group -> icon key (one shop, Boat/Crew groups — plan decision F)
Theme.groupIcon = { Boat = "boat", Crew = "crew" }

-- loadout item id -> icon key (ItemDefs.Items) — the hotbar, Job #075. Game place only; the lobby has
-- no loadout, but the table lives here for the same reason skillIcon/moduleIcon do: asset keys belong
-- in one file.
Theme.itemIcon = {
	Axe = "axe", -- Job #079 made this an axe; its real glyph landed 2026-08-16
	Torch = "spotlight", -- a carried lamp; the searchlight glyph is the closest in the set
	Pistol = "pistol",
	Shotgun = "shotgun",
	M16 = "rifle", -- Job #117
	Bazooka = "bazooka", -- Job #118
}

-- boat station / role id -> icon key (RoleServer's four stations + the Medic added in Job 057)
Theme.roleIcon = {
	driver = "wheel",
	gunner = "gun",
	engineer = "fuel",
	mechanic = "tools",
	medic = "medkit",
}

-- Monetization art, keyed by MonetizationDefs `id` (gold packs) and `key` (passes).
-- These are the TRANSPARENT-PNG uploads (2026-07-31), not the Creator Hub thumbnails — the Hub versions
-- are matted onto an opaque square/disc, which read as white blobs behind the art in a round badge.
-- The Hub thumbnail ids stay recorded in registry images.md for the store listings themselves.
Theme.productIcon = {
	pack10 = "rbxassetid://72255341573939", -- 10_transparent
	pack25 = "rbxassetid://114957317211525", -- 25_transparent
	pack60 = "rbxassetid://100983946600429", -- 60_transparent
	pack150 = "rbxassetid://133943328068949", -- 150_transparent
	armoredBoat = "rbxassetid://130910653087108", -- Boat_transparent
	boatPaint = "rbxassetid://82416796032835", -- Paint_transparent
	selfRevive = "rbxassetid://131281323216251", -- SelfRevive (uploaded 2026-08-01)
	-- The only row that uses its HUB id in-game. Normally that's the thing to avoid (the 2026-07-20 Hub
	-- uploads are matted onto an opaque disc and render as white blobs in these round badges) — but this
	-- one carries alpha, verified in Play 2026-08-02, so it needs no transparent re-upload.
	extraSlots = "rbxassetid://130798210334331", -- Game Pass Icon (uploaded 2026-08-02)
	-- ── Job #117 — the Lifetime M16 row shows the PASS ARTWORK, on the user's explicit call ──────
	-- The two M16 rows sit next to each other and both titles start with "M16", so they have to be
	-- tellable apart at badge size. The user's split (2026-08-25): *"For Lifetime use pass icon, and one
	-- time use rifle icon"* — the PASS row reads as a product, the ONE-RUN row reads as the weapon.
	--
	-- ⚠️ THIS IS THE STORE-LISTING IMAGE THE USER SUPPLIED FOR THE PASS (`99770814546746`), NOT the raw
	-- `RobloxPassM16.png` upload (`118709115773836`) — that one is 1254x1254 RGB with no alpha and is the
	-- source art for the Hub listing only. Do not substitute one for the other.
	m16Lifetime = "rbxassetid://99770814546746", -- the pass's store image
	-- `cosmeticBundle` art removed in Job 067 along with the pass itself — it was live and delivered
	-- nothing. Its id stays recorded in registry images.md in case the bundle is ever actually built.
}

-- Fallback icon key for a monetization item with no store art yet (Job 067). Components.icon prefers
-- `image` and falls back to `name`, so a row can pass BOTH and get real art the moment it is uploaded,
-- with a sensible vocabulary icon until then — rather than an empty badge.
Theme.productFallbackIcon = {
	extraSlots = "crate", -- carrying more
	selfRevive = "medkit", -- getting back up
	-- ── Job #117 ─────────────────────────────────────────────────────────────────────────────────
	-- The one-run charge gets the RIFLE glyph and has no `productIcon` entry, so this is what it draws —
	-- not a placeholder. The lifetime pass gets its real Hub artwork from `productIcon` above; `rifle`
	-- stays listed for it purely as the safety net if that image ever fails to load.
	-- Split this way on the user's call (2026-08-25): the pass row reads as a PRODUCT, the one-run row
	-- reads as the WEAPON.
	m16Lifetime = "rifle",
	m16 = "rifle",
	-- ── Job #118 — the Bazooka, and NEITHER row has a `productIcon` entry ────────────────────────
	-- 🔴 THAT IS A DECISION, NOT AN OVERSIGHT. `RobloxPassBazooka.png` → `78985801749301` is
	-- **1254x1254 RGB with NO alpha** (PNG IHDR colour type 2, read from the file). That is precisely the
	-- `RobloxPassM16.png` situation, and the M16 pass row only got a clean round badge because the user
	-- supplied a SECOND, transparent store image. No such image exists for the Bazooka, so pointing
	-- `productIcon` at the Hub art would render a white square inside the circular badge.
	--
	-- The split is by MEANING instead, which also solves the "two adjacent rows both starting with
	-- Bazooka" legibility problem the M16 rows had:
	--   · the LIFETIME row shows the launcher — you are buying the weapon, forever
	--   · the ONE-RUN row shows a single rocket — you are buying one run's ammunition
	-- If you would rather the pass row show the artwork, the fix is a TRANSPARENT re-upload of that same
	-- PNG and a `productIcon.bazookaLifetime` entry — not a different icon.
	bazookaLifetime = "bazooka",
	bazooka = "rocketAmmo",
}

-- ── Sounds (registry audio.md, verified 2026-07-30) ──────────────────────────────────────────────
-- `open` and `close` deliberately share one asset (open_close).
Theme.sound = {
	click = "rbxassetid://89108158102227", -- ui_mouse_click
	open = "rbxassetid://89724136900326", -- open_close
	close = "rbxassetid://89724136900326", -- open_close
	prompt = "rbxassetid://83771530109851", -- prompt
	countdown = "rbxassetid://116568191818931", -- timer_countdown (positional, on the pad)
	joinPad = "rbxassetid://118942668007111", -- joined_pad
	leader = "rbxassetid://83295373162555", -- leader_assigned
	launch = "rbxassetid://74173367633003", -- teleport_woosh
	purchase = "rbxassetid://108328452137259", -- purchase_success
	fail = "rbxassetid://95777104498740", -- failed_or_not_allowed
	upgrade = "rbxassetid://98721741422623", -- upgrade_applied
	rank = "rbxassetid://135669512865613", -- rank_completed_or_mission_completed
	footstepWood = "rbxassetid://74260976253608", -- footsteps_wood
	runSand = "rbxassetid://113877578461119", -- running_on_sand

	-- ── Job #075 — in-run HUD cues ──────────────────────────────────────────────────────────────
	-- REUSED from the shared registry (roblox.workspace/Assets/registry/audio.md). Three are filed
	-- under Defender; reuse-before-re-source is the registry's stated purpose, and these are generic
	-- SFX with nothing Defender-specific in them. Pending the user's OK — swap for a Jungle-specific
	-- upload if they'd rather.
	pickup = "rbxassetid://125050168809089", -- item_drop (defender) — loot picked up
	hurt = "rbxassetid://117259006391295", -- player_attacked (defender) — you take damage
	runWin = "rbxassetid://138409734628557", -- level_completed (defender) — run won
	zoneEnter = "rbxassetid://79506043370965", -- battle_starts (jungle) — zone-crossing stinger
	dayBreak = "rbxassetid://88638394432005", -- morning_starts (jungle)
	nightFall = "rbxassetid://75443344927115", -- night_starts_2 (jungle)

	-- ── Job #075's five run-turning cues — ✅ ALL SOURCED 2026-08-16 ────────────────────────────
	-- Uploaded by the user; these were the last empty ids in this table. They were wired at their call
	-- sites from the day the keys existed, so landing the ids is all that was needed to make them audible.
	lowFuel = "rbxassetid://76291949644634", -- low_fuel_warning   — fuel < 20%
	lowHull = "rbxassetid://77018431817918", -- low_hull_warning   — hull < 30%
	downed = "rbxassetid://139285102940691", -- palyer_dawned      — you go down (upload's spelling)
	emptyClick = "rbxassetid://75733077651437", -- empty_gun (uploaded 2026-08-05) — dry trigger click
	revived = "rbxassetid://74705196258655", -- palyer_revived     — picked back up
	runLost = "rbxassetid://94363214324807", -- run_lost_sound     — crew wiped
}

-- Same contract as iconPending: delete a row when its id lands above.
-- ✅ EMPTY as of 2026-08-16 — every HUD sound is sourced. `reportPendingSounds` now prints nothing,
-- which is the intended end state, not a broken check.
Theme.soundPending = {}

function Theme.reportPendingSounds()
	local missing = {}
	for _, key in ipairs(Theme.soundPending) do
		if (Theme.sound :: { [string]: string })[key] == "" then
			table.insert(missing, key)
		end
	end
	if #missing > 0 then
		warn(`[Theme] {#missing} PLACEHOLDER sounds still unresolved (Job #075): {table.concat(missing, ", ")}`)
	end
end

-- ── Colour helpers (button states, §6.2: hover ≈ +8% L, pressed ≈ −10% L, disabled ≈ 50% desat) ──
local function clamp01(n: number): number
	return math.clamp(n, 0, 1)
end

function Theme.lighten(c: Color3, amount: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, clamp01(v + amount))
end

function Theme.darken(c: Color3, amount: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, clamp01(v - amount))
end

function Theme.desaturate(c: Color3, amount: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, clamp01(s * (1 - amount)), v)
end

return Theme
