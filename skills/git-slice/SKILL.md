---
name: git-slice
description: Selectively stage only part of the current unstaged Git diff using the local `git slice` tool. Use when Codex needs to stage specific hunks or patch edits without staging an entire file, when the user asks to stage “just this part”, “only these changes”, “piecewise stage”, or when `git add -p` would normally be the manual fallback.
---

# Git Slice

Stage selected hunks or edited patches with `git slice` instead of driving
`git add -p` interactively.

Prefer `git slice` when available on `PATH`. If it is not available, fall back
to the repo-local `./slice` command from the project root.

## Workflow

1. Inspect the current unstaged diff.
2. Decide whether the change is best handled as whole hunks or as an edited patch.
3. Stage the selected portion.
4. Re-list before making another selection, because hunk IDs can change after staging.

## Inspect

Use file-scoped mode when the task is clearly about one file:

```bash
git slice list path/to/file
```

Use repo-wide mode when the user did not specify a file or wants to stage
across multiple files:

```bash
git slice list
```

Interpret the JSON as follows:

- `id`: selector for `show` and `pick`
- `path`: file that owns the hunk in repo-wide mode
- `file_hunk_id`: local hunk id within one file
- `summary`: fast scan of the changed lines
- `old_start` / `new_start`: line anchors from the diff header

## Choose The Mode

Use `pick` when whole hunks match the desired change.

Use `patch` plus `apply` when the hunk contains multiple logical edits and only
part of the hunk should be staged.

## Stage Whole Hunks

File-scoped:

```bash
git slice pick path/to/file 1 3
```

Repo-wide:

```bash
git slice pick 2 5-7
```

Preview without staging:

```bash
git slice show path/to/file 2
git slice show 4 6
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
to stage. Do not assume hunk IDs are stable after `apply`; run `list` again.

## Safety Rules

- Use `list` before `pick`; do not guess hunk IDs.
- Re-run `list` after each successful `pick` or `apply`.
- Use `--path <path>` with `show` or `pick` when a filename could be confused
  with numeric selectors.
- Prefer `show` before `pick` when the summaries are ambiguous.
- Prefer `patch` plus `apply` for sub-hunk precision instead of trying to map
  line-level intent onto whole-hunk selection.
