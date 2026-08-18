--!strict
-- AssetPivots.luau — repair the AssetLibrary's broken model pivots, once, at boot.
--
-- ⚠️ THIS FIXES A BUG YOU CANNOT SEE IN CODE, ONLY IN WORLD SPACE.
--
-- Every placement in this game seats a library model with `PivotTo`, which moves the model's PIVOT to
-- the given CFrame — not its geometry. That is fine when the pivot sits inside the model. Measured in
-- `ServerStorage.AssetLibrary`, three of them do not:
--
--     RockA   pivot 74 studs from its own bounding-box centre
--     RockB   pivot 48 studs
--     RockC   pivot 107 studs
--
-- They are imported meshes whose `PrimaryPart` is a mesh part whose local origin sits far outside the
-- rock. So `PivotTo(here)` put the rock *there*, and `ScaleTo` — which scales about the pivot — scaled
-- the error along with it. Found by measuring a built camp: the campfire's six ring stones, meant to sit
-- 4.6 studs around the flame, were flung up to 41 studs across the camp (107 × the 0.4 dressing scale =
-- 42.8, which is the number that was actually on the ground).
--
-- Fixing it in the seven call sites that clone from the library would fix it seven times and miss the
-- eighth. Fixing the SOURCE fixes every consumer at once, including ones not written yet — so this
-- rewrites `WorldPivot` to the bounding-box centre on the library models themselves.
--
-- Runs in the module body, so the require cache makes it exactly-once per VM. Require it from any module
-- that reaches the library (`CampDefs`, `FoliageDefs`) and ordering takes care of itself.
--
-- ⚠️ Only pivots that are genuinely WRONG are touched (>1 stud out). Models whose pivot is already at
-- their centre — which is what the rest of the codebase assumes, since it re-seats props by measuring
-- the bounding box bottom — are left exactly as they are.

local ServerStorage = game:GetService("ServerStorage")

local AssetPivots = {}

local TOLERANCE = 1 -- studs; below this the pivot is fine and must not be disturbed

local function normalise(): number
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	if not lib then
		return 0 -- an unsaved place file; every consumer already warns about this
	end
	local fixed, worst, worstName = 0, 0, ""
	for _, m in ipairs(lib:GetDescendants()) do
		if m:IsA("Model") and #m:GetChildren() > 0 then
			local ok, box = pcall(function(): CFrame
				local cf = m:GetBoundingBox()
				return cf
			end)
			if ok and box then
				local off = (box.Position - m:GetPivot().Position).Magnitude
				if off > TOLERANCE then
					-- ⚠️ `WorldPivot` ALONE DOES NOTHING HERE, and that is the whole trap.
					--
					-- When a Model has a `PrimaryPart`, the engine defines the pivot AS that part's
					-- CFrame and IGNORES `WorldPivot` entirely. RockA/B/C each name an imported mesh
					-- part as PrimaryPart, and that part's local origin is exactly what sits 74/48/107
					-- studs out. Writing `WorldPivot` on them was a silent no-op — verified in a built
					-- camp, where the fire's stones were still 43 studs away afterwards.
					--
					-- So the PrimaryPart has to go first. That is safe for these: `ExcursionServer`
					-- already states that "library models have no dependable PrimaryPart", nothing reads
					-- it on a dressing prop, and every placement goes through `PivotTo`, which falls back
					-- to `WorldPivot` once PrimaryPart is nil.
					m.PrimaryPart = nil
					-- Keep the pivot's ROTATION and take only its position, so a model authored with a
					-- deliberate facing is not spun on the spot.
					m.WorldPivot = CFrame.new(box.Position) * (m:GetPivot() - m:GetPivot().Position)
					fixed += 1
					if off > worst then
						worst, worstName = off, m.Name
					end
				end
			end
		end
	end
	if fixed > 0 then
		print(("[AssetPivots] repaired %d model pivot(s); worst was %s at %.0f studs off-centre")
			:format(fixed, worstName, worst))
	end
	return fixed
end

AssetPivots.repaired = normalise()

return AssetPivots
