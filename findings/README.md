# findings/ — deferred-bug log (Last River / roblox.jungle)

Bugs noticed mid-flight but deferred, so they're never lost. One file per finding, numbered `NNNN` (0000+),
`Status: open` → `fixed`.

## Use (shared `job.py` in `roblox.workspace/tools`)
- **Log:** `python ../roblox.workspace/tools/job.py finding --project jungle "Title" ["symptom"] [--severity low|med|high] [--where <file>]`
- **Fixed:** `python ../roblox.workspace/tools/job.py resolve --project jungle finding NNNN ["fixed in Job NNN"]`
- **List:** `python ../roblox.workspace/tools/job.py list --project jungle finding [--open]`
- Promote a real fix to a **Job**.
