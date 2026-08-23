# FINDING 0024: Turret elevation collapses to almost nothing at the edges of the traverse arc

**Project:** `roblox.jungle`
**Status:** fixed (2026-08-23) — Fixed in Job #105. Aim composition changed to CFrame.Angles(0,yaw,0) * CFrame.Angles(pitch,0,0) at all four sites (GunServer:143 aimCFrame, GunClient:116 camera, GunClient:175 tracer, BoatTurretVisual:75 barrel mesh). Verified in Play through the real remote, reading the actual barrel: -22.60 deg held at yaw 0/40/80/-80 and +45.50 deg at yaw 80, where the old form gave -3.83/+7.11 at the arc edges.
**Severity:** med
**Created:** 2026-08-23 17:16:39

**Symptom:** GunServer:143, GunClient:116 and BoatTurretVisual:75 all build the aim as CFrame.Angles(pitch, yaw, 0), which is Rx*Ry - so pitch is applied about the UN-yawed base X axis and the pitch axis does not follow the traverse. World elevation is asin(cos(yaw) * sin(pitch)), so the down stop degrades from -12.00 deg at yaw 0 to -2.07 deg at yaw 80. The correct turret order CFrame.Angles(0,yaw,0) * CFrame.Angles(pitch,0,0) holds the full angle at every yaw. Same cause also Dutch-angles the gunner camera (~11.8 deg horizon tilt at max yaw). Found by the Job #105 reviewer agent.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
