#!/usr/bin/env bash
# uninstall.sh - remove the colour role system
#
# Removes the runtime wherever it actually lives (resolved from the managed
# .bashrc block, the environment, or the compat symlink), strips exactly the
# managed block from .bashrc, and leaves everything else untouched.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

BASHRC="$HOME/.bashrc"
LEGACY_DIR="$HOME/ctl_environment"
LEGACY_SYMLINK="$HOME/.color_roles.json"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
BEGIN_MARK="# >>> color role system >>>"
END_MARK="# <<< color role system <<<"

ASSUME_YES=false
KEEP_ALIASES=false
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=true ;;
    --keep-aliases) KEEP_ALIASES=true ;;
    -h|--help) echo "Usage: $0 [-y|--yes] [--keep-aliases]"; exit 0 ;;
    *) error "Unknown option: $a"; exit 2 ;;
  esac
done

# Resolve the real runtime: managed block first, then env, then the symlink.
RUNTIME_DIR=""
if [ -f "$BASHRC" ]; then
  RUNTIME_DIR="$(awk -F'"' '/^export COLOR_RUNTIME_HOME=/{print $2; exit}' "$BASHRC" || true)"
fi
[ -n "$RUNTIME_DIR" ] || RUNTIME_DIR="${COLOR_RUNTIME_HOME:-}"
if [ -z "$RUNTIME_DIR" ] && [ -L "$LEGACY_DIR" ]; then
  RUNTIME_DIR="$(readlink -f "$LEGACY_DIR" || true)"
fi
[ -n "$RUNTIME_DIR" ] || RUNTIME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tss/color"

echo "This will remove:"
echo "  runtime         $RUNTIME_DIR"
echo "  compat link     $LEGACY_DIR"
echo "  compat link     $LEGACY_SYMLINK"
echo "  managed block   $BASHRC"
$KEEP_ALIASES || echo "  aliases         $BASH_ALIASES_FILE (prompted separately)"

if ! $ASSUME_YES; then
  read -r -p "Proceed? (y/N) " reply
  case "$reply" in [yY]|[yY][eE][sS]) ;; *) info "Cancelled."; exit 0 ;; esac
fi

# Refuse to delete anything outside $HOME.
safe_rm_dir() {
  local d="$1"
  [ -n "$d" ] && [ -d "$d" ] || return 0
  case "$(readlink -f "$d")" in
    "$HOME"/*) rm -rf "$d"; success "Removed $d" ;;
    *) warn "Refusing to remove path outside \$HOME: $d" ;;
  esac
}

[ -L "$LEGACY_DIR" ] && { rm -f "$LEGACY_DIR"; success "Removed compat link $LEGACY_DIR"; }
safe_rm_dir "$RUNTIME_DIR"
[ -d "$LEGACY_DIR" ] && safe_rm_dir "$LEGACY_DIR"
[ -L "$LEGACY_SYMLINK" ] && { rm -f "$LEGACY_SYMLINK"; success "Removed $LEGACY_SYMLINK"; }

# Prune now-empty parents left behind by the runtime, but never $HOME itself.
parent="$(dirname "$RUNTIME_DIR")"
while [ "$parent" != "$HOME" ] && [ "$parent" != "/" ] && [ -d "$parent" ]; do
  rmdir "$parent" 2>/dev/null || break
  parent="$(dirname "$parent")"
done

if [ -f "$BASHRC" ]; then
  if grep -Fq "$BEGIN_MARK" "$BASHRC"; then
    cp -a "$BASHRC" "${BASHRC}.backup.$(date +%Y%m%d_%H%M%S)"
    tmp="$(mktemp)"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$BASHRC" > "$tmp"
    mv "$tmp" "$BASHRC"
    success "Managed block removed from .bashrc (backup created)."
  else
    info "No managed block in .bashrc."
    if grep -qE 'ctl_environment/colors\.source\.sh|COLOR_RUNTIME_HOME' "$BASHRC"; then
      warn "Found pre-3.0 colour lines in .bashrc. Remove these by hand:"
      grep -nE 'ctl_environment/colors\.source\.sh|COLOR_RUNTIME_HOME|# Color Role System' "$BASHRC" >&2 || true
    fi
  fi
fi

if ! $KEEP_ALIASES && [ -f "$BASH_ALIASES_FILE" ]; then
  if $ASSUME_YES; then
    rm -f "$BASH_ALIASES_FILE"; success "Removed $BASH_ALIASES_FILE"
  else
    read -r -p "Also delete $BASH_ALIASES_FILE? (y/N) " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) rm -f "$BASH_ALIASES_FILE"; success "Removed $BASH_ALIASES_FILE" ;;
      *) info "Kept $BASH_ALIASES_FILE" ;;
    esac
  fi
fi

echo
success "Uninstall complete."
info "Open a new shell, or run: source ~/.bashrc"
