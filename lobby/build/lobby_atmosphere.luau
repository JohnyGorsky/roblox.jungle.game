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

-- Bloom: gentle highlight glow only (not heavy — mobile)
local bl = L:FindFirstChild("JungleBloom") or Instance.new("BloomEffect")
bl.Name = "JungleBloom"
bl.Intensity = 0.5; bl.Size = 24; bl.Threshold = 1.4
bl.Parent = L

-- SunRays: soft god-rays
local sr = L:FindFirstChild("JungleSunRays") or Instance.new("SunRaysEffect")
sr.Name = "JungleSunRays"
sr.Intensity = 0.08; sr.Spread = 0.85
sr.Parent = L

-- Water: jungle river turquoise (STYLEGUIDE §4), slightly murky + moving
local T = workspace.Terrain
T.WaterColor = Color3.fromRGB(36,119,134)
T.WaterTransparency = 0.60
T.WaterReflectance = 0.08
T.WaterWaveSize = 0.12
T.WaterWaveSpeed = 12

return "lobby atmosphere applied"
