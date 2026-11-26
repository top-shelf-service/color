#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home"
mkdir "$HOME"
unset COLOR_RUNTIME_HOME COLOR_ROLE_SCHEMA_PATH COLOR_LAWS_PATH
export XDG_DATA_HOME="$HOME/.local/share"
# Use a personal alias with a conflicting name, a custom alias, and code
# which would create a sentinel if anyone sourced the file during inspection.
# Literal shell code is the nonexecution sentinel, not an expression.
# shellcheck disable=SC2016
printf "%s\n" "alias colorroles='echo personal'" "alias mine='echo keep'" 'touch "$HOME/evaluated"' > "$HOME/.bash_aliases"
cp "$HOME/.bash_aliases" "$work/original"
bash "$repo/install.sh" --skip-nano --no-prompt >/dev/null
rt="$HOME/.local/share/tss/color"
# shellcheck source=/dev/null
. "$rt/colors.source.sh"
cmp "$work/original" "$HOME/.bash_aliases"
[ ! -e "$HOME/evaluated" ]
color aliases > "$work/inspect" 2>&1
grep -Fq 'POSSIBLE CONFLICT colorroles' "$work/inspect"
[ ! -e "$rt/aliases.enabled" ]
[ ! -e "$HOME/evaluated" ]
alias colorroles='echo personal'
alias mine='echo keep'
color aliases update > "$work/update" 2>&1
grep -Fq 'CONFLICT colorroles' "$work/update"
[ -d "$rt/aliases.enabled" ]
[ "$(alias colorroles)" = "alias colorroles='echo personal'" ]
[ "$(alias mine)" = "alias mine='echo keep'" ]
# Compare the shipped literal, including its unexpanded variable references.
# shellcheck disable=SC2016
[ "$(alias colorreload)" = 'alias colorreload='\''source "${COLOR_RUNTIME_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/tss/color}/colors.source.sh"'\''' ]
alias colortest >/dev/null
color aliases update > "$work/repeat" 2>&1
if grep -q 'ADDED' "$work/repeat"; then echo "Repeated update added aliases" >&2; exit 1; fi
cmp "$work/original" "$HOME/.bash_aliases"
[ ! -e "$HOME/evaluated" ]
# Verify the real managed hook, after the normal personal source.
bash --noprofile --norc -c '
  set -e
  . "$HOME/.bashrc"
  [ "$(alias colorroles)" = "alias colorroles='\''echo personal'\''" ]
  [ "$(alias mine)" = "alias mine='\''echo keep'\''" ]
  alias colorreload >/dev/null
  alias colortest >/dev/null
' > "$work/startup" 2>&1
grep -Fq 'CONFLICT colorroles' "$work/startup"
[ -e "$HOME/evaluated" ]
cmp "$work/original" "$HOME/.bash_aliases"
# Runtime-only refresh retains opt-in and never touches startup/personal files.
cp "$HOME/.bashrc" "$work/bashrc"
bash "$repo/install.sh" --runtime-only --runtime-dir "$rt" >/dev/null
[ -d "$rt/aliases.enabled" ]
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/original" "$HOME/.bash_aliases"
# Reload and check invalid argument, lock, unsafe file and malformed syntax.
# shellcheck source=/dev/null
. "$rt/colors.source.sh"
reject() {
  local expected="$1" rc=0
  shift
  color "$@" > "$work/reject" 2>&1 || rc=$?
  [ "$rc" -eq "$expected" ] || { cat "$work/reject"; return 1; }
}
reject 2 aliases update extra
mkdir "$rt.update-lock"
reject 1 aliases update
rmdir "$rt.update-lock"
cmp "$work/original" "$HOME/.bash_aliases"
mv "$HOME/.bash_aliases" "$work/personal"
ln -s "$work/personal" "$HOME/.bash_aliases"
reject 1 aliases
reject 1 aliases update
cmp "$work/original" "$work/personal"
rm "$HOME/.bash_aliases"
mkdir "$HOME/.bash_aliases"
reject 1 aliases update
rmdir "$HOME/.bash_aliases"
printf "alias broken='unterminated\n" > "$HOME/.bash_aliases"
cp "$HOME/.bash_aliases" "$work/malformed"
reject 1 aliases update
cmp "$work/malformed" "$HOME/.bash_aliases"
cp "$work/personal" "$HOME/.bash_aliases"
mv "$rt/alias-reference.txt" "$work/reference"
printf "alias colorroles='one'\nalias colorroles='two'\n" > "$rt/alias-reference.txt"
reject 1 aliases update
mv "$work/reference" "$rt/alias-reference.txt"
cmp "$work/original" "$HOME/.bash_aliases"
# Existing explicit keep-aliases uninstall behavior remains intact.
bash "$repo/uninstall.sh" -y --keep-aliases >/dev/null
cmp "$work/original" "$HOME/.bash_aliases"
[ ! -e "$rt" ]
printf 'Managed alias inspection, activation, conflict and preservation contracts passed.\n'
