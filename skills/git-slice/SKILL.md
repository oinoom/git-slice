---
name: git-slice
description: Selectively stage only part of the current unstaged Git diff using the local `git slice` tool. Use when Codex needs to stage specific hunks or patch edits without staging an entire file, when the user asks to stage “just this part”, “only these changes”, “piecewise stage”, or when `git add -p` would normally be the manual fallback.
---

# Git Slice

Stage selected hunks or edited patches with `git slice` instead of driving
`git add -p` interactively.

This skill is primarily useful for AI agents that do not interact well with an
interactive TUI. The intended setup is to put this repo on `PATH` so Git
automatically discovers the `git-slice` wrapper and the agent can use
`git slice` directly.

Use `git slice` as the primary interface. Only fall back to the repo-local
`./slice` command if `git slice` is unavailable in the current environment.

## Workflow

1. Inspect the current unstaged diff with `git slice show`.
2. Decide whether the change is best handled as whole hunks or as an edited patch.
3. Stage the selected portion with `git slice pick`.
4. Re-run `git slice show` before making another selection, because hunk IDs can change after staging.

## Inspect

Use `--path` as the canonical way to scope to one file:

```bash
git slice show --path path/to/file
```

Use repo-wide mode when the user did not specify a file or wants to stage
across multiple files:

```bash
git slice show
```

Use IDs when you want only specific hunks back:

```bash
git slice show 3
git slice show --path path/to/file 2
```

Interpret the JSON as follows:

- `id`: selector for `pick`
- `path`: file that owns the hunk in repo-wide mode
- `file_hunk_id`: local hunk id within one file
- `diff`: exact patch text for that hunk
- `addition`: added lines for the hunk when present
- `subtraction`: removed lines for the hunk when present
- `old_start` / `new_start`: line anchors from the diff header

`show` returns a flat JSON array of hunks, not a wrapper object.

Positional path syntax still works as a compatibility shortcut, but prefer
`--path` in new usage.

## Choose The Mode

Use `pick` when whole hunks match the desired change.

Use `patch` plus `apply` when the hunk contains multiple logical edits and only
part of the hunk should be staged.

## Stage Whole Hunks

File-scoped:

```bash
git slice pick --path path/to/file 1 3
```

Repo-wide:

```bash
git slice pick 2 5-7
```

## Stage Part Of A Hunk

Export the patch, edit it, and apply it to the index:

```bash
git slice patch path/to/file > partial.patch
git slice apply partial.patch
```

Or use stdin:

```bash
git slice patch path/to/file | sed '/^+debug/d' | git slice apply -
```

When editing the patch, remove added lines or whole hunk pieces you do not want
to stage. Do not assume hunk IDs are stable after `apply`; run `show` again.

## Safety Rules

- Use `show` before `pick`; do not guess hunk IDs.
- Re-run `show` after each successful `pick` or `apply`.
- Prefer `--path <path>` with `show` and `pick` for all new usage, not just
  ambiguous filenames.
- Prefer the `diff` field from `show` when deciding which hunk to stage.
- Prefer `patch` plus `apply` for sub-hunk precision instead of trying to map
  line-level intent onto whole-hunk selection.
