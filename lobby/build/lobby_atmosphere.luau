--!nocheck
-- ============================================================================
-- Last River — LOBBY atmosphere / lighting rig                     [Job #064]
-- ============================================================================
-- Warm late-afternoon TROPICAL JUNGLE mood (STYLEGUIDE §8, applies jungle-style
-- palette). Re-runnable: finds-or-creates the post-effects. Verify by screenshot.
--
-- NOTE: set `Lighting.Technology = Enum.Technology.Future` in Studio's rendering
-- settings — it CANNOT be set by script (deprecated as settable).
-- ============================================================================

local L = game:GetService("Lighting")

-- Base lighting: warm afternoon sun, cool-green jungle shade
L.ClockTime = 16.1
L.GeographicLatitude = 25
L.Brightness = 2.7
L.ExposureCompensation = 0.12
L.OutdoorAmbient = Color3.fromRGB(104,106,80)   -- mossy jungle shade
L.Ambient = Color3.fromRGB(74,72,56)
L.EnvironmentDiffuseScale = 0.5
L.EnvironmentSpecularScale = 0.5
L.GlobalShadows = true

-- Atmosphere: warm humid jungle haze (fades far mountains -> depth, no hard edge)
local atm = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.40
atm.Offset = 0.20
atm.Color = Color3.fromRGB(196,186,150)   -- warm humid air
atm.Decay = Color3.fromRGB(158,120,72)     -- warm afternoon horizon
atm.Glare = 0.32
atm.Haze = 2.7
atm.Parent = L

-- ColorCorrection: subtle warm tint + lush saturation
local cc = L:FindFirstChild("JungleCC") or Instance.new("ColorCorrectionEffect")
cc.Name = "JungleCC"
cc.TintColor = Color3.fromRGB(255,240,212)
cc.Saturation = 0.13
cc.Contrast = 0.07
cc.Brightness = 0
cc.Parent = L

-- Bloom — TWO LAYERS, both deliberate (Job #069):
--   · JungleBloom          low threshold, gentle  -> the soft overall glow
--   · JungleBloomHighlight high threshold, strong -> punch on the BRIGHTEST things only
--                                                    (pad neon, water sparkle, sun)
-- The highlight layer existed in the place as an unnamed stray `BloomEffect` and was doing
-- most of the visible glow. Job #069 ADOPTED it into the rig (and renamed it) rather than
-- deleting it, which would have quietly dimmed the lobby. Two blooms is a real cost — keep
-- it at two; a third should be merged, not added.
local bl = L:FindFirstChild("JungleBloom") or Instance.new("BloomEffect")
bl.Name = "JungleBloom"
bl.Intensity = 0.5; bl.Size = 24; bl.Threshold = 1.4
bl.Parent = L

local blh = L:FindFirstChild("JungleBloomHighlight") or Instance.new("BloomEffect")
blh.Name = "JungleBloomHighlight"
blh.Intensity = 1; blh.Size = 24; blh.Threshold = 2
blh.Parent = L

-- SunRays: soft god-rays. EXACTLY ONE. A second stray SunRaysEffect (Intensity 0.01 — i.e.
-- invisible) was costing a full-screen pass for nothing; deleted in Job #069.
local sr = L:FindFirstChild("JungleSunRays") or Instance.new("SunRaysEffect")
sr.Name = "JungleSunRays"
sr.Intensity = 0.08; sr.Spread = 0.85
sr.Parent = L

-- Water: muted jungle-river teal. NOTE: WaterColor is set darker than the §4
-- on-screen river color (#247786) because terrain water renders brighter than
-- the raw value (esp. under Voxel tech) -> this input renders as the intended teal.
local T = workspace.Terrain
T.WaterColor = Color3.fromRGB(24,78,86)
T.WaterTransparency = 0.30
T.WaterReflectance = 0.03
T.WaterWaveSize = 0.15
T.WaterWaveSpeed = 10

-- ── DRIFT CHECK (Job #069) ──────────────────────────────────────────────────
-- This script find-or-creates BY NAME, so anything added to Lighting by hand survives every
-- re-run untouched. That is exactly how the place ended up with two unauthored post-effects
-- (a second Bloom and an invisible SunRays at Intensity 0.01) that nobody noticed for jobs on
-- end. Every enabled PostEffect is a full-screen pass and costs real frames on mobile, so
-- report drift loudly instead of letting it accumulate silently.
local KNOWN = {
	JungleCC = true,
	JungleBloom = true,
	JungleBloomHighlight = true,
	JungleSunRays = true,
	DepthOfField = true, -- present but Enabled = false, so it costs nothing
}
local strays = {}
for _, c in ipairs(L:GetChildren()) do
	if c:IsA("PostEffect") and not KNOWN[c.Name] then
		table.insert(strays, ("%s (%s, %s)"):format(c.Name, c.ClassName, c.Enabled and "ENABLED" or "disabled"))
	end
end
if #strays > 0 then
	warn("[lobby_atmosphere] unauthored post-effect(s) in Lighting: " .. table.concat(strays, ", ")
		.. " — each enabled one is a full-screen pass. Adopt it into this script or delete it.")
end

-- NOTE on Lighting.Technology (Job #069): current Studio no longer exposes a `Technology`
-- dropdown — the property is gone from the Lighting panel and unreadable from a script
-- context ("lacking capability RobloxScript"). The modern controls are `LightingStyle`
-- (Realistic here) + `ShadowSoftness` (0.2) + `PrioritizeLightingQuality` (true), which are
-- the Future-lighting path. Nothing to set; the old "set Technology = Future by hand"
-- instruction is obsolete.

return ("lobby atmosphere applied (%d unauthored post-effect(s) found)"):format(#strays)
