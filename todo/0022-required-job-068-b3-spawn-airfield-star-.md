# TODO 0022: REQUIRED (Job 068 B3): Spawn airfield star is still a greybox cream cylinder

**Project:** `roblox.jungle`
**Status:** REOPENED (2026-08-02) — the live sweep found it unchanged. See below.
**Created:** 2026-08-02 10:50:31

## ⚠️ Reopened by the Job #068 live greybox sweep (2026-08-02)

This was resolved on the user's report that they had fixed it themselves. The sweep, run read-only via
Studio MCP against the open **Last River COOP lobby** place, found `Stations.Spawn.Star` **unchanged**:

| Property | Live value | `greybox_placement.luau:55` original |
|---|---|---|
| Size | `2.2 × 11 × 11` | `2.2 × 11 × 11` |
| Colour | `(243, 230, 194)` | CREAM `(243, 230, 194)` |
| Material | `SmoothPlastic` | `SmoothPlastic` |
| Transparency | `0` | `0` |
| Children | **0** — no Decal, no Texture | none |

Byte-for-byte the greybox part. The most likely explanations are that the fix was made in a different
place or session, or made and not saved. **Needs the user to confirm what changed** before this closes
again — and this time it should close on the sweep, not on report.

Note `Spawn.Pad` (the sand disc under it) is also still the greybox original — tracked in `todo/0036`.

Audit Job 068, gap B3. ASSETS.md 1.8 lists the painted military star as pending (user) -- the decal was never generated. What is actually in the place is greybox_placement.luau:55: a cream SmoothPlastic cylinder named Star, 11 studs across, on the spawn pad. This is the first thing every player sees on join. Also confirm whether Spawn.Pad (sand cylinder, 26 studs) is intentional or greybox. Options: generate the decal, or drop the star and let the sand pad stand alone.
