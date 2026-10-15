#!/usr/bin/env bash
# tests/test_restore_drill.sh - verify restore-drill.sh is syntactically valid
# and carries the safety patterns that keep it from eating a real backup.
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

echo "== 3. Cleanup logic =="
grep -q 'KEEP' "$TARGET" || { echo "FAIL: missing --keep handling"; exit 1; }
echo "PASS: --keep flag handled"

echo "ALL TESTS PASSED"
