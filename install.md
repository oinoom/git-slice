# Install

## CLI

Clone the repo and put the repo directory on your `PATH` so Git can find the
`git-slice` wrapper:

```bash
git clone git@github.com:oinoom/git-slice.git
cd git-slice
export PATH="$PWD:$PATH"
```

After that, these should work:

```bash
git slice list
git slice pick 1
```

If you want the `PATH` change to persist, add it to your shell profile.

## Skill

The repo-contained skill is at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).

For Codex, one direct install path is:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s "$PWD/skills/git-slice" "${CODEX_HOME:-$HOME/.codex}/skills/git-slice"
```

After that, the agent can use the local `git slice` interface:

```bash
git slice list --page 1
git slice pick 2
```

## What To Tell The Agent

Use this exact instruction if you want something short:

```text
Install and use [$git-slice](skills/git-slice/SKILL.md).
```

Once installed, the normal agent loop is:

1. `git slice list --page N` to inspect exact hunk diffs one page at a time
2. `git slice list` to inspect the full JSON payload when needed
3. `git slice pick ...` to stage selected IDs
4. `git slice list` again before making another selection
