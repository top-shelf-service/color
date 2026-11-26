#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_DATA_HOME="$work/home/data"
mkdir -p "$HOME" "$work/upstream"
unset COLOR_RUNTIME_HOME COLOR_ROLE_SCHEMA_PATH COLOR_LAWS_PATH
# Create a local trusted origin; no network or real home is used.
git -C "$root" archive HEAD | tar -xf - -C "$work/upstream"
git -C "$work/upstream" init -q -b main
git -C "$work/upstream" add .
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm baseline
git clone -q "$work/upstream" "$work/checkout"
printf '%s\n' 'alias personal="echo preserved"' > "$HOME/.bash_aliases"
"$work/checkout/install.sh" >/dev/null
rt="$XDG_DATA_HOME/tss/color"
# shellcheck source=/dev/null
source "$rt/colors.source.sh"
color help | grep -q update
[ "$(color version)" = 3.3.0 ]
color list > "$work/list"
grep -q directory "$work/list"
color validate >/dev/null
if color nonexistent || color update extra; then exit 1; fi
"$rt/install_hook.sh" test_custom test child --hex '#FFAA55' >/dev/null
cp "$rt/color_roles.json" "$work/roles"
cp "$HOME/.bashrc" "$work/bashrc"
cp "$HOME/.bash_aliases" "$work/aliases"
sed -i 's/VERSION="3.3.0"/VERSION="3.3.1"/' "$work/upstream/install.sh"
git -C "$work/upstream" add install.sh
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm update
color update
[ "$(color version)" = 3.3.1 ]
cmp "$work/roles" "$rt/color_roles.json"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/aliases" "$HOME/.bash_aliases"
color update > "$work/repeat"
grep -q 'already current' "$work/repeat"
# A candidate with a stricter policy rejects the current roles.
laws="$work/upstream/ctl_environment_template/laws/color/color-laws.json.template"
jq '.rules.require_contrast_ratio.min_ratio = 21' "$laws" > "$work/laws"
mv "$work/laws" "$laws"
git -C "$work/upstream" add .
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm rejected
if color update; then echo 'Invalid update accepted' >&2; exit 1; fi
[ "$(color version)" = 3.3.1 ]
cmp "$work/roles" "$rt/color_roles.json"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/aliases" "$HOME/.bash_aliases"
color validate >/dev/null
printf 'CLI update contract passed.\n'
