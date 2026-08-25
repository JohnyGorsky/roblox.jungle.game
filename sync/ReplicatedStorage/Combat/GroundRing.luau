--!strict
-- GroundRing.luau — the red circle on the ground that says "a rocket is landing here" (Job #118).
--
-- Two callers, and they must look like the same object because they ARE the same promise:
--   · `WeaponClient`  — your private aim preview, following your aim while you hold the Bazooka.
--   · `RocketFx`      — the public warning marker, locked at the impact point for the 4 s of flight and
--                       visible to the whole crew.
-- A player watches their preview ring turn into the marker ring the instant they fire, so one builder.
--
-- ⚠️ CLIENT USE ONLY. It lives in ReplicatedStorage next to `Ballistics` because that is where this
-- weapon's shared pieces live, but nothing on the server requires it and nothing here would work there:
-- these are local, unreplicated parts.
--
-- ── 🔴 EVERY PART BUILT HERE IS `CanQuery = false`, AND THAT IS NOT TIDINESS ───────────────────────
-- A queryable part parked on the ground breaks four unrelated systems in this game, none of which would
-- be suspected from the symptom:
--   1. `WeaponServer`'s hitscan filters only the shooter's character and the boat — so a marker would
--      **stop other players' bullets**, and their guns would appear to randomly stop working.
--   2. `BoatCamera` excludes only the boat and your own character — a marker between camera and boat
--      **yanks the camera in**.
--   3. `WeaponClient`'s own aim ray excludes only the character, so the preview ring would be hit by
--      **its own previous frame** and creep steadily toward the camera.
--   4. `HudState`'s 8-stud downward "am I aboard?" ray would read a marker under your feet as ground and
--      flip the HUD to *ashore* while you stand on deck.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GroundRing = {}

-- The disc floats this far above whatever it was placed on. Enough to beat z-fighting with terrain,
-- small enough that it still reads as lying ON the ground rather than hovering.
local LIFT = 0.15
local THICKNESS = 0.08
-- Fraction of the outer radius that is hollow. 0.92 leaves a rim about a twelfth of the radius wide —
-- ~2.5 studs on a 30-stud blast, which still reads at 300 studs.
local INNER_RATIO = 0.92

-- 🔴 THE FILL IS ALMOST INVISIBLE, AND THAT IS A CORRECTION MADE FROM A SCREENSHOT, NOT A PREFERENCE.
-- First build: `Neon` at 0.82. Captured in Play it was unusable — the blast radius is 30 studs, so the
-- disc is SIXTY studs across against a five-stud character, and the moment you aim at ground near your
-- own feet you are standing inside it. Neon ignores lighting, so 0.82 transparency across that much
-- screen read as "the ground is now red", not as a marker: the jungle, the river and the boat all went
-- red and the rim was off-screen entirely.
--
-- So the RIM carries the information and the fill is only a hint that the interior belongs to it.
-- `SmoothPlastic` rather than `Neon` for the same reason — a glowing floor is not a decal.
local FILL_TRANSPARENCY = 0.93

export type Ring = {
	setVisible: (boolean) -> (),
	setAt: (Vector3) -> (),
	setRadius: (number) -> (),
	setColor: (Color3) -> (),
	pulse: (number) -> (),
	destroy: () -> (),
}

function GroundRing.new(radius: number, color: Color3): Ring
	local r = math.max(1, radius)

	-- The FILL: a flat translucent disc. A `Cylinder` part's axis runs along its own X, so the CFrame
	-- below stands it up the other way to lie flat. This is the half that is guaranteed to render
	-- everywhere; the rim adornment on top of it is the half that makes it read as a ring.
	local disc = Instance.new("Part")
	disc.Name = "ImpactRing"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(THICKNESS, r * 2, r * 2)
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false -- 🔴 see the header
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.SmoothPlastic
	disc.Color = color
	disc.Transparency = FILL_TRANSPARENCY
	disc.Parent = Workspace

	-- The RIM. A `CylinderHandleAdornment` has a real `InnerRadius`, so it draws a true annulus with no
	-- texture asset, no second overlapping disc, and nothing to z-fight against.
	local rim = Instance.new("CylinderHandleAdornment")
	rim.Name = "Rim"
	rim.Adornee = disc
	rim.Radius = r
	rim.InnerRadius = r * INNER_RATIO
	rim.Height = THICKNESS * 2
	rim.Color3 = color
	rim.Transparency = 0.05 -- the rim is the marker; it should be unmistakable
	rim.AlwaysOnTop = false -- occluded by terrain like a real decal; a marker seen through a hill lies
	rim.ZIndex = 0
	-- The adornment extrudes along the adornee's LOCAL Z. The disc's own local X is its cylinder axis
	-- (already vertical in world space), so a quarter turn about Y lines the adornment up with it.
	rim.CFrame = CFrame.Angles(0, math.rad(90), 0)
	rim.Parent = disc

	local self = {}
	local alive = true
	local baseTransparency = FILL_TRANSPARENCY

	function self.setVisible(on: boolean)
		if not alive then
			return
		end
		disc.Transparency = if on then baseTransparency else 1
		rim.Visible = on
	end

	function self.setAt(pos: Vector3)
		if not alive then
			return
		end
		-- Laid flat: the cylinder's axis (local X) is rotated onto world +Y.
		disc.CFrame = CFrame.new(pos + Vector3.new(0, LIFT, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end

	function self.setRadius(n: number)
		if not alive then
			return
		end
		local nr = math.max(1, n)
		disc.Size = Vector3.new(THICKNESS, nr * 2, nr * 2)
		rim.Radius = nr
		rim.InnerRadius = nr * INNER_RATIO
	end

	function self.setColor(c: Color3)
		if not alive then
			return
		end
		disc.Color = c
		rim.Color3 = c
	end

	-- One breath in and out, for the warning marker while a rocket is in the air. Tween rather than a
	-- per-frame loop so it costs nothing and cannot outlive the part (`Destroy` cancels it).
	function self.pulse(period: number)
		if not alive then
			return
		end
		local info = TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(disc, info, { Transparency = math.max(0, baseTransparency - 0.06) }):Play()
		TweenService:Create(rim, info, { Transparency = 0.5 }):Play()
	end

	function self.destroy()
		alive = false
		disc:Destroy()
	end

	return self :: any
end

return GroundRing
