#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_DATA_HOME="$work/home/data" COLOR_PROMPT_DISABLE=1
mkdir -p "$HOME"
unset COLOR_RUNTIME_HOME COLOR_ROLE_SCHEMA_PATH COLOR_LAWS_PATH
printf '%s\n' 'alias personal="echo preserved"' > "$HOME/.bash_aliases"
"$root/install.sh" >/dev/null
rt="$XDG_DATA_HOME/tss/color"
# shellcheck source=/dev/null
source "$rt/colors.source.sh"
cp "$HOME/.bash_aliases" "$work/aliases"
cp "$HOME/.bashrc" "$work/bashrc"
cp "$rt/.version" "$work/version"
cp "$rt/laws/color/color-laws.json" "$work/policy"
printf 'unrelated\n' > "$rt/unrelated"
cp "$rt/color_roles.json" "$work/original"
snapshot=$(color backup)
[ -d "$snapshot" ]
cmp "$work/original" "$snapshot/color_roles.json"
[ "$(cat "$(dirname "$snapshot")/roles.sha256")" = "$(sha256sum < "$work/original" | cut -d ' ' -f 1)" ]
"$rt/install_hook.sh" test_custom test child --hex '#FFAA55' >/dev/null
color_reload
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
cp "$rt/color_roles.json" "$work/changed"
cp "$rt/cache/roles.sh" "$work/cache"
# Wrong arguments, missing path, occupied lock, and corrupt backup must not change live state.
if color restore || color backup extra || color restore "$work/missing"; then exit 1; fi
mkdir "$rt.update-lock"
if color backup || color restore "$snapshot"; then exit 1; fi
rmdir "$rt.update-lock"
printf 'broken\n' > "$snapshot/color_roles.json"
if color restore "$snapshot"; then exit 1; fi
cmp "$work/changed" "$rt/color_roles.json"
cmp "$work/cache" "$rt/cache/roles.sh"
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
# A checksum-free retained runtime still must satisfy the current policy.
legacy=$(mktemp -d "$(dirname "$rt")/.color-backup.XXXXXXXX")
mkdir "$legacy/runtime"
jq '.[0].hex_value="#FFFFFF"' "$work/original" > "$legacy/runtime/color_roles.json"
if color restore "$legacy/runtime"; then exit 1; fi
cmp "$work/changed" "$rt/color_roles.json"
cmp "$work/cache" "$rt/cache/roles.sh"
# A symlinked snapshot must not be accepted.
cp "$work/original" "$legacy/runtime/color_roles.json"
ln -s "$legacy/runtime" "$snapshot/link"
if color restore "$snapshot/link"; then exit 1; fi
# Force restore promotion to fail, exercising the shared rollback path.
mkdir "$work/bin"
export COLOR_TEST_REAL_MV
COLOR_TEST_REAL_MV=$(command -v mv)
export COLOR_TEST_RUNTIME="$rt"
cat > "$work/bin/mv" <<'SH'
#!/usr/bin/env bash
if [ "$#" -eq 3 ] && [ "$1" = -- ] && [[ "$2" == */.color-update.*/runtime ]] &&
   [ "$3" = "$COLOR_TEST_RUNTIME" ]; then
  exit 1
fi
exec "$COLOR_TEST_REAL_MV" "$@"
SH
chmod +x "$work/bin/mv"
if PATH="$work/bin:$PATH" color restore "$legacy/runtime"; then exit 1; fi
cmp "$work/changed" "$rt/color_roles.json"
cmp "$work/cache" "$rt/cache/roles.sh"
[ ! -e "$rt.update-lock" ]
# Test a valid old-format snapshot, then a verified explicit backup.
color restore "$legacy/runtime"
cmp "$work/original" "$rt/color_roles.json"
if get_color_by_role test_custom; then exit 1; fi
color validate >/dev/null
cp "$work/original" "$snapshot/color_roles.json"
# Restore must also recover an invalid live configuration.
printf 'not json\n' > "$rt/color_roles.json"
if color backup; then exit 1; fi
color restore "$snapshot"
cmp "$work/original" "$rt/color_roles.json"
color validate >/dev/null
[ "$COLOR_SYSTEM_READY" -eq 1 ]
[ -n "$(get_color_by_role prompt)" ]
cmp "$work/aliases" "$HOME/.bash_aliases"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/version" "$rt/.version"
cmp "$work/policy" "$rt/laws/color/color-laws.json"
[ "$(cat "$rt/unrelated")" = unrelated ]
[ ! -e "$rt.update-lock" ]
printf 'CLI configuration recovery contract passed.\n'
