# todo/ — quick-capture task queue (Last River / roblox.jungle)

Lightweight queue for **thoughts, small tasks, tweaks, reminders** — lighter than `Planned/` (features →
Jobs) and `Jobs/` (full work). One file per item, numbered `NNNN` (0000+), greppable `Status:` line.

## Use (shared `job.py` in `roblox.workspace/tools`)
- **Capture:** `python ../roblox.workspace/tools/job.py todo --project jungle "Short title" ["note"]`
- **Done:** `python ../roblox.workspace/tools/job.py resolve --project jungle todo NNNN ["what/where"]`
- **List:** `python ../roblox.workspace/tools/job.py list --project jungle todo [--open]`
- Promote real work to a **Job**. _todo = things to do; findings = deferred bugs._
