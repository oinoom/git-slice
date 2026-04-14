# git-slice

`slice` stages selected portions of the current unstaged diff without using
`git add -p`.

The main interface is:

1. `slice show` to get a flat JSON list of hunks with IDs and inline diff details.
2. `slice pick` to stage one or more of those IDs.

For installation and skill setup, see [install.md](install.md).

## Start Here

Repo-wide flow:

```bash
./slice show
./slice pick 2 5-7
```

File-scoped flow:

```bash
./slice show app/models/user.rb
./slice pick app/models/user.rb 2
```

Show only specific hunks by ID:

```bash
./slice show 3
./slice show app/models/user.rb 2
```

## Step 1: Show Hunks

Run `slice show` first.

Without a path, it returns a flat JSON array of all current unstaged hunks in
the repo:

```bash
./slice show
```

With a path, it returns only hunks from that file:

```bash
./slice show app/models/user.rb
```

With one or more hunk IDs, it returns only those hunks:

```bash
./slice show 2
./slice show 2 5-7
./slice show app/models/user.rb 2
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

Important fields:

- `id`: selector for `pick`
- `path`: file that owns the hunk
- `file_hunk_id`: hunk number within that file
- `old_start` / `new_start`: line numbers from the diff header
- `kind`: `mixed`, `addition`, `deletion`, or `context`
- `diff`: exact patch fragment for that hunk
- `addition`: added lines for that hunk, present only when there are additions
- `subtraction`: removed lines for that hunk, present only when there are removals

## Step 2: Stage By ID

After you have the IDs you want, pass them to `slice pick`.

File-scoped:

```bash
./slice pick app/models/user.rb 2
./slice pick app/models/user.rb 1 3
```

Repo-wide:

```bash
./slice pick 2
./slice pick 2 5-7
```

If you want to see the exact patch that would be staged without applying it:

```bash
./slice pick app/models/user.rb 2 --print-patch
```

## How IDs Work

File-scoped mode:

```bash
./slice show path/to/file
./slice pick path/to/file 1 3
```

- IDs are local to that file.
- `1` means "first hunk in that file".

Repo-wide mode:

```bash
./slice show
./slice pick 2 5-7
```

- IDs are global across the current unstaged diff.
- `2` means "second hunk in the repo-wide diff order".

IDs are regenerated from the current diff each time you run `show`. After a
successful `pick`, run `show` again before choosing more IDs.

## Common Examples

Stage one hunk from a file with two edits:

```bash
./slice show demo.txt
./slice pick demo.txt 1
git diff --cached -- demo.txt
git diff -- demo.txt
```

Stage across multiple files in one command:

```bash
./slice show
./slice pick 2 4
```

Inspect one repo-wide hunk before staging:

```bash
./slice show 3
./slice pick 3
```

## Advanced: Sub-Hunk Precision

`slice pick` stages whole hunks by ID. When one hunk contains multiple logical
edits and you only want part of it, use the advanced patch flow:

```bash
./slice patch demo.txt > patch.diff
# remove unwanted + or - lines from patch.diff
./slice apply patch.diff
```

Read patch from stdin:

```bash
./slice patch path/to/file | sed '/^+debug/d' | ./slice apply -
```

Use this only when hunk-level selection is too coarse.

## Command Reference

### `slice show [--path <path>] [<path>] [selectors...]`

Show selectable hunks as a flat JSON array with inline diff text.

- With a single-file path and no selectors, returns all hunks for that file.
- With repo-wide selectors, returns only the selected repo-wide hunks.
- With a single-file path and selectors, returns only the selected hunks from that file.

### `slice pick [path] <selectors...>`

Stage the selected hunk IDs.

Examples:

```bash
./slice pick app/models/user.rb 2
./slice pick 2 5-7
./slice pick --path "docs and notes/report.txt" 1
```

### `slice patch [path]`

Print the full unstaged patch for the given path or for the whole repo.

Examples:

```bash
./slice patch
./slice patch app/models/user.rb
./slice patch path/to/file --zero-context
```

### `slice apply <patch-file|->`

Apply an edited patch to the index only.

Examples:

```bash
./slice apply partial.patch
cat partial.patch | ./slice apply -
```

## How It Works

`slice` reads the current unstaged diff, parses it into hunks, assigns IDs,
and stages only the hunks you selected.

For normal `pick` usage, it rebuilds a patch containing only those hunks and
stages it with `git apply --cached`.

For advanced `apply` usage, it applies an edited patch directly to the index
with `git apply --cached`.

It never stages the entire file unless your selected hunks happen to cover the
whole file.

## Git Integration

If `git-slice` is on your `PATH`, Git will automatically expose:

```bash
git slice ...
```

That leaves all other Git commands untouched.

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
