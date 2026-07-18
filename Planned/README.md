# Planned/ — backlog for Roblox Jungle

One markdown file per planned item (idea, feature, mechanic, fix). Staging area **before** something
becomes a job.

## Convention

- One file per item: `Planned/<short-kebab-name>.md`.
- Keep it loose — a title, a few notes, why it matters, open questions.
- **Promote to a job** when ready:
  ```bash
  python ../roblox.workspace/tools/job.py new --project jungle --from Planned/<item>.md
  ```

High-level vision lives in [../GAME.md](../GAME.md); this folder is the concrete queue.
