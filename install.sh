#! /bin/sh -e

# Dotfiles bootstrap.
# Standalone (curl | sh): clones to ~/Projects/dotfiles, symlinks ~/.config/dotfiles, stows.
# In-repo   (./install.sh): stows from current checkout (repo wins by default).
# Linutil-compat          : packages live at repo root (no dotfiles/ subdir); Linutil's
#                           dotfiles-setup.sh may need updating to match this layout.

REPO_URL="${DOTFILES_REPO:-https://github.com/TuxLux40/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Projects/dotfiles}"

# --- helpers ------------------------------------------------------------------
RC='\033[0m'; RED='\033[31m'; YLW='\033[33m'; CYN='\033[36m'; GRN='\033[32m'
msg()  { printf "%b\n" "${CYN}==>${RC} $*"; }
warn() { printf "%b\n" "${YLW}warn:${RC} $*" >&2; }
die()  { printf "%b\n" "${RED}error:${RC} $*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# Escalation tool
if [ "$(id -u)" = "0" ]; then
    SUDO="env"
else
    SUDO=""
    for _t in sudo doas; do has "$_t" && SUDO="$_t" && break; done
    [ -z "$SUDO" ] && die "no sudo/doas found"
fi

# Package manager
PM=""
for _p in nala apt-get dnf pacman zypper apk xbps-install eopkg; do
    has "$_p" && PM="$_p" && break
done
[ -z "$PM" ] && die "no supported package manager"

pkg_install() {
    _bin="$1"; shift
    has "$_bin" && return 0
    msg "installing $_bin"
    case "$PM" in
        pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
        *)      $SUDO "$PM" install -y "$@" ;;
    esac
}

# --- args ---------------------------------------------------------------------
WITH_CLAMAV=0 WITH_SFTP=0 WITH_NAS=0 NAS_PATH="" DRY_RUN=0 ADOPT=0

usage() { cat <<EOF
Usage: install.sh [options]

  --dry-run     Preview stow actions only.
  --adopt       Let stow adopt local configs (local wins). Default: repo wins.
  --clamav      Stow clamav to /etc/clamav (needs root).
  --sftp        Run sftp-setup.sh after stowing.
  --nas [PATH]  Run symlink-nas.sh after stowing.
  -h, --help    Show this message.

Env: DOTFILES_REPO, DOTFILES_DIR (clone target, default: ~/Projects/dotfiles)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1;     shift ;;
        --adopt)   ADOPT=1;       shift ;;
        --clamav)  WITH_CLAMAV=1; shift ;;
        --sftp)    WITH_SFTP=1;   shift ;;
        --nas)
            WITH_NAS=1; shift
            case "${1:-}" in ""|-*) ;; *) NAS_PATH="$1"; shift ;; esac ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown arg: $1 (try --help)" ;;
    esac
done

# --- locate repo --------------------------------------------------------------
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE:-}" ]; then
    SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$BASH_SOURCE")" && pwd)"
elif [ -f "$0" ] && [ "$0" != "sh" ] && [ "$0" != "-sh" ]; then
    SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd 2>/dev/null)" || true
fi

REPO_ROOT=""
[ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ] && REPO_ROOT="$SCRIPT_DIR"

if [ -z "$REPO_ROOT" ]; then
    pkg_install git git
    if [ -d "$DOTFILES_DIR/.git" ]; then
        msg "updating $DOTFILES_DIR"
        git -C "$DOTFILES_DIR" pull --ff-only
    elif [ -e "$DOTFILES_DIR" ]; then
        die "$DOTFILES_DIR exists and is not a git repo"
    else
        msg "cloning $REPO_URL -> $DOTFILES_DIR"
        mkdir -p "$(dirname "$DOTFILES_DIR")"
        git clone --depth=1 "$REPO_URL" "$DOTFILES_DIR"
    fi
    REPO_ROOT="$DOTFILES_DIR"
    _link="$HOME/.config/dotfiles"
    [ ! -e "$_link" ] && [ ! -L "$_link" ] && ln -s "$REPO_ROOT" "$_link" && msg "linked $_link -> $REPO_ROOT"
fi

# --- stow ---------------------------------------------------------------------
pkg_install stow stow

STOW_FLAGS="-v"
[ "$DRY_RUN" -eq 1 ] && STOW_FLAGS="$STOW_FLAGS -n"
[ "$ADOPT"   -eq 1 ] && STOW_FLAGS="$STOW_FLAGS --adopt"

# A $HOME stow package only ever places hidden entries (.config, .bashrc, …) at
# the top of $HOME. A directory with a non-hidden top-level entry (e.g. an old
# packages dir like dotfiles/) would litter $HOME, so it is not a $HOME package.
is_home_pkg() {
    for _e in "$1"/*; do
        if [ -e "$_e" ] || [ -L "$_e" ]; then return 1; fi
    done
    return 0
}

# Delete any file or symlink that would conflict with stow, so repo version wins.
clear_conflicts() {
    _pkg="$1"; _tgt="$2"; _sudo="${3:-}"
    find "$_pkg" \( -type f -o -type l \) | while IFS= read -r _src; do
        _dst="$_tgt/${_src#"$_pkg"/}"
        [ -e "$_dst" ] || [ -L "$_dst" ] || continue
        if [ "$DRY_RUN" -eq 1 ]; then msg "would remove: $_dst"
        else $_sudo rm -f "$_dst"; fi
    done
}

msg "stowing from $REPO_ROOT -> $HOME"
cd "$REPO_ROOT"

for _pkg in */; do
    _pkg="${_pkg%/}"
    [ "$_pkg" = "clamav" ] && continue
    [ -d "$_pkg" ] || continue
    if ! is_home_pkg "$_pkg"; then
        warn "skipping $_pkg: non-hidden top-level entries (not a \$HOME stow package)"
        continue
    fi
    printf "%b\n" "${CYN}--${RC} $_pkg"
    [ "$ADOPT" -eq 0 ] && clear_conflicts "$_pkg" "$HOME" ""
    # shellcheck disable=SC2086
    stow $STOW_FLAGS -t "$HOME" "$_pkg" || warn "stow failed: $_pkg"
done

if [ "$WITH_CLAMAV" -eq 1 ] && [ -d "clamav" ]; then
    msg "stowing clamav -> /etc"
    [ "$ADOPT" -eq 0 ] && clear_conflicts "clamav" "/etc" "$SUDO"
    # shellcheck disable=SC2086
    $SUDO stow $STOW_FLAGS -t /etc clamav || warn "stow failed: clamav"
fi

cd - >/dev/null

# --- extras -------------------------------------------------------------------
[ "$WITH_SFTP" -eq 1 ] && msg "running sftp-setup.sh" && sh "$REPO_ROOT/sftp-setup.sh"

if [ "$WITH_NAS" -eq 1 ]; then
    msg "running symlink-nas.sh"
    _args=""
    [ "$DRY_RUN" -eq 1 ] && _args="--dry-run"
    [ -n "$NAS_PATH" ] && _args="$_args --nas $NAS_PATH"
    # shellcheck disable=SC2086
    bash "$REPO_ROOT/symlink-nas.sh" $_args
fi

printf "%b\n" "${GRN}done.${RC}"
