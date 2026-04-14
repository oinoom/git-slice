# ai-partial-stage

`slice` stages selected portions of the current unstaged diff without using
`git add -p`.

It gives an agent two stable interfaces:

1. Structured hunk selection:

```bash
./slice list path/to/file
./slice show path/to/file 1 3
./slice pick path/to/file 1,3
```

2. Patch editing for sub-hunk precision:

```bash
./slice patch path/to/file > partial.patch
# edit the patch
./slice apply partial.patch
```

## How It Works

`slice` reads the current unstaged diff, parses it into hunks, assigns hunk
IDs, and then either:

- rebuilds a patch containing only the selected hunks and stages it with
  `git apply --cached`, or
- applies an edited patch directly to the index with `git apply --cached`

It never stages the entire file unless the selected hunks happen to cover the
whole file.

## Quick Start

File-scoped flow:

```bash
./slice list app/models/user.rb
./slice show app/models/user.rb 2
./slice pick app/models/user.rb 2
```

Repo-wide flow:

```bash
./slice list
./slice show 2 5-7
./slice pick 2 5-7
```

Patch-edit flow:

```bash
./slice patch app/models/user.rb > partial.patch
# remove the lines you do not want to stage
./slice apply partial.patch
```

Read patch from stdin:

```bash
./slice patch path/to/file | sed '/^+debug/d' | ./slice apply -
```

## Commands

### `slice list [path]`

List selectable hunks as JSON.

With a path, IDs are local to that file.

Without a path, IDs are global across the current unstaged diff for the repo.

Example:

```bash
./slice list
```

Example output:

```json
{
  "scope": "repo",
  "file_count": 2,
  "hunk_count": 3,
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
      "summary": "-old value | +new value"
    }
  ]
}
```

Fields:

- `id`: selector for `show` and `pick`
- `path`: file that owns the hunk
- `file_hunk_id`: hunk number within that file
- `old_start` / `new_start`: line numbers from the diff header
- `kind`: `mixed`, `addition`, `deletion`, or `context`
- `summary`: short scan-friendly snippet for agent decisions

### `slice show [--path <path>] <selectors...>`

Print the exact patch for selected hunk IDs without staging them.

Examples:

```bash
./slice show app/models/user.rb 2
./slice show 3 5-7
./slice show --path "docs and notes/report.txt" 1
```

`--path` is useful when a filename could be confused with numeric selectors.

### `slice pick [--path <path>] <selectors...>`

Stage the selected hunk IDs.

Examples:

```bash
./slice pick app/models/user.rb 2
./slice pick 2 5-7
./slice pick --path "docs and notes/report.txt" 1
```

You can preview what would be staged without applying it:

```bash
./slice pick app/models/user.rb 2 --print-patch
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

## Selection Rules

File-scoped mode:

```bash
./slice list path/to/file
./slice pick path/to/file 1 3
```

- hunk IDs are local to that file
- `1` means “first hunk in that file”

Repo-wide mode:

```bash
./slice list
./slice pick 2 5-7
```

- hunk IDs are global across the entire current unstaged diff
- `2` means “second hunk in the repo-wide diff order”

Important: hunk IDs are regenerated from the current diff each time you run
`list`. After a successful `pick`, run `list` again before choosing more IDs.

## When To Use `pick` vs `apply`

Use `pick` when:

- whole hunks map cleanly to the change you want
- the agent can choose by hunk summary and line range alone

Use `patch` + `apply` when:

- the hunk contains multiple logical edits
- the agent needs sub-hunk precision
- the agent wants to remove individual added lines before staging

## End-to-End Examples

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

Stage only part of a single hunk:

```bash
./slice patch demo.txt > patch.diff
# remove unwanted + lines from patch.diff
./slice apply patch.diff
```

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

A repo-contained skill lives at [skills/git-slice](/Users/davidanekstein/NTL/ai-partial-stage/skills/git-slice).

It teaches an agent when to use `git slice`, how to choose between file-scoped
and repo-wide selection, and when to fall back to `patch` + `apply`.

Codex install:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s "/Users/davidanekstein/NTL/ai-partial-stage/skills/git-slice" "${CODEX_HOME:-$HOME/.codex}/skills/git-slice"
```

If your Claude setup supports `SKILL.md`-based skills, point it at the same
folder or symlink/copy that folder into its skills directory.
