--!strict
-- AtmosphereRig.luau — the GAME place's lighting / atmosphere / water rig             [Job #073]
-- ============================================================================================
-- Ported from the lobby's `lobby/build/lobby_atmosphere.luau` (STYLEGUIDE §8) and made
-- DAY/NIGHT-AWARE, because unlike the static-afternoon lobby the game runs a real clock
-- (`DayNightServer`).
--
-- ── WHY THIS IS A MODULE AND NOT A BUILD SCRIPT ─────────────────────────────────────────────
-- The lobby bakes its rig into the place with a one-off command-bar script, and ASSETS.md §1.14
-- carries a "Save the place or it resets" warning as a result. Here the values live in ONE
-- version-controlled module with an `apply()` function, required by two callers:
--
--   · `ServerScriptService.World.AtmosphereServer` — drives it from ClockTime every run
--   · the Studio command bar / MCP, to bake the EDIT-time look so we aren't building and
--     screenshotting the world under stock grey lighting:
--
--         print(require(game.ReplicatedStorage.World.AtmosphereRig).apply(16.1))
--
-- One source of truth, in git, and a place reset costs the editor look but never the runtime one.
--
-- ── WHAT VARIES AND WHAT DOES NOT ───────────────────────────────────────────────────────────
-- `STATIC` is applied once: it is the stuff that defines the LOOK regardless of hour (latitude,
-- exposure, post-effects, water). `KEYFRAMES` is the stuff that defines the HOUR, lerped between
-- keyframes: ambient, sun brightness, atmosphere and colour correction.
--
-- ⚠️ `ClockTime` is deliberately NOT in here. `DayNightServer` owns the clock; this rig reads it
-- and must never write it, or the two would fight every frame.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local AtmosphereRig = {}

-- ── the time-varying palette ────────────────────────────────────────────────────────────────
export type Palette = {
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	-- exposure + env diffuse are HOURLY, not static, and that was measured rather than assumed:
	-- at the lobby's static 0.12 / 0.5 the first night build came out pitch black (screenshotted —
	-- sand unreadable, palms flat silhouettes), which STYLEGUIDE §8 explicitly forbids. Lifting these
	-- two at night is what makes a moonlit night READABLE without washing it into day-for-night.
	exposure: number,
	envDiffuse: number,
	atmDensity: number,
	atmColor: Color3,
	atmDecay: Color3,
	atmGlare: number,
	atmHaze: number,
	ccTint: Color3,
	ccSaturation: number,
	ccContrast: number,
}

-- 16:00 — THE CANONICAL LOOK. These are the lobby's accepted values verbatim (Job #064, confirmed
-- against the live lobby place 2026-08-02 with zero drift). Everything else below is derived from
-- this by moving the sun; if the house style ever changes, it changes here first.
local DAY: Palette = {
	brightness = 2.7,
	ambient = Color3.fromRGB(74, 72, 56),
	outdoorAmbient = Color3.fromRGB(104, 106, 80),
	exposure = 0.12,
	envDiffuse = 0.5,
	atmDensity = 0.40,
	atmColor = Color3.fromRGB(196, 186, 150),
	atmDecay = Color3.fromRGB(158, 120, 72),
	atmGlare = 0.32,
	atmHaze = 2.7,
	ccTint = Color3.fromRGB(255, 240, 212),
	ccSaturation = 0.13,
	ccContrast = 0.07,
}

-- 09:00 — cooler and fresher than the afternoon, slightly hazier (morning mist off the river).
local MORNING: Palette = {
	brightness = 2.6,
	ambient = Color3.fromRGB(70, 74, 62),
	outdoorAmbient = Color3.fromRGB(100, 108, 88),
	exposure = 0.12,
	envDiffuse = 0.5,
	atmDensity = 0.42,
	atmColor = Color3.fromRGB(198, 196, 178),
	atmDecay = Color3.fromRGB(150, 150, 130),
	atmGlare = 0.20,
	atmHaze = 2.9,
	ccTint = Color3.fromRGB(246, 248, 240),
	ccSaturation = 0.11,
	ccContrast = 0.06,
}

-- 06:30 — the start of every run. Low golden sun through heavy mist; the crash lands here.
local DAWN: Palette = {
	brightness = 2.3,
	ambient = Color3.fromRGB(66, 60, 54),
	outdoorAmbient = Color3.fromRGB(92, 88, 76),
	exposure = 0.14,
	envDiffuse = 0.55,
	atmDensity = 0.48,
	atmColor = Color3.fromRGB(206, 180, 148),
	atmDecay = Color3.fromRGB(188, 120, 80),
	atmGlare = 0.30,
	atmHaze = 3.2,
	ccTint = Color3.fromRGB(255, 232, 206),
	ccSaturation = 0.14,
	ccContrast = 0.06,
}

-- 17:30 — hot horizon, long shadows. This is also where `LightController` switches the NightLights
-- on (its DUSK = 17.5), so the world warms up at the same moment the practicals appear.
local DUSK: Palette = {
	brightness = 2.2,
	ambient = Color3.fromRGB(64, 54, 46),
	outdoorAmbient = Color3.fromRGB(88, 78, 64),
	exposure = 0.15,
	envDiffuse = 0.55,
	atmDensity = 0.46,
	atmColor = Color3.fromRGB(200, 168, 130),
	atmDecay = Color3.fromRGB(176, 100, 56),
	atmGlare = 0.38,
	atmHaze = 3.0,
	ccTint = Color3.fromRGB(255, 226, 196),
	ccSaturation = 0.16,
	ccContrast = 0.08,
}

-- Night. Cool, desaturated, and thinner air than the day (a milky night sky reads as fog, not dark).
--
-- ⚠️ It is deliberately NOT pitch black. STYLEGUIDE §8 forbids a pitch-black jungle, and right now the
-- world has NOTHING to light it with — the base camp has zero Light objects and no fire pit or lantern,
-- and the only `NightLight`-tagged lights in the game are CARRIED (player torch, boat searchlight). So
-- `outdoorAmbient` here is doing the job camp practicals should be doing. When those get built, this
-- should come DOWN so the pools of light actually read. See Planned/ camp-night-practicals.
--
-- `brightness` at night is moonlight, not sun: the moon is still the light source even though
-- DayNightServer hides its disc (MoonAngularSize 0, TODO 0009 — it read as too shiny).
--
-- These numbers were tuned BY SCREENSHOT at 22:00 over the base camp, not derived. Two passes:
--   A first attempt carried the lobby's static exposure 0.12 / envDiffuse 0.5 into the night and came
--   out effectively pitch black. Lifting those two (0.26 / 0.85) is what made it readable.
--   A second pass pulled ccSaturation back from −0.10 to −0.04 and cooled the tint less, because at
--   −0.10 the sand read as grey SNOW rather than sand under moonlight.
local NIGHT: Palette = {
	brightness = 1.5,
	ambient = Color3.fromRGB(44, 50, 64),
	outdoorAmbient = Color3.fromRGB(66, 76, 96),
	exposure = 0.26,
	envDiffuse = 0.85,
	atmDensity = 0.34,
	atmColor = Color3.fromRGB(60, 72, 92),
	atmDecay = Color3.fromRGB(30, 40, 60),
	atmGlare = 0.05,
	atmHaze = 1.2,
	ccTint = Color3.fromRGB(200, 214, 250),
	ccSaturation = -0.04,
	ccContrast = 0.12,
}

-- Keyframes MUST stay sorted by hour, and hour 0 and 24 MUST hold the same palette so midnight
-- wraps seamlessly. The 6.5 / 17.5 keys are aligned with `LightController`'s DAWN / DUSK so the
-- palette turns at the same moment the lights do.
local KEYFRAMES: { { hour: number, palette: Palette } } = {
	{ hour = 0.0, palette = NIGHT },
	{ hour = 5.0, palette = NIGHT },
	{ hour = 6.5, palette = DAWN },
	{ hour = 9.0, palette = MORNING },
	{ hour = 16.1, palette = DAY },
	{ hour = 17.5, palette = DUSK },
	{ hour = 19.5, palette = NIGHT },
	{ hour = 24.0, palette = NIGHT },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function paletteAt(hour: number): Palette
	local h = hour % 24
	local lo, hi, t = KEYFRAMES[1], KEYFRAMES[#KEYFRAMES], 0
	for i = 1, #KEYFRAMES - 1 do
		local a, b = KEYFRAMES[i], KEYFRAMES[i + 1]
		if h >= a.hour and h <= b.hour then
			lo, hi = a, b
			local span = b.hour - a.hour
			t = if span > 0 then (h - a.hour) / span else 0
			break
		end
	end
	local A, B = lo.palette, hi.palette
	return {
		brightness = lerp(A.brightness, B.brightness, t),
		ambient = A.ambient:Lerp(B.ambient, t),
		outdoorAmbient = A.outdoorAmbient:Lerp(B.outdoorAmbient, t),
		exposure = lerp(A.exposure, B.exposure, t),
		envDiffuse = lerp(A.envDiffuse, B.envDiffuse, t),
		atmDensity = lerp(A.atmDensity, B.atmDensity, t),
		atmColor = A.atmColor:Lerp(B.atmColor, t),
		atmDecay = A.atmDecay:Lerp(B.atmDecay, t),
		atmGlare = lerp(A.atmGlare, B.atmGlare, t),
		atmHaze = lerp(A.atmHaze, B.atmHaze, t),
		ccTint = A.ccTint:Lerp(B.ccTint, t),
		ccSaturation = lerp(A.ccSaturation, B.ccSaturation, t),
		ccContrast = lerp(A.ccContrast, B.ccContrast, t),
	}
end

AtmosphereRig.paletteAt = paletteAt

-- ── adopting what the place already has ─────────────────────────────────────────────────────
-- EVERY enabled PostEffect is a full-screen pass and costs real frames on mobile, so the rule is
-- ADOPT, never add-alongside. The game place shipped with exactly the two strays Job #069 cleaned
-- out of the lobby:
--
--   · a `BloomEffect` named "Bloom" — values 1 / 24 / 2, byte-identical to JungleBloomHighlight
--   · a `SunRaysEffect` named "SunRays" at Intensity 0.01 / Spread 0.1 — invisible, but still a pass
--
-- Creating our own beside them would have left the game running SIX passes to the lobby's four,
-- with two of them doing nothing visible.

local function claim(className: string, name: string, taken: { [Instance]: true }): Instance
	local exact = Lighting:FindFirstChild(name)
	if exact and exact:IsA(className) and not taken[exact] then
		taken[exact] = true
		return exact
	end
	for _, c in Lighting:GetChildren() do
		if c:IsA(className) and not taken[c] then
			c.Name = name -- adopt a stray rather than adding another full-screen pass
			taken[c] = true
			return c
		end
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	taken[made] = true
	return made
end

-- Applies everything that does NOT depend on the hour. Idempotent — safe to re-run.
-- Returns the list of properties Studio refused to let us write (see the pcall note below).
local function applyStatic(): { string }
	local refused: { string } = {}
	local function try(label: string, fn: () -> ())
		if not pcall(fn) then
			table.insert(refused, label)
		end
	end

	Lighting.GeographicLatitude = 25
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	-- ExposureCompensation + EnvironmentDiffuseScale are NOT here — they are hourly (see Palette)

	-- These three are the modern Future-lighting controls (Job #069 established that `Technology` no
	-- longer exists as a settable/readable property). They are gated the way `Technology` was, so each
	-- is attempted individually and REPORTED rather than assumed silently applied.
	--
	-- 📏 Measured 2026-08-02 from the Studio command bar (a PRIVILEGED context — if it is refused
	-- there it is refused everywhere):
	--   · ShadowSoftness            ✅ writable  (already 0.2 in both places)
	--   · PrioritizeLightingQuality ❌ refused   — harmless, the game place is already `true`
	--   · LightingStyle             ❌ refused   — ⚠️ NOT harmless. The game place is `Soft` and the
	--     lobby is `Realistic`. This is the one value in the whole rig that a script cannot deliver;
	--     it must be set BY HAND in Studio → Lighting → Properties → LightingStyle = Realistic, and
	--     the place SAVED. `apply()` returns it in the REFUSED list so it can't be quietly forgotten.
	try("LightingStyle", function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic
	end)
	try("ShadowSoftness", function()
		(Lighting :: any).ShadowSoftness = 0.2
	end)
	try("PrioritizeLightingQuality", function()
		(Lighting :: any).PrioritizeLightingQuality = true
	end)

	local taken: { [Instance]: true } = {}

	local atm = claim("Atmosphere", "Atmosphere", taken) :: Atmosphere
	atm.Offset = 0.20 -- Density/Color/Decay/Glare/Haze are hourly — see applyPalette

	-- TWO blooms, both deliberate (lobby Job #069): a low-threshold gentle layer for the overall glow,
	-- and a high-threshold strong layer that punches only the brightest things (water sparkle, sun,
	-- the burning wreck). Keep it at two — a third should be merged, not added.
	local bl = claim("BloomEffect", "JungleBloom", taken) :: BloomEffect
	bl.Intensity, bl.Size, bl.Threshold, bl.Enabled = 0.5, 24, 1.4, true

	local blh = claim("BloomEffect", "JungleBloomHighlight", taken) :: BloomEffect
	blh.Intensity, blh.Size, blh.Threshold, blh.Enabled = 1, 24, 2, true

	local sr = claim("SunRaysEffect", "JungleSunRays", taken) :: SunRaysEffect
	sr.Intensity, sr.Spread, sr.Enabled = 0.08, 0.85, true

	local cc = claim("ColorCorrectionEffect", "JungleCC", taken) :: ColorCorrectionEffect
	cc.Brightness, cc.Enabled = 0, true -- TintColor/Saturation/Contrast are hourly

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.SunAngularSize = 13
		-- the moon is DayNightServer's business (it hides the disc) — not touched here
	end

	-- Water. NOTE: WaterColor is set DARKER than the STYLEGUIDE §4 on-screen river colour (#247786)
	-- because terrain water renders brighter than the raw value, so this input renders as the
	-- intended muted jungle teal rather than neon.
	--
	-- ⚠️ Reflectance is the big one here: the game place shipped at **1**, i.e. a mirror-finish river.
	local T = Workspace.Terrain
	T.WaterColor = Color3.fromRGB(24, 78, 86)
	T.WaterTransparency = 0.30
	T.WaterReflectance = 0.03
	T.WaterWaveSize = 0.15
	T.WaterWaveSpeed = 10

	return refused
end

-- Applies the hour-dependent half. Called ~2×/s at runtime, so it does property writes only.
local function applyPalette(p: Palette)
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoorAmbient
	Lighting.ExposureCompensation = p.exposure
	Lighting.EnvironmentDiffuseScale = p.envDiffuse

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = p.atmDensity
		atm.Color = p.atmColor
		atm.Decay = p.atmDecay
		atm.Glare = p.atmGlare
		atm.Haze = p.atmHaze
	end

	local cc = Lighting:FindFirstChild("JungleCC")
	if cc and cc:IsA("ColorCorrectionEffect") then
		cc.TintColor = p.ccTint
		cc.Saturation = p.ccSaturation
		cc.Contrast = p.ccContrast
	end
end

AtmosphereRig.applyStatic = applyStatic
AtmosphereRig.applyPalette = applyPalette

-- ── drift check ─────────────────────────────────────────────────────────────────────────────
-- Ported from the lobby rig, and it earned its place: that place quietly accumulated two unauthored
-- post-effects that nobody noticed for jobs on end, and the GAME place turned out to have the same
-- two. Report drift loudly instead of letting it accumulate.
local KNOWN = {
	JungleCC = true,
	JungleBloom = true,
	JungleBloomHighlight = true,
	JungleSunRays = true,
	DepthOfField = true, -- present but Enabled = false, so it costs nothing
}

function AtmosphereRig.strays(): { string }
	local found: { string } = {}
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") and not KNOWN[c.Name] then
			table.insert(found, ("%s (%s, %s)"):format(c.Name, c.ClassName, if c.Enabled then "ENABLED" else "disabled"))
		end
	end
	return found
end

-- One-shot: bake the whole rig at a given hour. This is what the command bar / MCP calls to make the
-- EDIT-time view match, and what AtmosphereServer calls once at start-up before it begins tracking.
function AtmosphereRig.apply(hour: number?): string
	local h = hour or Lighting.ClockTime
	local refused = applyStatic()
	applyPalette(paletteAt(h))
	local strays = AtmosphereRig.strays()
	if #strays > 0 then
		warn("[AtmosphereRig] unauthored post-effect(s) in Lighting: " .. table.concat(strays, ", ")
			.. " — each enabled one is a full-screen pass. Adopt it into this module or delete it.")
	end
	local note = ("[AtmosphereRig] applied at %.2fh (%d stray post-effect(s))"):format(h, #strays)
	if #refused > 0 then
		note ..= " — REFUSED: " .. table.concat(refused, ", ")
	end
	return note
end

return AtmosphereRig
