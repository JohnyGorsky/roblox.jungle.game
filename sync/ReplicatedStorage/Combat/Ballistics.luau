--!strict
-- Ballistics.luau — where a lobbed rocket lands, and the path it takes to get there (Job #118).
--
-- 🔴 THIS MODULE EXISTS SO THAT THREE THINGS CANNOT DISAGREE:
--   1. the RED RING the shooter sees on the ground before firing  (client, every frame)
--   2. the ARC the rocket is drawn flying                          (client, every frame, every player)
--   3. the POINT THE BLAST GOES OFF and what it damages            (server, authoritative)
-- If (1) and (3) drift the weapon lies to the player about where their 80 R$ rocket is going. If (2) and
-- (3) drift the explosion happens somewhere the rocket visibly is not. One copy of the maths, required by
-- both sides, is the only way that stays true — it cannot be kept in step by hand across three files.
--
-- ⚠️ NO `UserInputService`, NO `Workspace.CurrentCamera`, AND NOTHING CLIENT-ONLY IN HERE.
-- This is required by `ServerScriptService/Combat/Rocket.luau`, and `GetService` for a client-only
-- service THROWS on the server. Camera and pointer sampling stay in `WeaponClient`, which then hands the
-- resulting aim point in here.

local Workspace = game:GetService("Workspace")

local Ballistics = {}

-- ── the arc ───────────────────────────────────────────────────────────────────────────────────────
-- How high the rocket lobs above the straight line from muzzle to impact, at the top of its arc.
--
-- ⚠️ NOT REAL BALLISTICS, ON PURPOSE. A true 4-second projectile under Roblox gravity (196.2 studs/s²)
-- peaks at g·(t/2)²/2 = **392 studs** above the midpoint — several times the height of anything in the
-- game, straight off the top of the screen, and invisible for most of its flight. The requirement is
-- "flies in a curve, up and then down", which is a readability requirement, not a physics one. So the
-- path is authored: a parabola whose height is chosen to stay on camera.
local ARC_RATIO = 0.30 -- of the straight-line distance
local ARC_MIN = 10 -- a point-blank shot still visibly lobs rather than going flat
local ARC_MAX = 95 -- and a 300-stud shot does not leave the frame

function Ballistics.arcHeightFor(distance: number): number
	return math.clamp(distance * ARC_RATIO, ARC_MIN, ARC_MAX)
end

-- Where the rocket is at `alpha` ∈ [0, 1] of its flight.
--
-- The vertical term is `4·a·(1−a)`, which is exactly 0 at both ends and exactly 1 at a = 0.5. That is
-- what makes the rocket leave the muzzle and arrive AT the marked point with no fudge factor at either
-- end — the thing a hand-tuned offset would quietly get wrong.
function Ballistics.pointAt(origin: Vector3, impact: Vector3, arc: number, alpha: number): Vector3
	local a = math.clamp(alpha, 0, 1)
	return origin:Lerp(impact, a) + Vector3.new(0, arc * 4 * a * (1 - a), 0)
end

-- ── where the shot leaves the weapon ──────────────────────────────────────────────────────────────
-- 🔴 THE MUZZLE END IS FOUND, NOT ASSUMED — the note this was lifted from is in `WeaponClient`.
-- Of a held part's six face centres, the muzzle is the one furthest along the direction you are
-- shooting. That is correct for the +X Meshy guns AND for the -Z greybox box, and stays correct for any
-- weapon added later whatever axis it is modelled on. Hardcoding an axis broke the shotgun once already
-- (Job #104: `Size.Z` was the gun's 0.29-stud THICKNESS, so the flash came out of the character's fist).
--
-- ⚠️ IT LIVES HERE, SHARED, BECAUSE THE SERVER NOW NEEDS IT TOO (Job #118). The client draws the muzzle
-- flash from this point and the server LAUNCHES THE ROCKET from it; two copies of the same geometry
-- would let the rocket appear somewhere the flash is not. `WeaponAssets` cannot help — it is
-- ServerStorage, unreachable from the client — which is exactly why this is computed rather than stored.
function Ballistics.muzzleWorld(held: BasePart, aimDir: Vector3): Vector3
	local cf = held.CFrame
	local half = held.Size / 2
	local bestOffset, bestReach = Vector3.zero, -math.huge

	-- Written out rather than looped over `{{axis, extent}, ...}`: a mixed Vector3/number array is not
	-- expressible under `--!strict` without casts on every read, and six explicit candidates are easier
	-- to check by eye than the casts would be.
	local function consider(offset: Vector3)
		local reach = offset:Dot(aimDir)
		if reach > bestReach then
			bestReach, bestOffset = reach, offset
		end
	end
	consider(cf.RightVector * half.X)
	consider(cf.RightVector * -half.X)
	consider(cf.UpVector * half.Y)
	consider(cf.UpVector * -half.Y)
	consider(cf.LookVector * half.Z)
	consider(cf.LookVector * -half.Z)

	return (cf + bestOffset).Position
end

-- ── where it lands ────────────────────────────────────────────────────────────────────────────────
-- Shared by the client's preview ring and the server's authoritative launch. Same inputs → same answer.
--
-- The contract the red ring promises the player is simple and absolute: **the rocket lands here.** So
-- this resolves a single point and the flight is drawn straight to it. Nothing mid-arc can intercept it;
-- a rocket that clipped a branch at the top of its lob and detonated early would make the marker a lie.
local DROP_UP = 200 -- start the ground probe this far above the clamped point…
local DROP_DOWN = 1200 -- …and look this far down for something to land on

-- Everything the impact ray must NOT stop on.
--
-- 🔴 `Workspace.Foliage` IS EXCLUDED, AND THAT IS A FIX, NOT A SHORTCUT (findings/0023).
-- FoliageServer's leaf parts are `CanQuery`, so a fern stops a ray exactly like a wall does — and with
-- Instance Streaming the CLIENT frequently has not loaded those ferns while the server has. That is
-- precisely how a preview ring and a real impact point end up tens of studs apart, with the player
-- convinced the weapon is broken. Excluding one named folder removes the divergence at its root.
-- It is also, independently, just correct: a rocket punches through a leaf. A bullet does not, which is
-- why the hitscan guns are left alone.
local function impactParams(ignore: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if ignore then
		for _, inst in ipairs(ignore) do
			if inst then
				table.insert(filter, inst)
			end
		end
	end
	local foliage = Workspace:FindFirstChild("Foliage")
	if foliage then
		table.insert(filter, foliage)
	end
	params.FilterDescendantsInstances = filter
	-- ⚠️ WATER IS *NOT* IGNORED HERE, unlike every other ray in the game.
	-- `WeaponClient`/`WeaponServer` set `IgnoreWater = true` because a bullet should not stop at the
	-- surface. A rocket should: it throws a plume off the river rather than continuing to the riverbed.
	-- And without this, aiming at a crocodile out in the channel returns NOTHING over deep water, the
	-- aim point becomes a spot 1000 studs away in the sky, and the "ground" ring floats above the river.
	params.IgnoreWater = false
	return params
end

-- `aimPoint` is wherever the shooter's own aim ray ended up — possibly 1000 studs away in mid-air.
-- Returns the point the rocket will detonate on.
function Ballistics.resolveImpact(origin: Vector3, aimPoint: Vector3, range: number, ignore: { Instance }?): Vector3
	local delta = aimPoint - origin
	if delta.Magnitude < 0.1 then
		return origin
	end
	local dir = delta.Unit
	local params = impactParams(ignore)

	-- 1. Something solid within reach? That is the impact — a wall, a hillside, a hut, the water.
	local hit = Workspace:Raycast(origin, dir * range, params)
	if hit then
		return hit.Position
	end

	-- 2. Nothing within reach: the shot is clamped to `range` along the aim. That point is usually in the
	--    air (aimed at the sky, or simply past 300 studs), so drop it onto whatever is underneath — the
	--    ring has to sit on the GROUND, and a rocket has to land on something.
	local far = origin + dir * range
	local down = Workspace:Raycast(far + Vector3.new(0, DROP_UP, 0), Vector3.new(0, -(DROP_UP + DROP_DOWN), 0), params)
	if down then
		return down.Position
	end

	-- 3. Nothing below either (out over the void past the map edge). An air burst at the range limit is
	--    the honest answer: the ring is drawn where it really will go off rather than being hidden.
	return far
end

-- ── the blast falloff ─────────────────────────────────────────────────────────────────────────────
-- Full damage across the inner `inner` fraction of the radius, then linear down to `minFactor` at the
-- rim. Returns 0 outside. Shared so the tuning numbers in `ItemDefs` mean one thing.
function Ballistics.blastFactor(distance: number, radius: number, inner: number, minFactor: number): number
	if radius <= 0 or distance > radius then
		return 0
	end
	local t = distance / radius
	if t <= inner then
		return 1
	end
	-- guard the degenerate `inner = 1` case rather than dividing by zero
	local span = 1 - inner
	if span <= 1e-6 then
		return 1
	end
	return 1 - (1 - minFactor) * ((t - inner) / span)
end

return Ballistics
