---
name: git-slice
description: Selectively stage or unstage part of the current Git diff using the local `git slice` tool. Use when Codex needs to stage or unstage specific hunks, line-level changes, or patch edits without operating on an entire file, when the user asks to stage “just this part”, “only these changes”, “piecewise stage”, or when `git add -p` would normally be the manual fallback.
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
2. Choose whether to act on whole hunks, line-level changes inside a hunk, or stable ids returned by `show`.
3. Stage the selected portion with `git slice pick`.
4. Use `git slice show --staged` and `git slice unstage` if part of the staged selection should be removed from the index.
5. Re-run `git slice show` only when continuing to split the remaining unstaged diff, because numeric ids can change after staging.

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

Use hunk selectors when you want only specific hunks back:

```bash
git slice show 3
git slice show --path path/to/file 2
```

Interpret the JSON as follows:

- `id`: selector for `pick`
- `stable_id`: content-based selector that is usually more stable across unrelated staging changes
- `path`: file that owns the hunk in repo-wide mode
- `file_hunk_id`: local hunk id within one file
- `lines`: selectable line-level changes inside the hunk
- `diff`: exact patch text for that hunk
- `addition`: added lines for the hunk when present
- `subtraction`: removed lines for the hunk when present
- `old_start` / `new_start`: line anchors from the diff header

`show` returns a flat JSON array of hunks, not a wrapper object.

Each entry in `lines` is also selectable:

- numeric line id like `1.2`
- stable line id like `c_...`

In mixed hunks, a `lines` entry may contain both `subtraction` and `addition`.
That represents one replacement pair inside the hunk.

Positional path syntax still works as a compatibility shortcut, but prefer
`--path` in new usage.

## Choose The Mode

Use `pick` when whole hunks or line-level selectors match the desired change.

Use `patch` plus `apply` when the hunk contains multiple logical edits and only
part of the hunk should be staged in a way that still cannot be expressed by
the line-level selectors.

## Stage Or Unstage By Selector

File-scoped:

```bash
git slice pick --path path/to/file 1 3
git slice pick --path path/to/file 1.2
git slice pick --path path/to/file h_1d50f4d0e203dc27
git slice pick --path path/to/file c_4a4c5c888f842d6f
```

Repo-wide:

```bash
git slice pick 2 5-7
```

For staged changes:

```bash
git slice show --staged --path path/to/file
git slice unstage --path path/to/file 1
git slice unstage --path path/to/file 1.1
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
to stage. Do not assume numeric ids are stable after `pick`, `unstage`, or
`apply`; run `show` again if the agent is continuing to split the remaining
diff.

## Safety Rules

- Use `show` before `pick`; do not guess hunk IDs.
- Use `show --staged` before `unstage`; do not guess staged IDs.
- Re-run `show` after each successful `pick`, `unstage`, or `apply` only when
  making another selection from the changed diff.
- Prefer `--path <path>` with `show` and `pick` for all new usage, not just
  ambiguous filenames.
- Prefer the `stable_id` fields when the agent wants a selector that is more
  resilient than the short numeric ids.
- Prefer the `diff` field from `show` when deciding which hunk to stage or
  unstage.
- Prefer line-level selectors before falling back to `patch` plus `apply`.
