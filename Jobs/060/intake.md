# Job #060: Fix memory leak: cull far landing-site basins/camps

**Project**: `roblox.jungle`
**Created**: 2026-07-19 23:11:34
**Status**: Requirements Gathering (intake)

## Requirements / goal

Review follow-up (greybox-polish-perf). ExcursionServer builds LandingSite models (trees/huts/crates/guards) and sets built[index]=true but NEVER culls them → they accumulate over the 18000-stud run. Add culling: track index→model, and in the stream loop destroy landing sites far behind the boat (CULL_BEHIND) when no player is in the basin; clear built[index] + guardState for its guards. Mirrors DockServer's dock culling. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
