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

  "$TOOL" show demo.txt > hunks.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("hunks.json").read_text())
assert isinstance(payload, list), payload
assert len(payload) == 2, payload
assert payload[0]["kind"] == "mixed", payload
assert "@@ -2 +2 @@" in payload[0]["diff"], payload
assert payload[0]["subtraction"] == "-beta\n", payload
assert payload[0]["addition"] == "+BETA\n", payload
PY

  "$TOOL" pick demo.txt 1
  git diff --cached -- demo.txt > staged.diff
  git diff -- demo.txt > unstaged.diff

  grep -q '+BETA' staged.diff
  grep -q -- '-beta' staged.diff
  grep -q '+DELTA' unstaged.diff
  grep -q -- '-delta' unstaged.diff
}

case_repo_wide_show_and_pick() {
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

  "$TOOL" show > repo.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("repo.json").read_text())
assert isinstance(payload, list), payload
assert len(payload) == 3, payload
assert payload[0]["path"] == "first.txt", payload
assert payload[2]["path"] == "second.txt", payload
assert "diff --git a/first.txt b/first.txt" in payload[0]["diff"], payload
assert "@@ -1 +1 @@" in payload[0]["diff"], payload
assert payload[0]["subtraction"] == "-first\n", payload
assert payload[0]["addition"] == "+FIRST\n", payload
PY

  "$TOOL" show 2 3 > selected.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("selected.json").read_text())
assert len(payload) == 2, payload
assert payload[0]["id"] == 2, payload
assert payload[1]["id"] == 3, payload
assert "+TAIL\n" in payload[0]["addition"], payload
assert "+GREEN\n" in payload[1]["addition"], payload
PY

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

  "$TOOL" show demo.txt 2 > selected.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("selected.json").read_text())
assert len(payload) == 1, payload
assert payload[0]["id"] == 2, payload
assert payload[0]["addition"] == "+THREE\n", payload
assert payload[0]["subtraction"] == "-three\n", payload
PY
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

  "$TOOL" show big.txt > big.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("big.json").read_text())
assert len(payload) == 4, payload
assert payload[1]["old_start"] == 200, payload
assert payload[3]["old_start"] == 750, payload
PY

  "$TOOL" pick big.txt 2 4
  git diff --cached -- big.txt > staged.diff
  git diff -- big.txt > unstaged.diff
  grep -q '+changed 0200' staged.diff
  grep -q '+changed 0750' staged.diff
  grep -q '+changed 0010' unstaged.diff
  grep -q '+changed 0500' unstaged.diff
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
  "$TOOL" show spread.txt > relisted.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("relisted.json").read_text())
assert len(payload) == 2, payload
assert payload[0]["old_start"] == 8, payload
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

  if "$TOOL" show clean.txt >out 2>err; then
    echo "expected no-changes failure" >&2
    return 1
  fi
  grep -q 'No unstaged changes' err
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

  "$TOOL" show shape.txt > shape.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("shape.json").read_text())
assert len(payload) >= 1, payload
assert "addition" in payload[0] or "subtraction" in payload[0], payload
PY

  "$TOOL" patch shape.txt --zero-context > shape.patch
  git apply --cached --check --recount --unidiff-zero shape.patch
}

case_addition_only_pick_keeps_location() {
  repo=$(make_repo)
  cd "$repo"
  seq 1 10 > demo.txt
  git add demo.txt
  git commit -q -m "initial"

  python3 - <<'PY'
from pathlib import Path

lines = Path("demo.txt").read_text().splitlines()
lines.insert(5, "INSERTED")
Path("demo.txt").write_text("\n".join(lines) + "\n")
PY

  "$TOOL" show demo.txt > addition.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("addition.json").read_text())
assert len(payload) == 1, payload
assert payload[0]["kind"] == "addition", payload
assert payload[0]["old_count"] == 0, payload
PY

  "$TOOL" pick demo.txt 1
  git show :demo.txt > staged.txt
  python3 - <<'PY'
from pathlib import Path

lines = Path("staged.txt").read_text().splitlines()
assert lines[5] == "INSERTED", lines
PY

  if git diff --quiet -- demo.txt; then
    :
  else
    echo "expected insertion to be fully staged" >&2
    return 1
  fi
}

case_later_addition_hunk_keeps_location() {
  repo=$(make_repo)
  cd "$repo"
  cat > demo.py <<'EOF'
def main():
    files = [
        "data.h",
        "lib.c",
        "log.c",
        "obu.c",
    ]

    shutil.copy(
        src,
        dst,
    )
EOF
  git add demo.py
  git commit -q -m "initial"

  python3 - <<'PY'
from pathlib import Path

path = Path("demo.py")
text = path.read_text()
text = text.replace('        "log.c",\n', '        "log.c",\n        "mem.c",\n', 1)
text = text.replace(
    '\n    shutil.copy(\n',
    '\n        callgate_wrapper_c = Path("callgate_wrapper.c")\n'
    '        callgate_text = callgate_wrapper_c.read_text()\n'
    '\n'
    '    shutil.copy(\n',
    1,
)
path.write_text(text)
PY

  "$TOOL" show demo.py > later.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("later.json").read_text())
assert len(payload) == 2, payload
assert payload[1]["kind"] == "addition", payload
assert payload[1]["old_count"] == 0, payload
PY

  "$TOOL" pick demo.py 2
  git show :demo.py > staged.py
  python3 - <<'PY'
from pathlib import Path

lines = Path("staged.py").read_text().splitlines()
call_idx = lines.index('        callgate_wrapper_c = Path("callgate_wrapper.c")')
copy_idx = lines.index("    shutil.copy(")
assert call_idx < copy_idx, lines
PY

  if grep -q '"mem.c"' staged.py; then
    echo "unexpected earlier hunk staged" >&2
    return 1
  fi
  git diff -- demo.py > unstaged.diff
  grep -q '"mem.c"' unstaged.diff
}

case_optional_addition_and_subtraction_fields() {
  repo=$(make_repo)
  cd "$repo"
  cat > add.txt <<'EOF'
one
EOF
  cat > del.txt <<'EOF'
alpha
beta
EOF
  git add add.txt del.txt
  git commit -q -m "initial"

  cat > add.txt <<'EOF'
one
two
EOF
  cat > del.txt <<'EOF'
alpha
EOF

  "$TOOL" show > optional.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("optional.json").read_text())
assert len(payload) == 2, payload
by_path = {entry["path"]: entry for entry in payload}
assert by_path["add.txt"]["addition"] == "+two\n", by_path
assert "subtraction" not in by_path["add.txt"], by_path
assert by_path["del.txt"]["subtraction"] == "-beta\n", by_path
assert "addition" not in by_path["del.txt"], by_path
PY
}

case_line_level_selection_and_stable_ids() {
  repo=$(make_repo)
  cd "$repo"
  cat > stable.txt <<'EOF'
alpha
beta
gamma
delta
epsilon
zeta
eta
theta
EOF
  git add stable.txt
  git commit -q -m "initial"

  cat > stable.txt <<'EOF'
ALPHA
BETA
gamma
delta
epsilon
zeta
eta
THETA
EOF

  "$TOOL" show stable.txt > before.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("before.json").read_text())
assert len(payload) == 2, payload
assert payload[0]["stable_id"].startswith("h_"), payload
assert payload[0]["lines"][0]["stable_id"].startswith("c_"), payload
assert payload[0]["lines"][0]["id"] == "1.1", payload
assert payload[0]["lines"][1]["id"] == "1.2", payload
Path("line_selector.txt").write_text(payload[0]["lines"][1]["stable_id"])
Path("later_hunk.txt").write_text(payload[1]["stable_id"])
PY

  line_selector=$(cat line_selector.txt)
  later_hunk=$(cat later_hunk.txt)

  "$TOOL" show stable.txt "$later_hunk" > selected.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("selected.json").read_text())
selector = Path("later_hunk.txt").read_text()
assert len(payload) == 1, payload
assert payload[0]["stable_id"] == selector, payload
PY

  "$TOOL" pick stable.txt "$line_selector"
  git diff --cached -- stable.txt > staged.diff
  git diff -- stable.txt > unstaged.diff
  grep -q '+BETA' staged.diff
  if grep -q '+ALPHA' staged.diff; then
    echo "unexpected staged ALPHA change" >&2
    return 1
  fi
  grep -q '+ALPHA' unstaged.diff
  grep -q '+THETA' unstaged.diff

  "$TOOL" show stable.txt > after.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("after.json").read_text())
later_hunk = Path("later_hunk.txt").read_text()
assert any(entry["stable_id"] == later_hunk for entry in payload), payload
PY
}

case_show_staged_and_line_level_unstage() {
  repo=$(make_repo)
  cd "$repo"
  cat > staged.txt <<'EOF'
alpha
beta
gamma
EOF
  git add staged.txt
  git commit -q -m "initial"

  cat > staged.txt <<'EOF'
ALPHA
BETA
gamma
EOF

  "$TOOL" pick staged.txt 1
  "$TOOL" show --staged staged.txt > staged.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("staged.json").read_text())
assert len(payload) == 1, payload
assert len(payload[0]["lines"]) == 2, payload
Path("unstage_selector.txt").write_text(payload[0]["lines"][0]["stable_id"])
PY

  unstage_selector=$(cat unstage_selector.txt)
  "$TOOL" unstage staged.txt "$unstage_selector"
  git diff --cached -- staged.txt > staged.diff
  git diff -- staged.txt > unstaged.diff
  grep -q '+BETA' staged.diff
  if grep -q '+ALPHA' staged.diff; then
    echo "unexpected staged ALPHA change after unstage" >&2
    return 1
  fi
  grep -q '+ALPHA' unstaged.diff
  if grep -q '+BETA' unstaged.diff; then
    echo "unexpected unstaged BETA change after unstage" >&2
    return 1
  fi
}

case_binary_unsupported_reporting() {
  repo=$(make_repo)
  cd "$repo"
  python3 - <<'PY'
from pathlib import Path

Path("image.bin").write_bytes(b"\x00\x01\x02\x03")
PY
  git add image.bin
  git commit -q -m "initial"

  python3 - <<'PY'
from pathlib import Path

Path("image.bin").write_bytes(b"\x10\x11\x12\x13")
PY

  if "$TOOL" show image.bin >out 2>err; then
    echo "expected binary unsupported failure" >&2
    return 1
  fi
  grep -q 'binary file: image.bin' err
}

case_supported_and_unsupported_mix() {
  repo=$(make_repo)
  cd "$repo"
  cat > notes.txt <<'EOF'
red
green
blue
EOF
  python3 - <<'PY'
from pathlib import Path

Path("image.bin").write_bytes(b"\x00\x01\x02\x03")
PY
  git add notes.txt image.bin
  git commit -q -m "initial"

  cat > notes.txt <<'EOF'
red
GREEN
blue
EOF
  python3 - <<'PY'
from pathlib import Path

Path("image.bin").write_bytes(b"\x10\x11\x12\x13")
PY

  "$TOOL" show > mixed.json 2>err
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("mixed.json").read_text())
assert len(payload) == 1, payload
assert payload[0]["path"] == "notes.txt", payload
PY
  grep -q 'Ignored unsupported unstaged changes: binary file: image.bin' err
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

  PATH="$GIT_SLICE_PATH:$PATH" git slice show > subcmd.json
  python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("subcmd.json").read_text())
assert len(payload) == 1, payload
assert payload[0]["subtraction"] == "-green\n", payload
assert payload[0]["addition"] == "+GREEN\n", payload
assert "-green\n+GREEN\n" in payload[0]["diff"], payload
PY

  PATH="$GIT_SLICE_PATH:$PATH" git slice pick 1
  git diff --cached -- subcmd.txt > staged.diff
  grep -q '+GREEN' staged.diff

  # Verify that non-slice commands still resolve to regular Git behavior.
  PATH="$GIT_SLICE_PATH:$PATH" git status --short > status.txt
  grep -q '^M  subcmd.txt' status.txt
}

case_basic_pick
case_repo_wide_show_and_pick
case_show_and_pick
case_large_sparse_file
case_incremental_relist
case_patch_edit_single_hunk
case_repo_wide_patch
case_patch_apply_from_stdin
case_path_with_spaces
case_invalid_selector
case_no_changes
case_additions_and_deletions
case_addition_only_pick_keeps_location
case_later_addition_hunk_keeps_location
case_optional_addition_and_subtraction_fields
case_line_level_selection_and_stable_ids
case_show_staged_and_line_level_unstage
case_binary_unsupported_reporting
case_supported_and_unsupported_mix
case_git_subcommand_integration

echo "ok"
