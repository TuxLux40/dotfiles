# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Personal Arch-centric dotfiles plus a stow bootstrap (`install.sh`) and two standalone helper scripts. GNU Stow **packages live at the repo root** (one directory per package); `install.sh` stows them into `$HOME`. The canonical checkout is `~/Projects/dotfiles` — **never `~/.dotfiles` or a second clone**, which produces duplicate stow sources and configs symlinked into the wrong tree. An older `scripts/`/`config/`/`ansible/` installer was removed; treat those paths as gone, not as code to resurrect.

`.github/copilot-instructions.md` still describes the old installer and is stale. If a task contradicts that file and the current tree, trust the tree.

## Layout

- Each top-level directory is a **GNU Stow package** rooted at `$HOME`, mirroring the target layout (e.g. `fish/.config/fish/config.fish` → `~/.config/fish/config.fish`; `bash/.bashrc` → `~/.bashrc`). `clamav/clamav/*.conf` is the exception: those link into `/etc/clamav` and need a root stow target, not `$HOME`.
- `install.sh` — POSIX `/bin/sh -e` bootstrap. Installs stow, then loops the top-level package dirs and stows each into `$HOME` (skips `clamav`; also skips any dir that isn't a `$HOME` package — one with a non-hidden top-level entry, e.g. a stray packages dir). Default is repo-wins (drops conflicting symlinks, `--adopt`s, then `git restore`s so tracked versions win); `--adopt` flips to local-wins.
- `system.yaml` — blendOS package manifest (historical; kept for package-list reference, not consumed by any script).
- `sftp-setup.sh` — interactive SSHFS mount manager. Installs `sshfs` via the detected package manager, generates a systemd **user** unit at `~/.config/systemd/user/sshfs-<host>.service`, enables it. Supports add/remove flows. POSIX `/bin/sh -e`.
- `symlink-nas.sh` — idempotent script that symlinks NAS paths (default `$HOME/nas`) into XDG user dirs (`~/Documents`, `~/Pictures`, `~/Music`, `~/Videos`, `~/Downloads`) using the `NAS-<source>` naming convention. Bash, `set -euo pipefail`. Flags: `--dry-run`, `--force`, `--nas PATH`. Refuses to clobber real files/dirs; only replaces existing symlinks when `--force`.

## Common operations

```bash
# Stow a single package into $HOME (run from the repo root)
cd ~/Projects/dotfiles && stow -t ~ fish

# Preview (dry run)
stow -n -v -t ~ fish

# Adopt existing configs into the repo (moves files into <pkg>/, then links back)
stow --adopt -t ~ fish

# Re-link after changes
stow -R -t ~ fish

# Unlink
stow -D -t ~ fish

# SSHFS mount manager (interactive)
./sftp-setup.sh

# NAS symlinks
./symlink-nas.sh --dry-run
./symlink-nas.sh --nas /mnt/nas
```

No test suite, no lint config, no build step.

## Conventions

- **Commits**: Conventional prefixes per `.github/COMMIT_MESSAGE_GUIDELINES.md` (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `ci:`, `config:`, `remove:`, `update:`, etc.). Imperative mood, wrap body at 72 chars.
- **Shell scripts**:
  - `symlink-nas.sh` style: bash, `set -euo pipefail`, explicit flags, idempotent, never clobber real files.
  - `sftp-setup.sh` style: POSIX `sh`, detect `sudo`/`doas` via `ESCALATION_TOOL`, detect package manager by probing `nala apt-get dnf pacman zypper apk xbps-install eopkg` in order. Match this pattern if adding new distro-portable scripts.
- **Adding a new dotfile package**: create `<name>/` at the repo root mirroring the home-relative target path (e.g. `<name>/.config/<name>/...` for XDG configs, or `<name>/.<file>` for a top-level dotfile). Stow derives the symlink target from that structure — don't flatten it. Every top-level entry a `$HOME` package places must be hidden (`.config`, `.bashrc`, …); `install.sh` skips any package dir with a non-hidden top-level entry.
- **Secrets**: `.gitignore` blocks `.env*` globally but keeps `*.env.example`. When adding config that references secrets, ship a `.env.example` and keep the real file untracked.

## GitHub workflows

`.github/workflows/sync-wiki.yml` and `update-readme.yml` trigger on paths (`scripts/**`, `config/**`, `output/**`, `install.sh`) that no longer exist. They'll still run on `**/*.md` changes but most of their logic is dead. Don't rely on them; flag them for cleanup if touching CI.
