#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TOOL="$ROOT_DIR/slice"
GIT_SLICE_PATH="$ROOT_DIR"
ROOT_TMP=$(mktemp -d /tmp/slice-test.XXXXXX)
trap 'rm -rf "$ROOT_TMP"' EXIT

make_repo() {
  repo=$(mktemp -d "$ROOT_TMP/repo.XXXXXX")
  cd "$repo"
  git init -q
  git config user.name test
  git config user.email test@example.com
  printf '%s\n' "$repo"
}

case_basic_pick() {
  repo=$(make_repo)
  cd "$repo"
  cat > demo.txt <<'EOF'
alpha
beta
gamma
delta
EOF
  git add demo.txt
  git commit -q -m "initial"

  cat > demo.txt <<'EOF'
alpha
BETA
gamma
DELTA
EOF

  "$TOOL" list demo.txt > hunks.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("hunks.json").read_text())
assert payload["hunk_count"] == 2, payload
assert payload["hunks"][0]["kind"] == "mixed", payload
assert "@@ -2 +2 @@" in payload["hunks"][0]["diff"], payload
assert "-beta\n+BETA\n" in payload["hunks"][0]["diff"], payload
PY

  "$TOOL" pick demo.txt 1
  git diff --cached -- demo.txt > staged.diff
  git diff -- demo.txt > unstaged.diff

  grep -q '+BETA' staged.diff
  grep -q -- '-beta' staged.diff
  grep -q '+DELTA' unstaged.diff
  grep -q -- '-delta' unstaged.diff
}

case_repo_wide_list_and_pick() {
  repo=$(make_repo)
  cd "$repo"
  cat > first.txt <<'EOF'
first
keep
tail
EOF
  cat > second.txt <<'EOF'
red
green
blue
EOF
  git add first.txt second.txt
  git commit -q -m "initial"

  cat > first.txt <<'EOF'
FIRST
keep
TAIL
EOF
  cat > second.txt <<'EOF'
red
GREEN
blue
EOF

  "$TOOL" list > repo.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("repo.json").read_text())
assert payload["scope"] == "repo", payload
assert payload["file_count"] == 2, payload
assert payload["hunk_count"] == 3, payload
assert payload["hunks"][0]["path"] == "first.txt", payload
assert payload["hunks"][2]["path"] == "second.txt", payload
assert "diff --git a/first.txt b/first.txt" in payload["hunks"][0]["diff"], payload
assert "@@ -1 +1 @@" in payload["hunks"][0]["diff"], payload
PY

  "$TOOL" show 2 3 > selected.patch
  grep -q '+TAIL' selected.patch
  grep -q '+GREEN' selected.patch

  "$TOOL" pick 2 3
  git diff --cached -- first.txt second.txt > staged.diff
  git diff -- first.txt second.txt > unstaged.diff
  grep -q '+TAIL' staged.diff
  grep -q '+GREEN' staged.diff
  grep -q '+FIRST' unstaged.diff
}

case_show_and_pick() {
  repo=$(make_repo)
  cd "$repo"
  cat > demo.txt <<'EOF'
one
two
three
four
EOF
  git add demo.txt
  git commit -q -m "initial"

  cat > demo.txt <<'EOF'
ONE
two
THREE
four
EOF

  "$TOOL" show demo.txt 2 > selected.patch
  grep -q '+THREE' selected.patch
  "$TOOL" pick demo.txt 2
  git diff --cached -- demo.txt > staged.diff
  grep -q '+THREE' staged.diff
}

case_large_sparse_file() {
  repo=$(make_repo)
  cd "$repo"
  python3 - <<'PY'
from pathlib import Path

Path("big.txt").write_text("".join(f"line {i:04d}\n" for i in range(1, 801)))
PY
  git add big.txt
  git commit -q -m "initial"

  python3 - <<'PY'
from pathlib import Path

lines = [f"line {i:04d}\n" for i in range(1, 801)]
for idx in (9, 199, 499, 749):
    lines[idx] = f"changed {idx + 1:04d}\n"
Path("big.txt").write_text("".join(lines))
PY

  "$TOOL" list big.txt > big.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("big.json").read_text())
assert payload["hunk_count"] == 4, payload
assert payload["hunks"][1]["old_start"] == 200, payload
assert payload["hunks"][3]["old_start"] == 750, payload
PY

  "$TOOL" pick big.txt 2 4
  git diff --cached -- big.txt > staged.diff
  git diff -- big.txt > unstaged.diff
  grep -q '+changed 0200' staged.diff
  grep -q '+changed 0750' staged.diff
  grep -q '+changed 0010' unstaged.diff
  grep -q '+changed 0500' unstaged.diff
}

case_paginated_list() {
  repo=$(make_repo)
  cd "$repo"
  cat > page.txt <<'EOF'
one
two
three
four
five
six
EOF
  git add page.txt
  git commit -q -m "initial"

  cat > page.txt <<'EOF'
ONE
two
THREE
four
FIVE
six
EOF

  "$TOOL" list page.txt --page 2 > page2.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("page2.json").read_text())
assert payload["scope"] == "file", payload
assert payload["hunk_count"] == 3, payload
assert payload["page"] == 2, payload
assert payload["page_size"] == 1, payload
assert payload["total_pages"] == 3, payload
assert payload["has_previous_page"] is True, payload
assert payload["has_next_page"] is True, payload
assert payload["previous_page"] == 1, payload
assert payload["next_page"] == 3, payload
assert payload["returned_hunk_count"] == 1, payload
assert len(payload["hunks"]) == 1, payload
assert payload["hunks"][0]["id"] == 2, payload
assert "-three\n+THREE\n" in payload["hunks"][0]["diff"], payload
PY

  "$TOOL" list --page-size 2 --page 2 > repo-page.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("repo-page.json").read_text())
assert payload["scope"] == "repo", payload
assert payload["page"] == 2, payload
assert payload["page_size"] == 2, payload
assert payload["returned_hunk_count"] == 1, payload
assert payload["hunks"][0]["id"] == 3, payload
assert payload["hunks"][0]["path"] == "page.txt", payload
assert "-five\n+FIVE\n" in payload["hunks"][0]["diff"], payload
PY
}

case_incremental_relist() {
  repo=$(make_repo)
  cd "$repo"
  python3 - <<'PY'
from pathlib import Path

Path("spread.txt").write_text("".join(f"slot {i}\n" for i in range(1, 16)))
PY
  git add spread.txt
  git commit -q -m "initial"

  python3 - <<'PY'
from pathlib import Path

lines = [f"slot {i}\n" for i in range(1, 16)]
lines[1] = "slot 2 changed\n"
lines[7] = "slot 8 changed\n"
lines[13] = "slot 14 changed\n"
Path("spread.txt").write_text("".join(lines))
PY

  "$TOOL" pick spread.txt 1
  "$TOOL" list spread.txt > relisted.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("relisted.json").read_text())
assert payload["hunk_count"] == 2, payload
assert payload["hunks"][0]["old_start"] == 8, payload
PY

  "$TOOL" pick spread.txt 2
  git diff --cached -- spread.txt > staged.diff
  grep -q '+slot 2 changed' staged.diff
  grep -q '+slot 14 changed' staged.diff
  git diff -- spread.txt > unstaged.diff
  grep -q '+slot 8 changed' unstaged.diff
}

case_patch_edit_single_hunk() {
  repo=$(make_repo)
  cd "$repo"
  cat > demo.txt <<'EOF'
one
two
three
EOF
  git add demo.txt
  git commit -q -m "initial"

  cat > demo.txt <<'EOF'
one
TWO
three
FOUR
EOF

  "$TOOL" patch demo.txt > patch.diff
  python3 - <<'PY'
from pathlib import Path

patch = Path("patch.diff").read_text()
patch = patch.replace("+FOUR\n", "", 1)
Path("edited.patch").write_text(patch)
PY

  "$TOOL" apply edited.patch
  git diff --cached -- demo.txt > staged-edit.diff
  git diff -- demo.txt > unstaged-edit.diff
  grep -q '+TWO' staged-edit.diff
  grep -q -- '-two' staged-edit.diff
  grep -q '+FOUR' unstaged-edit.diff
}

case_repo_wide_patch() {
  repo=$(make_repo)
  cd "$repo"
  cat > one.txt <<'EOF'
one
two
EOF
  cat > two.txt <<'EOF'
alpha
beta
EOF
  git add one.txt two.txt
  git commit -q -m "initial"

  cat > one.txt <<'EOF'
ONE
two
EOF
  cat > two.txt <<'EOF'
alpha
BETA
EOF

  "$TOOL" patch > all.patch
  grep -q 'diff --git a/one.txt b/one.txt' all.patch
  grep -q 'diff --git a/two.txt b/two.txt' all.patch
}

case_patch_apply_from_stdin() {
  repo=$(make_repo)
  cd "$repo"
  cat > stdin.txt <<'EOF'
a
b
c
EOF
  git add stdin.txt
  git commit -q -m "initial"

  cat > stdin.txt <<'EOF'
a
B
c
D
EOF

  "$TOOL" patch stdin.txt > full.patch
  python3 - <<'PY'
from pathlib import Path

patch = Path("full.patch").read_text()
patch = patch.replace("+D\n", "", 1)
Path("stdin.patch").write_text(patch)
PY

  cat stdin.patch | "$TOOL" apply -
  git diff --cached -- stdin.txt > staged.diff
  git diff -- stdin.txt > unstaged.diff
  grep -q '+B' staged.diff
  grep -q '+D' unstaged.diff
}

case_path_with_spaces() {
  repo=$(make_repo)
  cd "$repo"
  mkdir -p "docs and notes"
  cat > "docs and notes/report draft.txt" <<'EOF'
first
second
third
EOF
  git add "docs and notes/report draft.txt"
  git commit -q -m "initial"

  cat > "docs and notes/report draft.txt" <<'EOF'
first
SECOND
third
EOF

  "$TOOL" pick "docs and notes/report draft.txt" 1
  git diff --cached -- "docs and notes/report draft.txt" > staged.diff
  grep -q '+SECOND' staged.diff
}

case_invalid_selector() {
  repo=$(make_repo)
  cd "$repo"
  cat > invalid.txt <<'EOF'
x
y
EOF
  git add invalid.txt
  git commit -q -m "initial"

  cat > invalid.txt <<'EOF'
X
y
EOF

  if "$TOOL" pick invalid.txt 2 >out 2>err; then
    echo "expected invalid selector failure" >&2
    return 1
  fi
  grep -q 'Invalid hunk id' err
}

case_no_changes() {
  repo=$(make_repo)
  cd "$repo"
  cat > clean.txt <<'EOF'
same
EOF
  git add clean.txt
  git commit -q -m "initial"

  if "$TOOL" list clean.txt >out 2>err; then
    echo "expected no-changes failure" >&2
    return 1
  fi
  grep -q 'No unstaged changes' err
}

case_invalid_page() {
  repo=$(make_repo)
  cd "$repo"
  cat > page.txt <<'EOF'
start
middle
end
EOF
  git add page.txt
  git commit -q -m "initial"

  cat > page.txt <<'EOF'
START
middle
end
EOF

  if "$TOOL" list page.txt --page 2 >out 2>err; then
    echo "expected invalid page failure" >&2
    return 1
  fi
  grep -q 'Invalid page: 2' err
}

case_additions_and_deletions() {
  repo=$(make_repo)
  cd "$repo"
  cat > shape.txt <<'EOF'
top
remove-me
middle
tail
EOF
  git add shape.txt
  git commit -q -m "initial"

  cat > shape.txt <<'EOF'
INTRO
top
middle
tail
EOF

  "$TOOL" list shape.txt > shape.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("shape.json").read_text())
assert payload["hunk_count"] >= 1, payload
PY

  "$TOOL" patch shape.txt --zero-context > shape.patch
  git apply --cached --check --recount --unidiff-zero shape.patch
}

case_git_subcommand_integration() {
  repo=$(make_repo)
  cd "$repo"
  cat > subcmd.txt <<'EOF'
red
green
blue
EOF
  git add subcmd.txt
  git commit -q -m "initial"

  cat > subcmd.txt <<'EOF'
red
GREEN
blue
EOF

  PATH="$GIT_SLICE_PATH:$PATH" git slice list > subcmd.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("subcmd.json").read_text())
assert payload["hunk_count"] == 1, payload
assert payload["hunks"][0]["summary"] == "-green | +GREEN", payload
assert "-green\n+GREEN\n" in payload["hunks"][0]["diff"], payload
PY

  PATH="$GIT_SLICE_PATH:$PATH" git slice pick 1
  git diff --cached -- subcmd.txt > staged.diff
  grep -q '+GREEN' staged.diff

  # Verify that non-slice commands still resolve to regular Git behavior.
  PATH="$GIT_SLICE_PATH:$PATH" git status --short > status.txt
  grep -q '^M  subcmd.txt' status.txt
}

case_basic_pick
case_repo_wide_list_and_pick
case_show_and_pick
case_large_sparse_file
case_paginated_list
case_incremental_relist
case_patch_edit_single_hunk
case_repo_wide_patch
case_patch_apply_from_stdin
case_path_with_spaces
case_invalid_selector
case_no_changes
case_invalid_page
case_additions_and_deletions
case_git_subcommand_integration

echo "ok"
