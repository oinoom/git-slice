# git-slice

`slice` stages selected portions of the current unstaged diff without using
`git add -p`.

The normal loop is:

1. `slice show`
2. `slice pick`
3. `slice show` again

For installation and skill setup, see [install.md](install.md).

## Happy Path

Repo-wide:

```bash
./slice show
./slice pick 2 5-7
./slice show
```

One file:

```bash
./slice show --path app/models/user.rb
./slice pick --path app/models/user.rb 2
./slice show --path app/models/user.rb
```

## Selector Rules

Use `--path` as the canonical way to scope to one file.

- No `--path`: IDs are repo-wide.
- `--path <file>`: IDs are local to that file.
- `slice show 3` means repo-wide hunk `3`.
- `slice show --path app/models/user.rb 2` means file-local hunk `2`.

After a successful `pick`, run `show` again before choosing more IDs. IDs are
recomputed from the current diff.

Positional path syntax still works as a compatibility shortcut:

```bash
./slice show app/models/user.rb 2
./slice pick app/models/user.rb 2
```

Prefer the `--path` form in new usage.

## `show`

`slice show` returns a flat JSON array of hunks.

Examples:

```bash
./slice show
./slice show 3
./slice show 2 5-7
./slice show --path app/models/user.rb
./slice show --path app/models/user.rb 2
./slice show --path "docs and notes/report.txt" 1
```

Example output:

```json
[
  {
    "id": 1,
    "path": "first.txt",
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
    "diff": "diff --git a/first.txt b/first.txt\nindex 1111111..2222222 100644\n--- a/first.txt\n+++ b/first.txt\n@@ -10 +10 @@\n-old value\n+new value\n"
  }
]
```

The fields most people care about are:

- `id`: pass this to `pick`
- `diff`: exact patch for that hunk
- `addition`: added lines, when present
- `subtraction`: removed lines, when present

Other fields are there to help agents and tooling:

- `path`
- `file_hunk_id`
- `header`
- `old_start` / `new_start`
- `old_count` / `new_count`
- `kind`
- `added_lines` / `removed_lines`

## `pick`

`slice pick` stages the selected hunk IDs.

Examples:

```bash
./slice pick 2
./slice pick 2 5-7
./slice pick --path app/models/user.rb 2
./slice pick --path app/models/user.rb 1 3
```

If you want to preview the exact patch that would be staged without applying it:

```bash
./slice pick --path app/models/user.rb 2 --print-patch
```

## Advanced Escape Hatch

Use `patch` and `apply` only when one hunk contains multiple logical edits and
you need sub-hunk precision.

```bash
./slice patch demo.txt > patch.diff
# remove unwanted + or - lines from patch.diff
./slice apply patch.diff
```

From stdin:

```bash
./slice patch path/to/file | sed '/^+debug/d' | ./slice apply -
```

## Commands

### `slice show [--path PATH] [selectors ...]`

Show hunks as a flat JSON array.

### `slice pick [--path PATH] <selectors ...>`

Stage selected hunk IDs.

### `slice patch [path]`

Print the full unstaged patch for a path or for the whole repo.

### `slice apply <patch-file|->`

Apply an edited patch to the index only.

## Git Integration

If `git-slice` is on your `PATH`, Git automatically exposes:

```bash
git slice ...
```

Example:

```bash
export PATH="/path/to/ai-partial-stage:$PATH"
git slice show
git slice pick 1 3
git status
```

## Skill

A repo-contained skill lives at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).
