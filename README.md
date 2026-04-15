# git-slice

`git slice` is a non-interactive interface for selectively staging and
unstaging Git changes.

It is mainly for AI agents and other automation that do not handle
`git add -p` well. Instead of driving an interactive TUI, an agent can:

1. inspect hunks as JSON
2. choose hunk ids, line ids, or stable opaque ids
3. stage or unstage only those selected changes

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

## Typical Tasks

### Stage Whole Hunks

Use this when the current diff has multiple logical changes and you want only
some of them in the next commit.

```bash
git slice show
git slice pick 2 5-7
```

File-scoped:

```bash
git slice show --path app/models/user.rb
git slice pick --path app/models/user.rb 2
```

### Stage One Line-Level Change Inside A Hunk

Each hunk in `show` includes a `lines` array. Those entries are also
selectable.

```bash
git slice show --path app/models/user.rb
git slice pick --path app/models/user.rb 1.2
```

You can also use the stable line id instead of the numeric line id:

```bash
git slice pick --path app/models/user.rb c_7a2f0b2d8f9d2e41
```

### Undo A Staged Slice

Inspect the staged diff, then unstage only the hunk or line-level change you
want to remove from the index.

```bash
git slice show --staged --path app/models/user.rb
git slice unstage --path app/models/user.rb 1
```

Line-level unstaging works too:

```bash
git slice unstage --path app/models/user.rb 1.1
```

### Keep Splitting The Remaining Diff

Only re-run `show` if you want to keep making another selection. Numeric ids
are derived from the current diff, so they can change after every successful
`pick` or `unstage`.

If you are automating a longer loop, prefer the stable opaque ids returned by
`show`.

## What `show` Returns

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
    "stable_id": "h_1d50f4d0e203dc27",
    "path": "app/models/user.rb",
    "file_hunk_id": 1,
    "header": "@@ -10,2 +10,2 @@",
    "old_start": 10,
    "old_count": 2,
    "new_start": 10,
    "new_count": 2,
    "kind": "mixed",
    "added_lines": 2,
    "removed_lines": 2,
    "lines": [
      {
        "id": "1.1",
        "stable_id": "c_4a4c5c888f842d6f",
        "kind": "mixed",
        "addition": "+new value\n",
        "subtraction": "-old value\n"
      },
      {
        "id": "1.2",
        "stable_id": "c_88b8a6d7b9fdf2c9",
        "kind": "addition",
        "addition": "+extra line\n"
      }
    ],
    "addition": "+new value\n+extra line\n",
    "subtraction": "-old value\n",
    "diff": "diff --git a/app/models/user.rb b/app/models/user.rb\nindex 1111111..2222222 100644\n--- a/app/models/user.rb\n+++ b/app/models/user.rb\n@@ -10,2 +10,2 @@\n-old value\n+new value\n+extra line\n"
  }
]
```

The fields most people care about are:

- `id`: numeric hunk selector for `pick` or `unstage`
- `stable_id`: content-based hunk selector that is usually more stable across
  unrelated staging changes
- `lines`: selectable line-level changes inside the hunk
- `diff`: exact patch for the full hunk
- `addition`: added lines for the full hunk, when present
- `subtraction`: removed lines for the full hunk, when present

Each entry in `lines` is also selectable:

- `id`: numeric line selector like `1.2`
- `stable_id`: content-based line selector like `c_...`
- `kind`: `mixed`, `addition`, or `deletion`
- `addition`: added line text, when present
- `subtraction`: removed line text, when present

In mixed hunks, one line entry can contain both `subtraction` and `addition`.
That represents one replacement pair inside the hunk.

## Selector Types

`git slice show` accepts hunk selectors:

- numeric hunk ids like `1`
- numeric hunk ranges like `2-5`
- stable hunk ids like `h_1d50f4d0e203dc27`

`git slice pick` and `git slice unstage` accept all of those plus line
selectors:

- numeric line ids like `1.2`
- stable line ids like `c_4a4c5c888f842d6f`

Numeric ids are short and easy to read, but they are local to the current diff
view. Stable ids are content-based, so they are better for automation, but they
will still change if the underlying change changes.

## Scope

By default, ids are repo-wide:

```bash
git slice show
git slice show 3
git slice pick 2 5-7
git slice unstage 1
```

Use `--path` to scope to one file. In that mode, numeric ids are local to that
file:

```bash
git slice show --path app/models/user.rb
git slice pick --path app/models/user.rb 1.2
git slice show --staged --path app/models/user.rb
git slice unstage --path app/models/user.rb 1
```

Use `--path` as the normal file-scoped form. Positional path syntax still
works as a compatibility shortcut:

```bash
git slice show app/models/user.rb 2
git slice pick app/models/user.rb 1.2
git slice unstage app/models/user.rb 1
```

But positional paths are ambiguous for unusual filenames, especially
numeric-looking ones. `--path` avoids that ambiguity.

## Unsupported Changes

`git slice` only works on text hunks that Git can represent as diff hunks.

If the current scope contains only unsupported changes, `show` fails with a
specific message. Common examples include:

- binary files
- rename-only changes
- mode-only changes
- submodule changes

If the current scope contains both selectable text hunks and unsupported
changes, `show` still returns JSON for the selectable hunks and prints a
warning on stderr describing what it ignored.

## Advanced Patch Editing

Use `patch` and `apply` only when whole hunks and line-level selectors are
still too coarse, or when you want to hand-edit the exact patch.

`patch` prints the current diff. You edit that patch, then `apply` applies the
edited patch to the index only.

```bash
git slice patch demo.txt > patch.diff
# edit patch.diff
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

For staged changes:

```bash
git slice patch --staged path/to/file
```

## Command Summary

`git slice show [--path PATH] [--staged] [selectors ...]`

Show hunks as JSON with stable ids and line-level entries.

`git slice pick [--path PATH] <selectors ...>`

Stage selected hunk ids, line ids, or stable ids.

`git slice unstage [--path PATH] <selectors ...>`

Unstage selected staged hunks, line ids, or stable ids.

`git slice pick --print-patch ...`

Print the patch that would be staged instead of applying it.

`git slice unstage --print-patch ...`

Print the patch that would be reversed instead of unstaging it.

`git slice patch [--staged] [--zero-context] [path]`

Print the current unstaged or staged patch for one path or for the whole repo.

`git slice apply <patch-file|->`

Apply an edited patch to the index only.

## Skill

A repo-contained skill lives at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).
