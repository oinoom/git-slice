# Install

## CLI

Git discovers external subcommands by looking for executables named `git-*` on
your `PATH`. This repo ships `git-slice`, so the setup is simply: clone the
repo and put the repo directory on your `PATH`.

```bash
git clone git@github.com:oinoom/git-slice.git
cd git-slice
export PATH="$PWD:$PATH"
```

After that, these should work:

```bash
git slice show
git slice pick 1
git slice show --staged
git slice unstage 1
```

If you want the `PATH` change to persist, add it to your shell profile.

## Skill

The repo-contained skill is at [skills/git-slice](skills/git-slice).

If you want an agent to use it, tell the agent to install
[$git-slice](skills/git-slice/SKILL.md).

## What To Tell The Agent

Use this exact instruction if you want something short:

```text
Install and use [$git-slice](skills/git-slice/SKILL.md).
```

Once installed, the usual agent flow is:

1. `git slice show` or `git slice show --path <file>` to inspect the JSON list
   of hunks
2. choose a hunk id, line id like `1.2`, or stable id like `h_...` / `c_...`
3. `git slice pick ...` to stage exactly those selections
4. `git slice show --staged` and `git slice unstage ...` if part of the staged
   selection should be removed from the index
5. re-run `git slice show` only if the agent is continuing to split the
   remaining unstaged diff

Use `--path` as the canonical file-scoping form:

```bash
git slice show --path app/models/user.rb
git slice pick --path app/models/user.rb 1.2
git slice show --staged --path app/models/user.rb
git slice unstage --path app/models/user.rb 1
```

Positional path syntax still works, but the `--path` form is the recommended
one for new usage.
