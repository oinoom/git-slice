# git-slice

`slice` stages selected portions of the current unstaged diff without using
`git add -p`.

Most users and agents only need two commands:

1. `slice list` to see the current changes, their IDs, and the exact diff for each hunk.
2. `slice pick` to stage one or more of those IDs.

Everything else is secondary.

For installation and skill setup, see [install.md](install.md).

## Start Here

Repo-wide flow:

```bash
./slice list --page 1
./slice list --page 2
./slice pick 2 5-7
```

File-scoped flow:

```bash
./slice list app/models/user.rb --page 1
./slice pick app/models/user.rb 2
```

If you want the full JSON for all hunks at once:

```bash
./slice list
```

If you want a raw patch instead of JSON:

```bash
./slice show app/models/user.rb 2
```

## Step 1: List Changes And IDs

Run `slice list` first.

Without a path, it shows all current unstaged changes in the repo:

```bash
./slice list
```

With a path, it shows only that file:

```bash
./slice list app/models/user.rb
```

To walk hunks one page at a time, similar to `git add -p`, use `--page`:

```bash
./slice list --page 1
./slice list --page 2
./slice list app/models/user.rb --page 3
```

`--page` defaults to one hunk per page. Use `--page-size` to group multiple hunks:

```bash
./slice list --page 2 --page-size 3
```

Example output:

```json
{
  "scope": "repo",
  "file_count": 2,
  "hunk_count": 3,
  "page": 1,
  "page_size": 1,
  "returned_hunk_count": 1,
  "total_pages": 3,
  "has_previous_page": false,
  "has_next_page": true,
  "next_page": 2,
  "files": [
    { "path": "first.txt", "hunk_count": 2 },
    { "path": "second.txt", "hunk_count": 1 }
  ],
  "hunks": [
    {
      "id": 1,
      "path": "first.txt",
      "file_hunk_id": 1,
      "old_start": 10,
      "new_start": 10,
      "kind": "mixed",
      "added_lines": 1,
      "removed_lines": 1,
      "summary": "-old value | +new value",
      "diff": "diff --git a/first.txt b/first.txt\nindex 1111111..2222222 100644\n--- a/first.txt\n+++ b/first.txt\n@@ -10 +10 @@\n-old value\n+new value\n"
    }
  ]
}
```

Important fields:

- `id`: the selector you pass to `pick` or `show`
- `path`: the file that owns the hunk
- `file_hunk_id`: the hunk number within that file
- `old_start` / `new_start`: line numbers from the diff header
- `kind`: `mixed`, `addition`, `deletion`, or `context`
- `summary`: a short snippet for quick scanning
- `diff`: the exact patch fragment for that hunk
- `page` / `page_size` / `total_pages`: pagination controls for hunk-by-hunk browsing

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

## Step 3: Preview Specific IDs

Use `slice show` when you want the raw patch for one or more IDs without the
JSON envelope from `list`.

Examples:

```bash
./slice show app/models/user.rb 2
./slice show 3 5-7
./slice show --path "docs and notes/report.txt" 1
```

`--path` is useful when a filename could be confused with numeric selectors.

## How IDs Work

File-scoped mode:

```bash
./slice list path/to/file
./slice pick path/to/file 1 3
```

- IDs are local to that file.
- `1` means "first hunk in that file".

Repo-wide mode:

```bash
./slice list
./slice pick 2 5-7
```

- IDs are global across the current unstaged diff.
- `2` means "second hunk in the repo-wide diff order".

IDs are regenerated from the current diff each time you run `list`. After a
successful `pick`, run `list` again before choosing more IDs.

When using `--page`, the page number is just a way to browse. The actual
selector you pass to `pick` is still the hunk `id`.

## Common Examples

Stage one hunk from a file with two edits:

```bash
./slice list demo.txt
./slice pick demo.txt 1
git diff --cached -- demo.txt
git diff -- demo.txt
```

Stage across multiple files in one command:

```bash
./slice list
./slice pick 2 4
```

Preview a repo-wide hunk before staging:

```bash
./slice list --page 3
./slice pick 3
```

Browse one hunk at a time, `git add -p` style:

```bash
./slice list --page 1
./slice list --page 2
./slice list --page 3
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

### `slice list [--page N] [--page-size N] [path]`

List selectable hunks as JSON, including the exact diff text for each returned
hunk.

- With a path, IDs are local to that file.
- Without a path, IDs are global across the current unstaged diff for the repo.
- `--page` returns one page of hunks and defaults to one hunk per page.
- `--page-size` returns multiple hunks per page.

### `slice pick [path] <selectors...>`

Stage the selected hunk IDs.

Examples:

```bash
./slice pick app/models/user.rb 2
./slice pick 2 5-7
./slice pick --path "docs and notes/report.txt" 1
```

### `slice show [--path <path>] <selectors...>`

Print the exact patch for selected hunk IDs without staging them.

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
git slice list
git slice pick 1 3
git status
```

## Skill

A repo-contained skill lives at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).

It teaches an agent when to use `git slice`, how to choose between file-scoped
and repo-wide selection, and when to fall back to `patch` + `apply`.

Codex install:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s "/Users/davidanekstein/NTL/ai-partial-stage/skills/git-slice" "${CODEX_HOME:-$HOME/.codex}/skills/git-slice"
```

If your Claude setup supports `SKILL.md`-based skills, point it at the same
folder or symlink/copy that folder into its skills directory.
