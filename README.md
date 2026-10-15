<div align="center">

[![Stars](https://img.shields.io/github/stars/StefanYasin/restore-drill?style=flat)]
[![License](https://img.shields.io/github/license/StefanYasin/restore-drill?style=flat)]
[![Issues](https://img.shields.io/github/issues/StefanYasin/restore-drill?style=flat)]
[![Last commit](https://img.shields.io/github/last-commit/StefanYasin/restore-drill?style=flat)]
[![Language](https://img.shields.io/github/languages/top/StefanYasin/restore-drill?style=flat)]

[![Tests](https://img.shields.io/github/actions/workflow/status/StefanYasin/restore-drill/ci.yml?style=flat&label=tests)]
</div>

# Restore Drill 🔍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Verify your GitHub backups actually restore — in one command.**

Backups are only worth something if they can come back. `restore-drill.sh` clones
your private backup repos to a temp directory, verifies integrity, and cleans up.

## What it checks

- ✅ **Clone** — full history clone (real restore semantics, not shallow)
- ✅ **Contents** — commit count, file count, HEAD hash + date
- ✅ **Integrity** — `git fsck` clean (no corruption, no dangling objects)

## Usage

```bash
bash restore-drill.sh          # run the drill, clean up after
bash restore-drill.sh --keep   # leave the clone behind for inspection
```

Exit code `0` = pass, `1` = a repo failed. Wire it into a cron for quarterly drills.

## Config

Edit the `REPOS` array at the top:

```bash
REPOS=(
  "you/private-notes"
  "you/hermes-backup"
)
```

## Why this exists

A backup that has never been restored is a rumor. This is the 5-minute
sanity check that turns "I back up daily" into "I *know* my backups restore."

## Notes

- Uses a Windows-native temp path (`%LOCALAPPDATA%\Temp`) — MSYS `/tmp` breaks
  native `git -C` on Windows (learned the hard way)
- `git fsck` has no `--quiet` flag on some versions — redirect output instead
- Works on macOS/Linux too (swap `$LOCALAPPDATA` for `/tmp` if needed)

## License

MIT — see [LICENSE](LICENSE).

---

Built and maintained by **Stefan Yasin** — technical operations, infrastructure, and applied AI. [Portfolio](https://stefanyasin.github.io/) · [LinkedIn](https://www.linkedin.com/in/stefanyasin/) · [Buy me a coffee](https://buymeacoffee.com/stefanthepro)
