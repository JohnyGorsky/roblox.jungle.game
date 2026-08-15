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

	-- ── Job #075 — in-run HUD set. ⚠️ PLACEHOLDERS, NOT YET UPLOADED ─────────────────────────────
	-- Every key below is `""` on purpose. `Components.icon` resolves an empty id through
	-- `Theme.iconFallback` (right-hand column of that table), so the HUD renders a sensible stand-in at
	-- the correct size and position instead of an empty square — layout and screenshots stay honest
	-- while the art is being sourced.
	--
	-- TO LAND THE REAL ART: paste the rbxassetid here, then delete that key's row from BOTH
	-- `iconPending` and `iconFallback`. `Theme.reportPendingIcons()` prints what's still outstanding.
	-- Sourcing table: ASSETS.md §5.2. Same Flaticon author as the 23 above (ASSETS.md §1.9).
	salvage = "", -- scrap/salvage pile — Salvage currency chip
	metal = "", -- metal plate/girder — cargo chip, repair resource
	ammoBox = "", -- ammo box/bullets — cargo chip, ammo readout
	heart = "", -- heart — player health bar
	machete = "", -- machete/sword — hotbar slot (default weapon)
	pistol = "", -- pistol — hotbar slot
	bandage = "", -- bandage — hotbar slot
	flag = "", -- checkered flag — END marker on the river bar
	warning = "", -- warning triangle — low fuel, boat under attack
	sun = "", -- sun — day phase
	moon = "", -- moon — night phase
	skull = "", -- skull — downed overlay, crew-lost result
	shotgun = "", -- shotgun — hotbar slot (optional)
	rope = "", -- rope/knot — untie affordance (optional)
	pin = "", -- map pin — dock marker on the river bar (optional)
	clipboard = "", -- clipboard — objectives tab (optional)
}

-- Which §075 keys are still awaiting art. Delete a row when its id lands above.
Theme.iconPending = {
	"salvage", "metal", "ammoBox", "heart", "machete", "pistol", "bandage", "flag",
	"warning", "sun", "moon", "skull", "shotgun", "rope", "pin", "clipboard",
}

-- Stand-in art for a pending key -> an EXISTING key from the verified 23. Chosen so the substitute is
-- semantically close enough to read correctly in a screenshot, never so close that we forget to
-- replace it. `Components.icon` consults this only when the real id is empty.
Theme.iconFallback = {
	salvage = "crate", -- scrap goes in a crate
	metal = "tools",
	ammoBox = "gun",
	heart = "medkit",
	machete = "tools",
	pistol = "gun",
	bandage = "medkit",
	flag = "bounty", -- target = the thing you're heading for
	warning = "bounty",
	sun = "star",
	moon = "star",
	skull = "crew",
	shotgun = "gun",
	rope = "tools",
	pin = "fuel", -- the pin we draw marks a FUEL landing
	clipboard = "check",
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
	Axe = "machete", -- Job #079: the starting melee is an axe now (icon still the machete placeholder)
	Torch = "spotlight", -- a carried lamp; the searchlight glyph is the closest in the set
	Pistol = "pistol",
	Shotgun = "shotgun",
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
	-- `cosmeticBundle` art removed in Job 067 along with the pass itself — it was live and delivered
	-- nothing. Its id stays recorded in registry images.md in case the bundle is ever actually built.
}

-- Fallback icon key for a monetization item with no store art yet (Job 067). Components.icon prefers
-- `image` and falls back to `name`, so a row can pass BOTH and get real art the moment it is uploaded,
-- with a sensible vocabulary icon until then — rather than an empty badge.
Theme.productFallbackIcon = {
	extraSlots = "crate", -- carrying more
	selfRevive = "medkit", -- getting back up
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

	-- ⚠️ PLACEHOLDERS, NOT YET SOURCED — Pixabay, see ASSETS.md §5.2.
	-- Empty ids are a silent no-op in UISound (it skips them rather than building a dead Sound), so
	-- everything below is wired at its call site already and starts working the moment an id lands.
	lowFuel = "", -- single soft warning beep — fuel < 20%
	lowHull = "", -- metallic stress groan — hull < 30%
	downed = "", -- low thud + breath — you go down
	emptyClick = "rbxassetid://75733077651437", -- empty_gun (uploaded 2026-08-05) — dry trigger click
	revived = "", -- rising recovery swell — picked back up
	runLost = "", -- somber descending sting — crew wiped
}

-- Same contract as iconPending: delete a row when its id lands above.
Theme.soundPending = { "lowFuel", "lowHull", "downed", "revived", "runLost" }

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
