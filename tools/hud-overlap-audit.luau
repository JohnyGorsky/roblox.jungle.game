--!nonstrict
-- hud-overlap-audit.luau — HUD overlap + tap-target regression check (Job #094).
--
-- Run in the GAME place via the Studio Command Bar or the MCP `execute_luau` tool (datamodel: Client,
-- while in Play). Prints a TABLE, not a judgement: every pair of painted rectangles from two different
-- HUDs that intersect, plus every tap target below the thumb floor.
--
-- ── Why it measures PAINTED LEAVES, not frames ────────────────────────────────────────────────────
-- Several HUDs are a transparent holder that is much larger than what it draws — `CurrencyHud`'s row is
-- 0.34 of the screen wide but its chips hug the right edge and size to their own text. Intersecting
-- holder frames reports a collision there that no player can see, and (worse) that false positive would
-- have masked the real one: the chips genuinely DO collide with `RiverProgress` once a narrow viewport
-- makes its MinSize clamp kick in. So: only elements that actually paint count, and only across
-- different source HUDs — a label inside its own card is not an overlap.
--
-- ── Two modes ─────────────────────────────────────────────────────────────────────────────────────
--   LIVE      — measures the real PlayerGui at the real viewport. Truthful, but one resolution, and it
--               can only see the states the session is actually in.
--   SIMULATED — clones each HUD's content into a fixed-size Frame and lets the engine lay it out, so
--               any viewport can be swept without the Device Emulator. Offset-based sizes and the
--               UISizeConstraint clamps (which are in PIXELS and are the actual cause of the narrow-
--               screen collisions) behave exactly as they would on a real device.
--
-- SIMULATED caveat, stated rather than buried: it does not model per-device ScreenInsets (notch/topbar),
-- so it is a layout check, not a safe-area check. Safe area still needs a real device or the emulator.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TAP_FLOOR = 58 -- px; the floor RunComponents.touchButton already sets for thumb targets

-- Viewports swept in SIMULATED mode. Portrait is deliberately absent: Job #094 locked the game to
-- landscape, which is what makes leaving it out legitimate rather than convenient.
local VIEWPORTS = {
	{ name = "phone-small-landscape", w = 1136, h = 640 },
	{ name = "phone-landscape", w = 1334, h = 750 },
	{ name = "phone-tall-landscape", w = 1920, h = 880 },
	{ name = "tablet-landscape", w = 1620, h = 1080 },
	{ name = "desktop", w = 1920, h = 1080 },
}

-- HUDs to audit. Anything not listed (loading screens, full-bleed fades, the freecam chrome) is either
-- deliberately full-screen or not part of the in-run HUD, and would only generate noise.
local AUDIT = {
	"BoatHud", "HealthHud", "CurrencyHud", "RiverProgress", "InventoryHud", "ObjectiveHud",
	"CrewToast", "RoleChip", "BoatStatusCard", "UntieButton", "StagingHint", "BoatTouchControls",
	"AdminLauncher", "DownedHud", "RunGui",
}

-- ── states ───────────────────────────────────────────────────────────────────────────────────────
-- Which HUDs are actually on screen together, per game state. This table is the difference between a
-- useful report and a misleading one: the first run of this audit forced every HUD visible at once and
-- duly reported BoatTouchControls ↔ InventoryHud, which cannot happen — the hotbar hides itself in a
-- control seat precisely so the steer buttons can have that corner. A detector that doesn't model
-- gating invents collisions, and invented collisions get "fixed", which moves real UI for no reason.
--
-- `hide` lists element names within a HUD that are NOT on screen in that state.
local STATES = {
	{
		name = "driving (touch)",
		show = { "BoatTouchControls", "HealthHud", "BoatHud", "CurrencyHud", "RiverProgress",
			"ObjectiveHud", "CrewToast", "RoleChip" },
		hide = { Hotbar = true, HandsFull = true }, -- InventoryHud hides both in a control seat
	},
	{
		name = "aboard, not driving (touch)",
		show = { "HealthHud", "BoatHud", "CurrencyHud", "RiverProgress", "InventoryHud",
			"ObjectiveHud", "CrewToast", "RoleChip" },
		hide = {},
	},
	{
		name = "moored / pre-launch (touch)",
		show = { "HealthHud", "BoatHud", "CurrencyHud", "InventoryHud", "UntieButton", "RoleChip" },
		hide = {},
	},
}

-- ── painted-ness ─────────────────────────────────────────────────────────────────────────────────

local function paints(o: Instance): boolean
	if not o:IsA("GuiObject") or not o.Visible then
		return false
	end
	if o.BackgroundTransparency < 0.99 then
		return true
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		return o.Text ~= "" and o.TextTransparency < 0.99
	end
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then
		return o.Image ~= "" and o.ImageTransparency < 0.99
	end
	return false
end

local function visibleChain(o: Instance, stopAt: Instance): boolean
	local cur = o
	while cur and cur ~= stopAt do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return true
end

local function collect(root: Instance, hudName: string, origin: Vector2, acc: { any })
	for _, d in ipairs(root:GetDescendants()) do
		if paints(d) and visibleChain(d, root) then
			local p, s = d.AbsolutePosition - origin, d.AbsoluteSize
			if s.X > 0 and s.Y > 0 then
				table.insert(acc, {
					hud = hudName,
					path = d.Name,
					x1 = p.X, y1 = p.Y, x2 = p.X + s.X, y2 = p.Y + s.Y,
					w = s.X, h = s.Y,
					tappable = d:IsA("GuiButton"),
				})
			end
		end
	end
end

local function intersect(a, b)
	local x1, y1 = math.max(a.x1, b.x1), math.max(a.y1, b.y1)
	local x2, y2 = math.min(a.x2, b.x2), math.min(a.y2, b.y2)
	if x2 > x1 and y2 > y1 then
		return (x2 - x1) * (y2 - y1), x1, y1, x2 - x1, y2 - y1
	end
	return nil
end

-- ── report ───────────────────────────────────────────────────────────────────────────────────────

local function report(rects, label, vw, vh, out)
	table.insert(out, ("── %s  (%d x %d) ─────────────────────────────"):format(label, vw, vh))

	-- overlaps, worst first, deduplicated to one line per HUD-pair
	local worst = {}
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			if a.hud ~= b.hud then
				local area, ox, oy, ow, oh = intersect(a, b)
				if area then
					local key = (a.hud < b.hud) and (a.hud .. " ↔ " .. b.hud) or (b.hud .. " ↔ " .. a.hud)
					local cur = worst[key]
					if not cur or area > cur.area then
						worst[key] = { area = area, a = a, b = b, ox = ox, oy = oy, ow = ow, oh = oh }
					end
				end
			end
		end
	end

	local list = {}
	for key, v in pairs(worst) do
		table.insert(list, { key = key, v = v })
	end
	table.sort(list, function(p, q) return p.v.area > q.v.area end)

	if #list == 0 then
		table.insert(out, "   OVERLAPS: none")
	else
		table.insert(out, ("   OVERLAPS: %d HUD pair(s)"):format(#list))
		for _, e in ipairs(list) do
			table.insert(out, ("     %-40s  %dx%d px at (%d,%d)   [%s / %s]"):format(
				e.key, e.v.ow, e.v.oh, e.v.ox, e.v.oy, e.v.a.path, e.v.b.path))
		end
	end

	-- undersized tap targets
	local small = {}
	for _, r in ipairs(rects) do
		if r.tappable and (r.w < TAP_FLOOR or r.h < TAP_FLOOR) then
			table.insert(small, ("     %-28s %dx%d px  (floor %d)"):format(r.hud .. "/" .. r.path, r.w, r.h, TAP_FLOOR))
		end
	end
	if #small == 0 then
		table.insert(out, "   TAP TARGETS: all at or above the floor")
	else
		table.insert(out, ("   TAP TARGETS below floor: %d"):format(#small))
		for _, s in ipairs(small) do
			table.insert(out, s)
		end
	end
	table.insert(out, "")
end

-- ── modes ────────────────────────────────────────────────────────────────────────────────────────

local M = {}

function M.live()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cam = workspace.CurrentCamera
	local rects = {}
	for _, name in ipairs(AUDIT) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			collect(g, name, Vector2.zero, rects)
		end
	end
	local out = { ("LIVE  ·  TouchEnabled=%s"):format(tostring(UserInputService.TouchEnabled)) }
	report(rects, "LIVE", cam.ViewportSize.X, cam.ViewportSize.Y, out)
	return table.concat(out, "\n")
end

-- Clones each audited HUD's content into a fixed-size stage so the engine resolves scale, aspect and
-- the pixel size-constraints against a chosen viewport. `force` optionally makes a HUD's content
-- visible so a state that isn't currently on screen can still be measured.
function M.simulate(force: { [string]: boolean }?)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("__HudAuditStage")
	if old then old:Destroy() end

	local host = Instance.new("ScreenGui")
	host.Name = "__HudAuditStage"
	host.Enabled = false -- measured, never shown: layout still resolves while hidden
	host.ResetOnSpawn = false
	host.ScreenInsets = Enum.ScreenInsets.None
	host.Parent = pg

	local out = {}
	for _, vp in ipairs(VIEWPORTS) do
		local stage = Instance.new("Frame")
		stage.Name = vp.name
		stage.Size = UDim2.fromOffset(vp.w, vp.h)
		stage.Position = UDim2.fromOffset(0, 0)
		stage.BackgroundTransparency = 1
		stage.Parent = host

		local sources = {}
		for _, name in ipairs(AUDIT) do
			local g = pg:FindFirstChild(name)
			if g and g:IsA("ScreenGui") then
				local box = Instance.new("Frame")
				box.Name = name
				box.Size = UDim2.fromScale(1, 1)
				box.BackgroundTransparency = 1
				box.Parent = stage
				for _, child in ipairs(g:GetChildren()) do
					if child:IsA("GuiObject") then
						local c = child:Clone()
						if force and force[name] then
							c.Visible = true
						end
						c.Parent = box
					end
				end
				table.insert(sources, { name = name, box = box })
			end
		end

		task.wait() -- one frame for the layout pass

		local rects = {}
		for _, s in ipairs(sources) do
			collect(s.box, s.name, stage.AbsolutePosition, rects)
		end
		report(rects, "SIMULATED " .. vp.name, vp.w, vp.h, out)
		stage:Destroy()
	end

	host:Destroy()
	return table.concat(out, "\n")
end

return M
