#!/usr/bin/env bash
# ============================================================================
# install.sh - the installer for the colour role system
#
# This is the only installer. Runtime-dir handling, aliases, nano syntax and
# prompt setup are all flags here rather than separate wrapper scripts.
#
# DESIGN
#   Code vs data. colors.source.sh, install_hook.sh and validate_color_roles.sh
#   are CODE: always refreshed to the shipped version. color_roles.json and
#   .bash_aliases are DATA: created if absent, preserved otherwise, and only
#   replaced under --force. That split is what makes re-running safe.
#
#   Self-healing. Missing files, broken symlinks and a half-migrated legacy
#   layout are repaired on every run. Running this twice, or after something
#   deleted half the runtime, converges to the same working state.
#
#   Fail closed. The installed schema is validated against color-laws.json
#   before the run is declared successful.
# ============================================================================

set -euo pipefail

VERSION="3.4.0"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

REPO_ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
TEMPLATE_DIR="$REPO_ROOT/ctl_environment_template"

DEFAULT_RUNTIME="${XDG_DATA_HOME:-$HOME/.local/share}/tss/color"
RUNTIME_DIR="${COLOR_RUNTIME_HOME:-$DEFAULT_RUNTIME}"
LEGACY_DIR="$HOME/ctl_environment"
LEGACY_SYMLINK="$HOME/.color_roles.json"
BASHRC="$HOME/.bashrc"
BASH_ALIASES_FILE="$HOME/.bash_aliases"
NANO_DIR="$HOME/.nano"
NANORC="$HOME/.nanorc"

BEGIN_MARK="# >>> color role system >>>"
END_MARK="# <<< color role system <<<"

FORCE=false
BACKUP=false
SKIP_ALIASES=false
SKIP_NANO=false
INSTALL_PROMPT=true
STRICT=false
RUNTIME_ONLY=false

usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

  --runtime-dir <path>  Install the runtime here.
                        Default: \$XDG_DATA_HOME/tss/color
                        (${DEFAULT_RUNTIME})
  -f, --force           Replace user data (color_roles.json, .bash_aliases).
                        Code files are always refreshed regardless.
  -b, --backup          Back up any file replaced by --force.
      --runtime-only    Refresh an existing staged runtime; do not touch shell files.
      --skip-aliases    Do not install ~/.bash_aliases.
      --skip-nano       Do not install nano TS/TSX syntax files.
      --no-prompt       Leave PS1 alone.
      --prompt          Colour the prompt (default).
      --strict          Fail on advisory policy warnings too.
  -h, --help            This message.
  -v, --version         Print version.

Re-running is safe and idempotent. It also repairs a damaged install.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --runtime-dir) [ $# -ge 2 ] || { error "--runtime-dir requires a path"; exit 2; }; RUNTIME_DIR="$2"; shift 2 ;;
    -f|--force)    FORCE=true; shift ;;
    -b|--backup)   BACKUP=true; shift ;;
    --runtime-only) RUNTIME_ONLY=true; shift ;;
    --skip-aliases) SKIP_ALIASES=true; shift ;;
    --skip-nano)   SKIP_NANO=true; shift ;;
    --no-prompt)   INSTALL_PROMPT=false; shift ;;
    --prompt)      INSTALL_PROMPT=true; shift ;;
    --strict)      STRICT=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    -v|--version)  echo "$VERSION"; exit 0 ;;
    *) error "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

$BACKUP && ! $FORCE && { error "--backup requires --force."; exit 2; }

RUNTIME_DIR="${RUNTIME_DIR%/}"
case "$RUNTIME_DIR" in
  /*) ;;
  *) error "--runtime-dir must be an absolute path."; exit 2 ;;
esac

# ---------------------------------------------------------------- helpers ---
backup_path() {
  local f="$1"
  [ -e "$f" ] || return 0
  local b
  b="${f}.backup.$(date +%Y%m%d_%H%M%S)"
  cp -a "$f" "$b"
  info "Backed up: $b"
}

# Code: always overwrite with the shipped version.
install_code() {
  local src="$1" dest="$2" mode="${3:-644}"
  [ -f "$src" ] || { error "Template missing: $src"; exit 1; }
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    info "$(basename "$dest") already current."
  else
    install -m "$mode" "$src" "$dest"
    success "$(basename "$dest") installed."
  fi
}

# Data: create if absent, preserve otherwise.
install_data() {
  local src="$1" dest="$2"
  [ -f "$src" ] || { error "Template missing: $src"; exit 1; }
  mkdir -p "$(dirname "$dest")"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    success "$(basename "$dest") created."
  elif $FORCE; then
    $BACKUP && backup_path "$dest"
    cp "$src" "$dest"
    warn "$(basename "$dest") replaced (--force)."
  else
    info "$(basename "$dest") preserved (use --force to replace)."
  fi
}

# ------------------------------------------------------------ dependencies --
info "Colour role system installer v$VERSION"
if ! command -v jq >/dev/null 2>&1; then
  error "jq is required. Install it with: sudo apt-get install -y jq"
  exit 2
fi
command -v nano >/dev/null 2>&1 || $SKIP_NANO || warn "nano not found; syntax files will still be installed."

if $RUNTIME_ONLY; then
  if [ ! -f "$RUNTIME_DIR/color_roles.json" ] || $FORCE; then
    error "--runtime-only requires an existing runtime and forbids --force."
    exit 2
  fi
fi

# The vocabulary is shipped reference data, not user-editable role data.
# Reject unreadable or incomplete packages before changing installed files.
if ! jq -e 'type == "object" and (.terms | type == "array" and length > 0)
    and (.domains | type == "array" and length > 0)
    and (.classification.role_to_term | type == "object")' \
    "$REPO_ROOT/docs/vocabulary.json" >/dev/null; then
  error "Invalid shipped vocabulary: $REPO_ROOT/docs/vocabulary.json"
  exit 1
fi

# ------------------------------------------------- migrate legacy layout ----
# A real directory at ~/ctl_environment from a pre-3.0 install is moved into
# the runtime once, preserving any roles the user registered.
if ! $RUNTIME_ONLY && [ -d "$LEGACY_DIR" ] && [ ! -L "$LEGACY_DIR" ]; then
  if [ "$LEGACY_DIR" != "$RUNTIME_DIR" ]; then
    mkdir -p "$(dirname "$RUNTIME_DIR")"
    if [ -e "$RUNTIME_DIR" ]; then
      info "Merging legacy $LEGACY_DIR into existing runtime."
      [ -f "$LEGACY_DIR/color_roles.json" ] && [ ! -f "$RUNTIME_DIR/color_roles.json" ] \
        && cp "$LEGACY_DIR/color_roles.json" "$RUNTIME_DIR/color_roles.json"
      backup_path "$LEGACY_DIR"
      rm -rf "$LEGACY_DIR"
    else
      mv "$LEGACY_DIR" "$RUNTIME_DIR"
      success "Migrated legacy runtime to $RUNTIME_DIR"
    fi
  fi
fi

mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/laws/color" "$RUNTIME_DIR/cache"

# ------------------------------------------------------------ install core --
install_data "$TEMPLATE_DIR/color_roles.json.template"            "$RUNTIME_DIR/color_roles.json"
install_code "$TEMPLATE_DIR/laws/color/color-laws.json.template"   "$RUNTIME_DIR/laws/color/color-laws.json"
install_code "$TEMPLATE_DIR/colors.source.sh.template"            "$RUNTIME_DIR/colors.source.sh"
install_code "$TEMPLATE_DIR/install_hook.sh.template"             "$RUNTIME_DIR/install_hook.sh" 755
install_code "$REPO_ROOT/validate_color_roles.sh"                 "$RUNTIME_DIR/validate_color_roles.sh" 755
install_code "$TEMPLATE_DIR/color-cli.sh.template"                "$RUNTIME_DIR/color-cli.sh"
install_code "$REPO_ROOT/docs/vocabulary.json"                     "$RUNTIME_DIR/vocabulary.json"

# Invalidate the compiled cache so the next shell recompiles from the schema.
rm -f "$RUNTIME_DIR/cache/roles.sh"
echo "$VERSION" > "$RUNTIME_DIR/.version"

if ! $RUNTIME_ONLY; then
# Record the actual checkout once; runtime-only archives retain this file.
if command -v git >/dev/null 2>&1 && [ "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || true)" = "$REPO_ROOT" ]; then
  printf '%s\n' "$REPO_ROOT" > "$RUNTIME_DIR/.update-repo"
fi
# --------------------------------------------------- compatibility links ----
# These are conveniences only. The loader is self-locating and works without
# them; nothing in the runtime resolves through these paths.
if [ "$LEGACY_DIR" != "$RUNTIME_DIR" ]; then
  if [ -e "$LEGACY_DIR" ] && [ ! -L "$LEGACY_DIR" ]; then
    warn "$LEGACY_DIR exists and is not a symlink; leaving it alone."
  else
    ln -sfn "$RUNTIME_DIR" "$LEGACY_DIR"
    info "Compatibility link: $LEGACY_DIR -> $RUNTIME_DIR"
  fi
fi
if [ -e "$LEGACY_SYMLINK" ] && [ ! -L "$LEGACY_SYMLINK" ]; then
  warn "$LEGACY_SYMLINK is a regular file; leaving it alone."
else
  ln -sfn "$RUNTIME_DIR/color_roles.json" "$LEGACY_SYMLINK"
fi

# ---------------------------------------------------------------- aliases ---
if $SKIP_ALIASES; then
  info "Skipping aliases."
else
  install_data "$REPO_ROOT/bash_aliases_template.sh" "$BASH_ALIASES_FILE"
fi

# ------------------------------------------------------------------- nano ---
if $SKIP_NANO; then
  info "Skipping nano syntax."
else
  mkdir -p "$NANO_DIR"
  install_code "$TEMPLATE_DIR/nano/typescript.nanorc.template" "$NANO_DIR/typescript.nanorc"
  install_code "$TEMPLATE_DIR/nano/tsx.nanorc.template"        "$NANO_DIR/tsx.nanorc"
  touch "$NANORC"
  for inc in 'include "~/.nano/typescript.nanorc"' 'include "~/.nano/tsx.nanorc"'; do
    grep -Fqx "$inc" "$NANORC" || echo "$inc" >> "$NANORC"
  done
fi

# ---------------------------------------------------------------- bashrc ----
# One managed block, delimited by sentinels, rewritten wholesale each run.
# Nothing outside the sentinels is ever touched.
touch "$BASHRC"
if grep -Fq "$BEGIN_MARK" "$BASHRC"; then
  if ! grep -Fq "$END_MARK" "$BASHRC"; then
    error "Managed block in $BASHRC is damaged (begin marker without end marker)."
    error "Refusing to rewrite it. Fix or remove the block by hand, then re-run."
    exit 1
  fi
  backup_path "$BASHRC"
  tmp="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$BASHRC" > "$tmp"
  mv "$tmp" "$BASHRC"
fi
{
  echo "$BEGIN_MARK"
  echo "# Managed by install.sh v$VERSION. Edits inside this block are overwritten."
  echo "export COLOR_RUNTIME_HOME=\"$RUNTIME_DIR\""
  $INSTALL_PROMPT || echo "export COLOR_PROMPT_DISABLE=1"
  echo "[ -r \"\$COLOR_RUNTIME_HOME/colors.source.sh\" ] && . \"\$COLOR_RUNTIME_HOME/colors.source.sh\""
  if ! $SKIP_ALIASES; then
    echo "[ -r \"\$HOME/.bash_aliases\" ] && . \"\$HOME/.bash_aliases\""
  fi
  echo "$END_MARK"
} >> "$BASHRC"
success "Managed block written to .bashrc"
fi

# --------------------------------------------------------------- enforce ----
info "Enforcing colour policy..."
VALIDATE_ARGS=()
$STRICT && VALIDATE_ARGS+=(--strict)
if ! "$RUNTIME_DIR/validate_color_roles.sh" "${VALIDATE_ARGS[@]+"${VALIDATE_ARGS[@]}"}" \
      "$RUNTIME_DIR/color_roles.json" "$RUNTIME_DIR/laws/color/color-laws.json"; then
  error "Installed schema violates color-laws.json. Install FAILED."
  error "Ways out:"
  error "  recolour one role:  $RUNTIME_DIR/install_hook.sh <role> <category> <hierarchy> --replace"
  error "  reset to shipped:   $0 --force"
  error "  relax the rule:     edit $RUNTIME_DIR/laws/color/color-laws.json"
  exit 1
fi

# ---------------------------------------------------------------- verify ----
fail=0
for f in color_roles.json laws/color/color-laws.json colors.source.sh \
         install_hook.sh validate_color_roles.sh color-cli.sh vocabulary.json .version; do
  [ -e "$RUNTIME_DIR/$f" ] || { error "Missing after install: $RUNTIME_DIR/$f"; fail=1; }
done
for f in install_hook.sh validate_color_roles.sh; do
  [ -x "$RUNTIME_DIR/$f" ] || { error "Not executable: $RUNTIME_DIR/$f"; fail=1; }
done
if ! $RUNTIME_ONLY; then
  grep -Fq "$BEGIN_MARK" "$BASHRC" || { error "Managed block missing from .bashrc"; fail=1; }
fi

# Prove the loader works standalone, with no symlink and no COLOR_RUNTIME_HOME.
if ! ( unset COLOR_RUNTIME_HOME COLOR_ROLE_SCHEMA_PATH COLOR_LAWS_PATH
       # shellcheck source=/dev/null  # path is the chosen runtime dir, not fixed
       . "$RUNTIME_DIR/colors.source.sh" >/dev/null 2>&1
       [ "${COLOR_SYSTEM_READY:-0}" -eq 1 ] && get_color_by_role prompt >/dev/null ); then
  error "Loader self-test failed: runtime did not come up standalone."
  fail=1
fi

[ "$fail" -eq 0 ] || { error "Verification failed."; exit 1; }

echo
success "Install complete. Runtime: $RUNTIME_DIR"
info "Reload your shell:  source ~/.bashrc"
info "Try:  colorroles  |  color_apply success \"it works\"  |  color_validate"
