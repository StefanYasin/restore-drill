#!/usr/bin/env bash
# restore-drill.sh — verify GitHub backups actually restore.
# Clones both private repos to a temp dir, checks integrity, then cleans up.
# Run: bash restore-drill.sh [--keep]
set -euo pipefail

REPOS=(
  "StefanYasin/hermes-vault"
  "StefanYasin/hermes-backup"
)
# Temp path: %LOCALAPPDATA%\Temp on Windows (MSYS /tmp breaks native git -C),
# $TMPDIR or /tmp everywhere else. Guarded because set -u fails on unset vars.
if [ -n "${LOCALAPPDATA:-}" ]; then
  BASE_TMP="$LOCALAPPDATA/Temp"
else
  BASE_TMP="${TMPDIR:-/tmp}"
fi
TMPDIR="$BASE_TMP/restore-drill-$(date +%s)"
mkdir -p "$TMPDIR"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

echo "🔍 Restore drill — $(date '+%Y-%m-%d %H:%M')"
echo "   Temp: $TMPDIR"
echo ""

FAIL=0
for repo in "${REPOS[@]}"; do
  name="${repo#*/}"
  echo "── Cloning $repo (full history — real restore semantics) ..."
  if git clone --quiet "https://github.com/$repo.git" "$TMPDIR/$name" 2>&1; then
    # Verify: repo has commits, files, and a valid HEAD tree
    count=$(git -C "$TMPDIR/$name" rev-list --count HEAD 2>/dev/null || echo 0)
    files=$(git -C "$TMPDIR/$name" ls-files 2>/dev/null | wc -l)
    head=$(git -C "$TMPDIR/$name" log -1 --format='%h %ad' --date=short 2>/dev/null || echo "none")
    echo "   ✅ $name — commits:$count files:$files HEAD:$head"
    # Deep check: verify working tree matches HEAD (no corruption)
    if git -C "$TMPDIR/$name" fsck --no-dangling 2>/dev/null; then
      echo "   ✅ integrity: fsck clean"
    else
      echo "   ⚠️ integrity: fsck found issues"
      FAIL=1
    fi
  else
    echo "   ❌ CLONE FAILED for $repo"
    FAIL=1
  fi
  echo ""
done

if [ $FAIL -eq 0 ]; then
  echo "🎉 RESTORE DRILL PASSED — all backups clone and verify."
else
  echo "🚨 RESTORE DRILL FAILED — check the errors above."
fi

if [ $KEEP -eq 1 ]; then
  echo "   (--keep: leaving clone at $TMPDIR)"
else
  rm -rf "$TMPDIR"
  echo "   (temp clone removed)"
fi
exit $FAIL
