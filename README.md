# dotfiles

Personal Arch-centric dotfiles. GNU Stow packages at the repo root, plus a bootstrap script and two opt-in helpers.

## Install

Clone to `~/Projects/dotfiles` (the canonical location) and run the bootstrap:

```bash
git clone https://github.com/TuxLux40/dotfiles.git ~/Projects/dotfiles
~/Projects/dotfiles/install.sh
```

Or one-liner (clones to `~/Projects/dotfiles` by default):

```bash
curl -fsSL https://raw.githubusercontent.com/TuxLux40/dotfiles/main/install.sh | sh
```

The installer:

1. Detects the package manager (`nala apt-get dnf pacman zypper apk xbps-install eopkg`) and installs **GNU stow**.
2. Stows each package directory at the repo root into `$HOME` (e.g. `fish/.config/fish/config.fish` → `~/.config/fish/config.fish`).
3. Skips `clamav` by default (needs `/etc/clamav` and root; use `--clamav`).

By default the **repo is the source of truth**: conflicting symlinks are dropped and the tracked versions win. Pass `--adopt` to instead pull existing local configs into the repo.

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Preview stow actions, change nothing. |
| `--adopt` | Run `stow --adopt` (absorb existing local configs; local wins). |
| `--clamav` | Also stow `clamav` to `/etc` via sudo/doas. |
| `--sftp` | Run [sftp-setup.sh](sftp-setup.sh) after stowing. |
| `--nas [PATH]` | Run [symlink-nas.sh](symlink-nas.sh) after stowing. |

### Env

| Var | Default |
|-----|---------|
| `DOTFILES_REPO` | `https://github.com/TuxLux40/dotfiles.git` |
| `DOTFILES_DIR`  | `$HOME/Projects/dotfiles` (clone target in curl-pipe mode) |

> **Note:** keep a single canonical checkout at `~/Projects/dotfiles`. Do **not** clone to `~/.dotfiles` — a second clone leads to duplicate stow sources and configs symlinked into the wrong tree.

## Use with linutil

linutil's **System Setup → Dotfiles Setup** runs stow against a clone of this repo. The packages live at the repo root (a standard GNU-stow layout), so it works without modification — but linutil manages its own clone path, so prefer [install.sh](install.sh) for a single canonical checkout at `~/Projects/dotfiles`.

## Layout

- Package dirs at the repo root (`fish/`, `ghostty/`, `bash/`, `atuin/`, …) — each a GNU Stow package rooted at `$HOME` (exception: `clamav/` → `/etc`).
- [install.sh](install.sh) — bootstrap. Installs stow, stows packages.
- [sftp-setup.sh](sftp-setup.sh) — interactive SSHFS mount manager (systemd user units).
- [symlink-nas.sh](symlink-nas.sh) — NAS → XDG user-dirs symlinks.
- `system.yaml` — historical blendOS package manifest (reference only).

## Manual stow

```bash
cd ~/Projects/dotfiles
stow -n -v -t ~ fish      # dry-run
stow -t ~ fish            # apply
stow --adopt -t ~ fish    # absorb existing configs
stow -R -t ~ fish         # relink after changes
stow -D -t ~ fish         # unlink
```
