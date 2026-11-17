#!/usr/bin/env bash
# tests/test_restore_drill.sh - verify restore-drill.sh is syntactically valid
# and carries the safety and output patterns it promises.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$SCRIPT_DIR/restore-drill.sh"

echo "== 1. Syntax check (bash -n) =="
bash -n "$TARGET"
echo "PASS: syntax valid"

echo "== 2. Safety patterns =="
grep -q 'set -euo pipefail' "$TARGET" || { echo "FAIL: missing set -euo pipefail"; exit 1; }
grep -q 'REPOS=' "$TARGET" || { echo "FAIL: missing REPOS list"; exit 1; }
grep -q 'TMPDIR=' "$TARGET" || { echo "FAIL: missing TMPDIR"; exit 1; }
echo "PASS: set -euo pipefail, REPOS, TMPDIR present"

echo "== 3. Flags =="
for flag in --keep --quiet --metadata-only --deep --dry-run --max-duration --json; do
  grep -q -e "$flag" "$TARGET" || { echo "FAIL: missing flag $flag"; exit 1; }
done
echo "PASS: all documented flags present"

echo "== 4. Exit codes =="
grep -q 'EXIT=2' "$TARGET" || { echo "FAIL: transport exit code missing"; exit 1; }
grep -q 'EXIT=3' "$TARGET" || { echo "FAIL: integrity exit code missing"; exit 1; }
echo "PASS: distinct exit codes for transport vs integrity failures"

echo "== 5. Verdict + recovery =="
grep -q 'RESTORE DRILL PASSED' "$TARGET" || { echo "FAIL: verdict line missing"; exit 1; }
grep -q 'Recovery checklist' "$TARGET" || { echo "FAIL: recovery instructions missing"; exit 1; }
echo "PASS: verdict banner and recovery instructions present"

echo "ALL TESTS PASSED"
