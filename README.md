# git-slice

`git slice` is a non-interactive interface for staging part of the current
unstaged diff.

It is mainly for AI agents and other automation that do not handle `git add -p`
well. Instead of driving an interactive TUI, an agent can:

1. inspect hunks as JSON
2. choose hunk IDs
3. stage those hunks directly

If you want `git add -p` style selective staging for tools like Codex or
Claude, this is the interface.

For installation and skill setup, see [install.md](install.md).

## How `git slice` is found

Put this repo on your `PATH`.

Git looks for executables named `git-*` on `PATH`, so once this repo root is on
`PATH`, Git discovers [git-slice](git-slice), which is a small wrapper around
[slice](slice).

After that, use:

```bash
git slice ...
```

## Typical Use

Use `git slice` when the current diff contains more than one logical change and
you want to stage only the parts that belong in the next commit.

The usual flow is:

1. run `git slice show` to inspect the current selectable hunks and their IDs
2. run `git slice pick ...` with the IDs you want to stage for this commit
3. stop there if you are done, or run `git slice show` again only if you want
   to keep splitting the remaining unstaged diff into another commit

Repo-wide example:

```bash
git slice show
git slice pick 2 5-7
```

One-file example:

```bash
git slice show --path app/models/user.rb
git slice pick --path app/models/user.rb 2
```

If you are making several partial commits from the same working tree, inspect
again after each successful `pick`. Hunk IDs are computed from the current
remaining diff, so they can change after staging part of it.

## What `show` returns

`git slice show` returns a flat JSON array of hunks.

Example:

```bash
git slice show --path app/models/user.rb
```

Example output:

```json
[
  {
    "id": 1,
    "path": "app/models/user.rb",
    "file_hunk_id": 1,
    "header": "@@ -10 +10 @@",
    "old_start": 10,
    "old_count": 1,
    "new_start": 10,
    "new_count": 1,
    "kind": "mixed",
    "added_lines": 1,
    "removed_lines": 1,
    "addition": "+new value\n",
    "subtraction": "-old value\n",
    "diff": "diff --git a/app/models/user.rb b/app/models/user.rb\nindex 1111111..2222222 100644\n--- a/app/models/user.rb\n+++ b/app/models/user.rb\n@@ -10 +10 @@\n-old value\n+new value\n"
  }
]
```

The fields most people care about are:

- `id`: pass this to `pick`
- `diff`: exact patch for that hunk
- `addition`: added lines, when present
- `subtraction`: removed lines, when present

Other fields are there for tooling:

- `path`
- `file_hunk_id`
- `header`
- `old_start` / `new_start`
- `old_count` / `new_count`
- `kind`
- `added_lines` / `removed_lines`

## Scope And Selectors

By default, IDs are repo-wide:

```bash
git slice show
git slice show 3
git slice pick 2 5-7
```

Use `--path` to scope to one file. In that mode, IDs are local to that file:

```bash
git slice show --path app/models/user.rb
git slice show --path app/models/user.rb 2
git slice pick --path app/models/user.rb 1 3
```

Use `--path` as the normal file-scoped form. Positional path syntax still
works as a compatibility shortcut:

```bash
git slice show app/models/user.rb 2
git slice pick app/models/user.rb 2
```

But positional paths are ambiguous for unusual filenames, especially
numeric-looking ones. `--path` avoids that ambiguity.

## Failure Modes

`git slice show` can fail in two common ways:

- Clean diff: `No unstaged changes found.`
- No text hunks available: `No text hunks available for partial staging.`

The second case usually means Git does not have text hunks to work with for the
current change.

## Sub-Hunk Edits

Use `patch` and `apply` only when one hunk still contains multiple logical
edits and hunk-level `pick` is too coarse.

`patch` prints the current diff. You edit that patch, then `apply` applies the
edited patch to the index only.

```bash
git slice patch demo.txt > patch.diff
# remove unwanted + or - lines from patch.diff
git slice apply patch.diff
```

From stdin:

```bash
git slice patch path/to/file | sed '/^+debug/d' | git slice apply -
```

If you want a machine-oriented patch with minimal context:

```bash
git slice patch --zero-context path/to/file
```

## Command Summary

`git slice show [--path PATH] [selectors ...]`

Show hunks as JSON with inline diff text.

`git slice pick [--path PATH] <selectors ...>`

Stage selected hunk IDs.

`git slice pick --print-patch ...`

Print the patch that would be staged instead of applying it.

`git slice patch [path]`

Print the current unstaged patch for one path or for the whole repo.

`git slice apply <patch-file|->`

Apply an edited patch to the index only.

## Skill

A repo-contained skill lives at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).
