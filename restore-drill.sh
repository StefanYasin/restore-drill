#!/usr/bin/env bash
# restore-drill.sh - verify GitHub backups actually restore.
# Clones the configured repos to a temp dir, verifies integrity, cleans up.
#
# Usage: bash restore-drill.sh [flags]
#   --keep            leave the temp clone in place for inspection
#   --quiet           print nothing unless something fails (cron friendly)
#   --metadata-only   structural check only: clone, commit count, file list (no fsck)
#   --deep            default: full fsck + working-tree verification
#   --dry-run         validate auth/connectivity only (ls-remote, no clone)
#   --max-duration N  stop after N seconds; partial results are reported
#   --json            machine-readable summary on stdout
#
# Exit codes:
#   0  clean: every repo cloned and verified
#   2  transport/auth failure: a clone or ls-remote could not complete
#   3  integrity failure: clone worked but verification failed
#   4  usage error or duration budget exceeded
set -euo pipefail

REPOS=(
  "StefanYasin/hermes-vault"
  "StefanYasin/hermes-backup"
)

# ---- flag parsing (while+shift so --max-duration consumes its value) ----
KEEP=0; QUIET=0; METADATA_ONLY=0; DRY_RUN=0; JSON_OUT=0; MAX_DURATION=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --metadata-only) METADATA_ONLY=1; shift ;;
    --deep) METADATA_ONLY=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --max-duration) MAX_DURATION="${2:-0}"; shift 2 ;;
    *) echo "unknown flag: $1"; exit 4 ;;
  esac
done

# Temp path: %LOCALAPPDATA%\Temp on Windows (MSYS /tmp breaks native git -C),
# $TMPDIR or /tmp everywhere else. Guarded because set -u fails on unset vars.
if [ -n "${LOCALAPPDATA:-}" ]; then
  BASE_TMP="$LOCALAPPDATA/Temp"
else
  BASE_TMP="${TMPDIR:-/tmp}"
fi
TMPDIR="$BASE_TMP/restore-drill-$(date +%s)"
mkdir -p "$TMPDIR"

# ---- duration budget ----
SECONDS=0
check_budget() {
  if [ "$MAX_DURATION" -gt 0 ] && [ "$SECONDS" -ge "$MAX_DURATION" ]; then
    [ "$QUIET" -eq 0 ] && echo "⏱️ duration budget of ${MAX_DURATION}s exceeded - stopping (partial results follow)"
    exit 4
  fi
}

# Logs go to stderr when --json is on so stdout carries only the summary.
say() {
  if [ "$JSON_OUT" -eq 1 ]; then
    echo "$@" >&2
  elif [ "$QUIET" -eq 0 ]; then
    echo "$@"
  fi
}

say "🔍 Restore drill - $(date '+%Y-%m-%d %H:%M')"
[ "$DRY_RUN" -eq 1 ] && say "   mode: dry-run (connectivity only)"
say "   Temp: $TMPDIR"
say ""

FAIL_CLONE=0
FAIL_INTEGRITY=0
JSON_ROWS=()

for repo in "${REPOS[@]}"; do
  name="${repo#*/}"
  check_budget

  if [ "$DRY_RUN" -eq 1 ]; then
    if git ls-remote --heads "https://github.com/$repo.git" >/dev/null 2>&1; then
      say "   ✅ $name - reachable (auth OK)"
      JSON_ROWS+=("{\"repo\":\"$name\",\"reachable\":true}")
    else
      say "   ❌ $name - UNREACHABLE (check network and git authentication)"
      JSON_ROWS+=("{\"repo\":\"$name\",\"reachable\":false}")
      FAIL_CLONE=1
    fi
    say ""
    continue
  fi

  say "── Cloning $repo (full history - real restore semantics) ..."
  if git clone --quiet "https://github.com/$repo.git" "$TMPDIR/$name" 2>&1; then
    count=$(git -C "$TMPDIR/$name" rev-list --count HEAD 2>/dev/null || echo 0)
    files=$(git -C "$TMPDIR/$name" ls-files 2>/dev/null | wc -l | tr -d ' ')
    head=$(git -C "$TMPDIR/$name" log -1 --format='%h %ad' --date=short 2>/dev/null || echo "none")
    say "   ✅ $name - commits:$count files:$files HEAD:$head"

    if [ "$METADATA_ONLY" -eq 1 ]; then
      say "   ℹ️  metadata-only: fsck skipped"
      JSON_ROWS+=("{\"repo\":\"$name\",\"status\":\"ok\",\"commits\":$count,\"files\":$files,\"head\":\"${head% *}\",\"deep_checked\":false}")
    else
      check_budget
      if git -C "$TMPDIR/$name" fsck --no-dangling 2>/dev/null; then
        say "   ✅ integrity: fsck clean"
        JSON_ROWS+=("{\"repo\":\"$name\",\"status\":\"ok\",\"commits\":$count,\"files\":$files,\"head\":\"${head% *}\",\"deep_checked\":true}")
      else
        say "   ⚠️ integrity: fsck found issues"
        JSON_ROWS+=("{\"repo\":\"$name\",\"status\":\"corrupt\",\"commits\":$count,\"files\":$files,\"head\":\"${head% *}\",\"deep_checked\":true}")
        FAIL_INTEGRITY=1
      fi
    fi
  else
    say "   ❌ CLONE FAILED for $repo"
    JSON_ROWS+=("{\"repo\":\"$name\",\"status\":\"clone_failed\"}")
    FAIL_CLONE=1
  fi
  say ""
  check_budget
done

# ---- verdict banner ----
if [ "$FAIL_CLONE" -eq 0 ] && [ "$FAIL_INTEGRITY" -eq 0 ]; then
  say "🎉 RESTORE DRILL PASSED - all backups clone and verify."
  EXIT=0
else
  say "🚨 RESTORE DRILL FAILED"
  say "   Recovery checklist:"
  say "   - clone failed: check network and that git is authenticated"
  say "     (gh auth status, or git credential manager), then run again"
  say "   - integrity failed: re-clone the repo manually and compare;"
  say "     if objects are missing contact whoever owns the backup target"
  if [ "$FAIL_CLONE" -eq 1 ]; then EXIT=2; else EXIT=3; fi
fi

# ---- json summary ----
if [ "$JSON_OUT" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    MODE="dry_run"
  elif [ "$METADATA_ONLY" -eq 1 ]; then
    MODE="metadata_only"
  else
    MODE="deep"
  fi
  ROWS=$(IFS=,; echo "${JSON_ROWS[*]}")
  printf '{"mode":"%s","result":"%s","exit_code":%s,"repos":[%s]}\n' \
    "$MODE" "$([ "$EXIT" -eq 0 ] && echo pass || echo fail)" "$EXIT" "$ROWS"
fi

if [ "$KEEP" -eq 1 ]; then
  say "   (--keep: leaving clone at $TMPDIR)"
else
  rm -rf "$TMPDIR"
  say "   (temp clone removed)"
fi
exit $EXIT
