--!strict
-- WorldSign.luau — THE physical world-sign recipe (Job #120).
--
-- One recipe, one place to restyle. A WoodPlanks board on two wood posts, with a `SurfaceGui` on BOTH
-- faces so it reads from either side. This is not a new design: it is the recipe `ASSETS.md` §1.3
-- records as the game's built sign (`Board` 8×3×0.4 WoodPlanks on two `Post`s, the four lobby station
-- signs), and it is `buildShopSign` from `ExcursionServer` lifted out verbatim so the river piers can
-- use the same thing the trading posts use.
--
-- ⚠️ THREE PROPERTIES HERE ARE LOAD-BEARING, NOT STYLING. Each has an incident behind it.
--
--   1. **It is PHYSICAL, never a `BillboardGui`.** STYLEGUIDE §5 and Job #077 both rule billboards out
--      for world signage: an `AlwaysOnTop` billboard renders THROUGH terrain and through the very thing
--      it is attached to. Job #072 shipped that once already (world tags visible from the plane) and
--      Job #077 shipped it a second time at the shop.
--
--   2. **Every part is `CanCollide = false`.** At a camp that is merely tidy. At a river pier it is
--      safety-critical: `DockServer`'s header records the standing rule that physical collision with
--      the boat assembly blows the boat apart — which is why the whole pier below the waterline is
--      de-collided — and a sign on the pier's water edge is squarely in the hull's path at a sloppy
--      mooring. Do not "fix" these to true.
--
--   3. **`ground` is PASSED IN, never re-probed here.** `ExcursionServer:1976` records why: the sign
--      stands on the same levelled pad as the post 16 studs away, and an independent probe there read
--      22.0 on ground that measures 17.0, leaving the sign hanging 4.7 studs up. One measurement,
--      shared by everything on the pad. The caller owns that measurement — and at a pier it must be a
--      real raycast of the deck, not `DockServer.DECK_Y`, which is 0.92 studs above the plank surface
--      the model actually renders (measured live, Job #120).
--
-- Returns the BOARD (callers hang a `ProximityPrompt` on it — see Job #106 on why the trigger belongs
-- on the thing players walk up to) and the POSTS (so a caller can tie something to one; `DockServer`
-- moors the boat's rope round the foot of the nearer post).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local WorldSign = {}

-- Geometry, shared by every sign in the game. Changing a number here changes the trading posts too.
local BOARD_SIZE = Vector3.new(8, 3, 0.4)
local BOARD_HEIGHT = 6.2 -- board centre above `ground`
local POST_SIZE = Vector3.new(0.5, 7, 0.5)
local POST_HEIGHT = 3.5 -- post centre above `ground`, i.e. the post spans ground .. ground+7
local POST_SPREAD = 3.4 -- posts at ±this along the board's width

export type Options = {
	position: Vector3, -- where the sign stands (X/Z used; Y ignored in favour of `ground`)
	faceTo: Vector3, -- the sign turns to face this point
	parent: Instance,
	ground: number, -- the surface the posts stand on — MEASURED by the caller, never assumed
	text: string,
	boardName: string?, -- defaults to "SignBoard"
	-- Whether the sign stops raycasts. Defaults TRUE, which is what camp signs have always done.
	--
	-- ⚠️ Pass `false` for a sign standing anywhere players SHOOT PAST. `findings/0023` is this exact bug
	-- with foliage: "FoliageServer's leaf parts are CanQuery, so they stop hitscan the way a wall does".
	-- `GunServer` and `WeaponServer` both raycast with `FilterType = Exclude` over only
	-- `{ boat, character }`, so any CanQuery part between a player and their target eats the round. A
	-- board on a river pier sits square in the line from a moored boat to the bank — which is precisely
	-- where the shooting happens — so `DockServer` passes false. `Deck` next to it is `CanQuery = false`
	-- for the same reason.
	blockRaycasts: boolean?,
}

function WorldSign.build(o: Options): (Part, { Part })
	local pos, faceTo = o.position, o.faceTo
	local d = Vector3.new(faceTo.X - pos.X, 0, faceTo.Z - pos.Z)
	local yaw = if d.Magnitude > 0.01 then math.atan2(d.X, d.Z) else 0
	local base = CFrame.new(pos.X, o.ground, pos.Z) * CFrame.Angles(0, yaw, 0)

	local query = o.blockRaycasts ~= false
	local function block(name: string, size: Vector3, color: Color3, cf: CFrame, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false -- see note 2 in the header
		p.CanQuery = query
		p.Size = size
		p.Color = color
		p.Material = mat
		p.CFrame = cf
		p.Parent = o.parent
		return p
	end

	local posts: { Part } = {}
	for _, dx in ipairs({ -POST_SPREAD, POST_SPREAD }) do
		table.insert(
			posts,
			block("Post", POST_SIZE, Theme.color.woodDark, base * CFrame.new(dx, POST_HEIGHT, 0), Enum.Material.Wood)
		)
	end

	local board = block(
		o.boardName or "SignBoard",
		BOARD_SIZE,
		Theme.color.wood,
		base * CFrame.new(0, BOARD_HEIGHT, 0),
		Enum.Material.WoodPlanks
	)

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.MaxDistance = 320 -- occluded correctly by the world, unlike the billboard it replaces
		sg.Parent = board
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(0.9, 0.8)
		lbl.Position = UDim2.fromScale(0.05, 0.1)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Theme.color.cream -- never pure white (STYLEGUIDE §4)
		lbl.TextStrokeColor3 = Theme.color.stroke
		lbl.TextStrokeTransparency = 0.4
		lbl.Font = Theme.font.sign -- SpecialElite — physical world signs only
		lbl.TextScaled = true
		lbl.Text = o.text
		lbl.Parent = sg
	end

	return board, posts
end

-- The post foot, in world space — where a rope, a lantern or a notice would actually be tied.
-- `offsetUp` studs above the post's base.
function WorldSign.postFoot(post: Part, offsetUp: number): Vector3
	return post.Position - Vector3.new(0, post.Size.Y / 2, 0) + Vector3.new(0, offsetUp, 0)
end

-- Repaint a built sign. Both faces, in one call.
--
-- ⚠️ THIS EXISTS BECAUSE A SIGN THAT CARRIES A PROMPT CAN CONTRADICT IT. A `ProximityPrompt`'s
-- `ActionText` is state ("Tie Boat" → "Untie Boat"); a board painted at build time is not. Put the two
-- on the same object without this and the moment a player ties up, the board tells them to do the thing
-- they have just done. Any caller that flips its prompt's `ActionText` must flip its board with it.
function WorldSign.setText(board: Part, text: string)
	for _, sg in ipairs(board:GetChildren()) do
		if sg:IsA("SurfaceGui") then
			local lbl = sg:FindFirstChildOfClass("TextLabel")
			if lbl then
				lbl.Text = text
			end
		end
	end
end

return WorldSign
