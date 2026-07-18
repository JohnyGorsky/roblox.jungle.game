# Greybox polish & perf cleanup

**Source:** playtest notes (2026-07-18). Small cleanups that aren't a full phase — batch when convenient.

- **Obstacle/ramp hook markers** (#005) — the big translucent red/green blocks on the water clutter the
  view. Shrink them, make them subtler, or hide them until real rock/log/ramp props exist.
- **Cull far landing sites & camps** (#012) — landing zones/camps are built once and never removed
  (`built[index]` never cleared); over a long run they accumulate in memory. Add a behind-the-boat cull
  like the terrain/dock/foliage streamers.
- **Crocs keep "attacking" a destroyed boat** — a boat at 0 HP still gets bitten (flashes red forever).
  Stop attacking / despawn threats once the boat is destroyed.
- **HUD polish** — the cargo/ammo readout, fuel/boat bars, and gunner ammo cue are greybox and overlap
  the VehicleSeat speed gauge; a proper HUD layout is P9, but a tidy-up pass may be worth it sooner.
- **Client "out of ammo" feedback** — the handheld still draws a tracer when the server rejects the shot
  for no ammo; add a client-side ammo check + a small "empty" cue.

(Most of these are minor; the landing-site cull is the one with a real memory impact on long runs.)

→ Promote to a job (or fold individual items into other work).
