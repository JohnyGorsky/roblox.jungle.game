--!strict
-- BoatTurretVisual.local.luau — poses the mounted gun barrel and the searchlight head ON THIS CLIENT,
-- from THIS CLIENT'S OWN view of the boat (Job #087).
--
-- 🔴 WHY THIS EXISTS — the measurement, so nobody moves it back to the server.
--
-- Both parts are `Anchored`, and the server used to write their CFrame every Heartbeat from ITS view
-- of the hull. But the hull is a server-owned physics body: every client renders an INTERPOLATED pose
-- that is not the server's. Two objects, two different routes to the screen, so the anchored parts
-- landed roughly one frame of travel behind the hull they are bolted to. Driving straight at 53
-- studs/s that measured:
--
--     GunBarrel        drift vs hull   avg 1.1427 / max 6.0795 studs
--     SearchlightHead  drift vs hull   avg 1.1538 / max 6.3765 studs
--     GunBase (welded) drift vs hull   avg 0.0000 / max 0.0002 studs   <- the control
--
-- At rest the same figure is 0.0022 studs, which is why it reads as "jiggles while riding, snaps back
-- when you stop" (todo 0047). The boat travels 0.93 studs per frame at that speed — so the drift IS,
-- almost exactly, one frame of lag.
--
-- 🔴 THE FIX IS THE FRAME OF REFERENCE, NOT SMOOTHING. Posing these parts from `GunBase` — which is
-- WELDED into the assembly and therefore replicates WITH the hull, measured at exactly 0.0000 — means
-- the barrel is derived from the same pose the client is drawing. There is no lag to smooth away,
-- because there is no longer a second source of truth.
--
-- ⚠️ A client CFrame write to a server-owned anchored part does NOT replicate. That is deliberate and
-- required: every client poses these two for itself, against the hull it is actually rendering. Nothing
-- here is authoritative — the server keeps the aim numbers and does the firing raycast from its own
-- `aimCFrame()`, which never reads these parts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BIND = "BoatTurretVisual"
local player = Players.LocalPlayer

local boat = Workspace:WaitForChild("Boat", 60)
if not boat then
	return
end
local hull = boat:WaitForChild("Hull", 30) :: BasePart?
local base = boat:WaitForChild("GunBase", 30) :: BasePart?
local barrel = boat:WaitForChild("GunBarrel", 30) :: BasePart?
if not (hull and base and barrel) then
	warn("[BoatTurretVisual] missing Hull/GunBase/GunBarrel — turret will not be posed")
	return
end

local seat = boat:FindFirstChild("GunSeat") :: Seat?

-- ── the local gunner's own aim ────────────────────────────────────────────────────────────────────
-- Whoever is MANNING the gun poses the barrel from their own input, not from the replicated attribute.
-- Their aim then has no round trip in it at all — the barrel follows the mouse exactly as fast as the
-- camera does. Everyone else reads what the server published, which is all they can know anyway.
--
-- `GunClient` already sends yaw/pitch to the server; it also mirrors them onto these attributes on the
-- LOCAL player so this script can read them without the two scripts having to know about each other.
local function localAim(): (number?, number?)
	if not seat or not player.Character then
		return nil, nil
	end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or seat.Occupant ~= hum then
		return nil, nil
	end
	local y = player:GetAttribute("GunAimYaw") :: number?
	local p = player:GetAttribute("GunAimPitch") :: number?
	return y, p
end

local function poseBarrel(yaw: number, pitch: number)
	-- Same expression the server used, but built from the CLIENT's `GunBase` — a welded part, so it is
	-- in perfect lockstep with the hull as rendered here.
	barrel.CFrame = base.CFrame * CFrame.Angles(pitch, yaw, 0) * CFrame.new(0, 0, -barrel.Size.Z / 2)
end

-- ── searchlight ───────────────────────────────────────────────────────────────────────────────────
-- Resolved lazily: the head only exists once the Searchlight module is installed, and its mount offset
-- is published by `BoatModules` so the geometry stays defined in one place.
local head: BasePart? = nil
local skin: BasePart? = nil

local function refreshSearchlight()
	local h = boat:FindFirstChild("SearchlightHead")
	head = (h and h:IsA("BasePart")) and h or nil
	if head then
		local s = head:FindFirstChild("Skin_searchlightHead")
		skin = (s and s:IsA("BasePart")) and s or nil
	else
		skin = nil
	end
end
refreshSearchlight()
boat.ChildAdded:Connect(refreshSearchlight)
boat.ChildRemoved:Connect(refreshSearchlight)

local function poseSearchlight(yaw: number)
	local h = head
	if not h or not h.Parent then
		return
	end
	local mount = boat:GetAttribute("SearchlightMount") :: CFrame?
	if not mount then
		return -- BoatModules has not published the geometry yet
	end
	-- YAW ONLY, deliberately — following the gunner's elevation would point the beam at the sky the
	-- moment they aimed at a bank. Same rule the server version had.
	local cf = hull.CFrame * mount * CFrame.Angles(0, yaw, 0)
	h.CFrame = cf
	local sk = skin
	if sk and sk.Parent then
		local off = boat:GetAttribute("SearchlightSkinOffset") :: CFrame?
		if off then
			sk.CFrame = cf * off
		end
	end
end

RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value - 1, function()
	if not (hull.Parent and base.Parent and barrel.Parent) then
		return
	end
	-- the local gunner's own input wins; everyone else uses the published aim
	local ly, lp = localAim()
	local yaw = ly or (boat:GetAttribute("GunYaw") :: number?) or 0
	local pitch = lp or (boat:GetAttribute("GunPitch") :: number?) or 0
	poseBarrel(yaw, pitch)
	poseSearchlight(yaw)
end)
