--!nocheck
-- ============================================================================
-- Last River — LOBBY greybox (editor-placed layout)               [Job #064]
-- ============================================================================
-- The lobby is HAND-PLACED in the editor (memory: lobby-editor-placed-not-scripted).
-- This script builds the greybox stand-ins; the human refines art; SCRIPTS then
-- FIND these by name + attach actions (they do NOT generate lobby geometry).
--
-- Every interactive STATION is a Model named exactly for script lookup, with:
--   * attribute  Station = "<type>"   (RobuxShop / BoatUpgrades / SkillTrainer /
--     Bounties / PartyPad / Spawn)
--   * a child Part named "Anchor"     (where a ProximityPrompt attaches)
-- Non-interactive stuff lives under Displays/ and Scenery/.
-- Station set = the game's existing code set (not the MapIdea names).
-- +X = East/water, -Z = North/runway, +Z = South/entry.
-- ============================================================================

local ws = workspace
for _,n in ipairs({"LOBBY_BLOCKOUT","LOBBY_GREYBOX"}) do local f=ws:FindFirstChild(n); if f then f:Destroy() end end
local root = Instance.new("Folder"); root.Name="LOBBY_GREYBOX"; root.Parent=ws
local Stations = Instance.new("Folder"); Stations.Name="Stations"; Stations.Parent=root
local Displays = Instance.new("Folder"); Displays.Name="Displays"; Displays.Parent=root
local Scenery  = Instance.new("Folder"); Scenery.Name="Scenery"; Scenery.Parent=root

-- palette
local WOOD=Color3.fromRGB(114,80,45); local PLANK=Color3.fromRGB(128,97,66); local DWOOD=Color3.fromRGB(76,55,37)
local OLIVE=Color3.fromRGB(89,97,59); local DOLIVE=Color3.fromRGB(63,73,48); local METAL=Color3.fromRGB(78,82,70)
local DMETAL=Color3.fromRGB(53,58,53); local SAND=Color3.fromRGB(200,163,106); local CREAM=Color3.fromRGB(243,230,194)
local GOLD=Color3.fromRGB(214,155,34); local BLUE=Color3.fromRGB(53,107,154); local GREEN=Color3.fromRGB(75,122,43)
local RED=Color3.fromRGB(168,75,60); local YELLOW=Color3.fromRGB(213,161,43); local CANVAS=Color3.fromRGB(115,119,80)
local RUST=Color3.fromRGB(150,90,50)
local Mat=Enum.Material; local DISC=CFrame.Angles(0,0,math.rad(90))

local function P(parent,name,size,pos,color,mat,cf,shape)
	local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.Size=size
	p.CFrame=CFrame.new(pos)*(cf or CFrame.new()); p.Color=color; p.Material=mat or Enum.Material.SmoothPlastic
	if shape then p.Shape=shape end
	p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent; return p end
local function lbl(part,text,col)
	local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,160,0,26); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true; bb.Parent=part
	local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,1,0); t.BorderSizePixel=0; t.BackgroundColor3=col or Color3.fromRGB(36,53,45); t.BackgroundTransparency=0.25
	t.TextColor3=CREAM; t.TextScaled=true; t.Font=Enum.Font.BuilderSansBold; t.Text=text; t.Parent=bb
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=t end
-- station model with Station attribute + Anchor part
local function station(name,stype,anchorPos)
	local m=Instance.new("Model"); m.Name=name; m:SetAttribute("Station",stype); m.Parent=Stations
	local a=P(m,"Anchor",Vector3.new(1,1,1),anchorPos,CREAM); a.Transparency=1; a.CanCollide=false
	m.PrimaryPart=a
	return m end

-- ---- SPAWN ----
do
	local m=station("Spawn","Spawn",Vector3.new(0,3,-35))
	P(m,"Pad",Vector3.new(2,26,26),Vector3.new(0,0.6,-35),SAND,Mat.Sand,DISC,Enum.PartType.Cylinder)
	P(m,"Star",Vector3.new(2.2,11,11),Vector3.new(0,0.7,-35),CREAM,Mat.SmoothPlastic,DISC,Enum.PartType.Cylinder)
	lbl(m.Anchor,"SPAWN",GREEN)
	local sp=Instance.new("SpawnLocation"); sp.Name="LobbySpawn"; sp.Anchored=true; sp.Neutral=true
	sp.Size=Vector3.new(10,1,10); sp.Position=Vector3.new(0,0.6,-35); sp.Transparency=1; sp.CanCollide=false; sp.Parent=m
end

-- ---- PLANE + PILOT (landmark, nose -> +Z) ----
do
	local m=Instance.new("Model"); m.Name="Plane"; m.Parent=Scenery
	local fus=P(m,"Fuselage",Vector3.new(8,8,50),Vector3.new(0,8,0),OLIVE,Mat.Metal)
	P(m,"Cockpit",Vector3.new(6,3,8),Vector3.new(0,11.5,17),DMETAL,Mat.Glass)
	P(m,"Nose",Vector3.new(6,6,6),Vector3.new(0,8,26),DOLIVE,Mat.Metal)
	P(m,"Wings",Vector3.new(62,1.8,12),Vector3.new(0,8,2),DOLIVE,Mat.Metal)
	P(m,"TailFin",Vector3.new(1.5,9,8),Vector3.new(0,13.5,-22),OLIVE,Mat.Metal)
	P(m,"TailWing",Vector3.new(24,1.5,7),Vector3.new(0,10,-22),DOLIVE,Mat.Metal)
	for _,sx in ipairs({-17,17}) do
		P(m,"Engine",Vector3.new(4.5,4.5,10),Vector3.new(sx,8,5),DMETAL,Mat.Metal)
		P(m,"Prop",Vector3.new(1,13,13),Vector3.new(sx,8,11),DMETAL,Mat.Metal,CFrame.Angles(0,math.rad(90),0),Enum.PartType.Cylinder) end
	P(m,"GearF",Vector3.new(1.6,7,1.6),Vector3.new(0,3.5,18),DMETAL,Mat.Metal)
	P(m,"GearL",Vector3.new(1.6,7,1.6),Vector3.new(-7,3.5,-2),DMETAL,Mat.Metal)
	P(m,"GearR",Vector3.new(1.6,7,1.6),Vector3.new(7,3.5,-2),DMETAL,Mat.Metal)
	-- pilot NPC placeholder
	local pm=Instance.new("Model"); pm.Name="Pilot"; pm.Parent=m
	P(pm,"Legs",Vector3.new(2,3,1.5),Vector3.new(11,1.5,12),DOLIVE,Mat.SmoothPlastic)
	P(pm,"Torso",Vector3.new(2.2,3,1.4),Vector3.new(11,4.5,12),OLIVE,Mat.SmoothPlastic)
	local head=P(pm,"Head",Vector3.new(1.4,1.4,1.4),Vector3.new(11,6.7,12),Color3.fromRGB(214,181,140),Mat.SmoothPlastic)
	lbl(head,"PILOT",DOLIVE)
	lbl(fus,"PLANE")
end

-- ---- PARTY / LAUNCH PADS ----
local function pad(color,name,pos)
	local m=station("PartyPad_"..name,"PartyPad",pos+Vector3.new(0,3,0))
	m:SetAttribute("PadColor",name)
	P(m,"Ring",Vector3.new(2,20,20),pos+Vector3.new(0,1,0),PLANK,Mat.WoodPlanks,DISC,Enum.PartType.Cylinder)
	local top=P(m,"Center",Vector3.new(2.4,14,14),pos+Vector3.new(0,1.1,0),color,Mat.Neon,DISC,Enum.PartType.Cylinder)
	top.Transparency=0.15
	lbl(m.Anchor,name.." PAD",color)
end
pad(BLUE,"Blue",Vector3.new(-30,0,-22))
pad(RED,"Red",Vector3.new(30,0,-22))
pad(GREEN,"Green",Vector3.new(-30,0,30))
pad(YELLOW,"Yellow",Vector3.new(30,0,30))

-- ---- STATION BUILDINGS (code set) ----
-- generic open-front stall (front faces +X)
local function stall(name,stype,cx,cz,roofCol,signCol,labelText)
	local m=station(name,stype,Vector3.new(cx+9,4,cz))
	P(m,"Floor",Vector3.new(20,1,18),Vector3.new(cx,0.5,cz),DWOOD,Mat.WoodPlanks)
	P(m,"BackWall",Vector3.new(1,11,18),Vector3.new(cx-10,6,cz),PLANK,Mat.WoodPlanks)
	P(m,"WallN",Vector3.new(20,11,1),Vector3.new(cx,6,cz-9),PLANK,Mat.WoodPlanks)
	P(m,"WallS",Vector3.new(20,11,1),Vector3.new(cx,6,cz+9),PLANK,Mat.WoodPlanks)
	P(m,"Counter",Vector3.new(1.5,4,14),Vector3.new(cx+8,2.5,cz),WOOD,Mat.Wood)
	P(m,"Roof",Vector3.new(24,1,22),Vector3.new(cx+1,12.4,cz),roofCol,Mat.CorrodedMetal,CFrame.Angles(0,0,math.rad(-8)))
	P(m,"Sign",Vector3.new(0.6,4.5,13),Vector3.new(cx+10.4,10.5,cz),signCol,Mat.SmoothPlastic)
	P(m,"FlagPole",Vector3.new(0.5,16,0.5),Vector3.new(cx+9,8,cz-9),DMETAL,Mat.Metal)
	P(m,"Flag",Vector3.new(0.3,3,4),Vector3.new(cx+9,14,cz-6.5),signCol,Mat.Fabric)
	lbl(m.Anchor,labelText,signCol)
end
stall("SkillTrainer","SkillTrainer",-105,-25,DOLIVE,BLUE,"SKILL TRAINER")
stall("Bounties","Bounties",-105,45,DOLIVE,GOLD,"BOUNTIES")

-- Robux Shop: small kiosk on the plaza
do
	local m=station("RobuxShop","RobuxShop",Vector3.new(-58,5,42))
	P(m,"Base",Vector3.new(6,1,6),Vector3.new(-58,0.5,42),DWOOD,Mat.WoodPlanks)
	P(m,"Kiosk",Vector3.new(4,5,3),Vector3.new(-58,3.5,42),GREEN,Mat.SmoothPlastic)
	P(m,"Roof",Vector3.new(6,0.6,6),Vector3.new(-58,6.5,42),DOLIVE,Mat.CorrodedMetal)
	lbl(m.Anchor,"ROBUX SHOP",GREEN)
end

-- Boat Upgrades: at the water / dock shore (moved close to water per request)
do
	local m=station("BoatUpgrades","BoatUpgrades",Vector3.new(112,5,5))
	P(m,"Bench",Vector3.new(8,1,6),Vector3.new(112,1.5,5),DWOOD,Mat.WoodPlanks)
	P(m,"Rig",Vector3.new(5,5,4),Vector3.new(112,4,5),METAL,Mat.Metal)
	P(m,"Arm",Vector3.new(6,0.6,0.6),Vector3.new(115,6,5),DMETAL,Mat.Metal)
	P(m,"Sign",Vector3.new(0.5,3,6),Vector3.new(112,8,5),GREEN,Mat.SmoothPlastic)
	lbl(m.Anchor,"BOAT UPGRADES",GREEN)
end

-- ---- DOCK / JETTY (scenery near boat upgrades & water) ----
do
	local m=Instance.new("Model"); m.Name="Dock"; m.Parent=Scenery
	P(m,"Pier",Vector3.new(46,1,9),Vector3.new(150,1.5,5),PLANK,Mat.WoodPlanks)
	for _,px in ipairs({130,145,160,172}) do
		P(m,"Post",Vector3.new(1.2,12,1.2),Vector3.new(px,-4,1),DWOOD,Mat.Wood)
		P(m,"Post2",Vector3.new(1.2,12,1.2),Vector3.new(px,-4,9),DWOOD,Mat.Wood) end
	P(m,"Winch",Vector3.new(3,3,3),Vector3.new(170,3.5,5),RUST,Mat.Metal)
	lbl(m.Pier,"DOCK",PLANK)
end

-- ---- DISPLAYS: leaderboards ----
local function board(name,cx,cz,face,title,accent)
	local m=Instance.new("Model"); m.Name=name; m.Parent=Displays
	P(m,"PostL",Vector3.new(1,12,1),Vector3.new(cx-6,6,cz),DWOOD,Mat.Wood)
	P(m,"PostR",Vector3.new(1,12,1),Vector3.new(cx+6,6,cz),DWOOD,Mat.Wood)
	local b=P(m,"Board",Vector3.new(14,8,0.6),Vector3.new(cx,11,cz),DWOOD,Mat.WoodPlanks)
	P(m,"Trim",Vector3.new(15,9,0.4),Vector3.new(cx,11,cz+0.2*face),accent,Mat.SmoothPlastic)
	lbl(b,title,accent)
end
board("Leaderboard_TopRuns",-62,-56,1,"TOP RUNS",GOLD)
board("Leaderboard_Weekly",62,-56,1,"WEEKLY",BLUE)

-- ---- WELCOME SIGN ----
do
	local m=Instance.new("Model"); m.Name="WelcomeSign"; m.Parent=Displays
	P(m,"PostL",Vector3.new(1.2,11,1.2),Vector3.new(-8,5,120),DWOOD,Mat.Wood)
	P(m,"PostR",Vector3.new(1.2,11,1.2),Vector3.new(8,5,120),DWOOD,Mat.Wood)
	local bd=P(m,"Board",Vector3.new(18,5,1),Vector3.new(0,9,120),WOOD,Mat.WoodPlanks)
	P(m,"Trim",Vector3.new(19,5.8,0.6),Vector3.new(0,9,120.4),GOLD,Mat.SmoothPlastic)
	lbl(bd,"WELCOME TO JUNGLE AIRFIELD",GOLD)
end

-- ---- WATCHTOWERS ----
local function tower(name,cx,cz)
	local m=Instance.new("Model"); m.Name=name; m.Parent=Scenery
	for _,o in ipairs({{-4,-4},{4,-4},{-4,4},{4,4}}) do P(m,"Leg",Vector3.new(1.2,20,1.2),Vector3.new(cx+o[1],10,cz+o[2]),DWOOD,Mat.Wood) end
	local plat=P(m,"Platform",Vector3.new(11,1,11),Vector3.new(cx,20,cz),PLANK,Mat.WoodPlanks)
	P(m,"Rail",Vector3.new(11,3,1),Vector3.new(cx,22,cz-5),WOOD,Mat.Wood)
	P(m,"Roof",Vector3.new(13,1,13),Vector3.new(cx,27,cz),CANVAS,Mat.Fabric)
	lbl(plat,name)
end
tower("Watchtower_NW",-95,-120)
tower("Watchtower_NE",90,-120)

-- ---- RUNWAY MARKINGS ----
do
	local m=Instance.new("Model"); m.Name="RunwayMarkings"; m.Parent=Scenery
	for z=-120,-460,-40 do P(m,"Dash",Vector3.new(3,0.2,14),Vector3.new(0,0.15,z),CREAM,Mat.SmoothPlastic) end
	for _,sx in ipairs({-7,-3,3,7}) do P(m,"Threshold",Vector3.new(1.6,0.2,10),Vector3.new(sx,0.15,-112),CREAM,Mat.SmoothPlastic) end
end

-- ---- SCENERY: expedition-camp props (crates/barrels/tents/etc.) ----
local function crates(cx,cz)
	P(Scenery,"Crate",Vector3.new(4,4,4),Vector3.new(cx,2,cz),WOOD,Mat.Wood)
	P(Scenery,"Crate",Vector3.new(4,4,4),Vector3.new(cx+4.2,2,cz),WOOD,Mat.Wood)
	P(Scenery,"Crate",Vector3.new(4,4,4),Vector3.new(cx+2,6,cz+0.5),DWOOD,Mat.Wood)
end
local function barrels(cx,cz)
	for _,o in ipairs({{0,0},{3,0.5},{1.5,3}}) do
		P(Scenery,"Barrel",Vector3.new(2.4,4,2.4),Vector3.new(cx+o[1],2,cz+o[2]),RUST,Mat.Metal,nil,Enum.PartType.Cylinder) end
end
local function tent(cx,cz)
	P(Scenery,"TentFloor",Vector3.new(10,0.4,8),Vector3.new(cx,0.4,cz),DWOOD,Mat.WoodPlanks)
	P(Scenery,"TentRoof",Vector3.new(11,0.4,6),Vector3.new(cx,5,cz-2),CANVAS,Mat.Fabric,CFrame.Angles(math.rad(30),0,0))
	P(Scenery,"TentRoof",Vector3.new(11,0.4,6),Vector3.new(cx,5,cz+2),CANVAS,Mat.Fabric,CFrame.Angles(math.rad(-30),0,0))
end
local function campfire(cx,cz)
	P(Scenery,"FirePit",Vector3.new(4,0.6,4),Vector3.new(cx,0.5,cz),DMETAL,Mat.Rock,DISC,Enum.PartType.Cylinder)
	P(Scenery,"Logs",Vector3.new(1,1,4),Vector3.new(cx,1,cz),WOOD,Mat.Wood)
	local f=P(Scenery,"Flame",Vector3.new(2,3,2),Vector3.new(cx,2.5,cz),Color3.fromRGB(230,140,50),Mat.Neon); f.Transparency=0.3
end
local function sandbags(cx,cz)
	for i=0,3 do P(Scenery,"Sandbag",Vector3.new(3,1.4,2),Vector3.new(cx+i*3,1,cz),SAND,Mat.Sand) end
	for i=0,2 do P(Scenery,"Sandbag",Vector3.new(3,1.4,2),Vector3.new(cx+1.5+i*3,2.4,cz),SAND,Mat.Sand) end
end
local function foliage(cx,cz)
	P(Scenery,"Trunk",Vector3.new(1.6,12,1.6),Vector3.new(cx,6,cz),WOOD,Mat.Wood)
	P(Scenery,"Canopy",Vector3.new(12,7,12),Vector3.new(cx,14,cz),GREEN,Mat.Grass,nil,Enum.PartType.Ball)
	P(Scenery,"Bush",Vector3.new(5,4,5),Vector3.new(cx+5,2,cz+3),DOLIVE,Mat.Grass,nil,Enum.PartType.Ball)
end
crates(-70,-10); crates(-40,55); crates(60,-25); crates(95,15)
barrels(-115,10); barrels(120,-10); barrels(-50,-45)
tent(-70,70); tent(55,45)
campfire(-15,55); campfire(70,-45)
sandbags(-90,-95); sandbags(75,-95)
-- foliage clumps ringing the clearing
foliage(-150,-40); foliage(-150,60); foliage(-120,110); foliage(-40,150)
foliage(60,145); foliage(130,90); foliage(150,-60); foliage(120,-110)
foliage(20,-90); foliage(-60,-110)

local total=#Stations:GetChildren()+#Displays:GetChildren()+#Scenery:GetChildren()
return "greybox lobby built: "..#Stations:GetChildren().." stations, "..#Displays:GetChildren().." displays, "..#Scenery:GetChildren().." scenery, total "..total
