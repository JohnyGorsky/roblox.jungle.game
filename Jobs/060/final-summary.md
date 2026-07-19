# Final Summary — Job #060: Fix memory leak — cull far landing-site basins/camps

**Project**: `roblox.jungle` · **Completed**: 2026-07-19 · POC · Review follow-up (greybox-polish-perf).

## The leak
`ExcursionServer` built `LandingSite` models (trees/huts/crates/guards) and set `built[index]=true`, but never
destroyed them — so over an 18000-stud run they accumulated indefinitely (a real instance/memory leak).

## Fix (`ExcursionServer`)
- Track `siteModels[index] → model` at build.
- In the stream loop, **cull** any landing site more than `CULL_BEHIND` (1200) studs behind the boat — but
  only when **no player is in its basin** (don't yank someone ashore into the void). On cull: clear the site's
  guards' `guardState`, `model:Destroy()`, and clear `siteModels[index]` + `built[index]`.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Built the first landing (z=1600), sailed the boat to z=3005 (>2800), waited a tick → the LandingSite
      was destroyed (`Camps` children → 0), player not in basin.
- **Not committed.**

## Notes
- Only the instance models are culled; carved basin terrain is left (cheap voxels; the river chunk-culler
  handles nearby terrain). If needed later, the basin could be filled back.
