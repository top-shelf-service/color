#!/usr/bin/env bash
# Isolated role contract, including direct hook lock coordination.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_DATA_HOME="$work/home/data" COLOR_PROMPT_DISABLE=1
unset COLOR_RUNTIME_HOME COLOR_ROLE_SCHEMA_PATH COLOR_LAWS_PATH
mkdir -p "$HOME"
./install.sh >/dev/null
rt="$XDG_DATA_HOME/tss/color"
# shellcheck source=/dev/null
. "$rt/colors.source.sh"
schema="$rt/color_roles.json"
cache="$rt/cache/roles.sh"
hook="$rt/install_hook.sh"
cp "$schema" "$work/builtins"

color show directory | jq -e '.role == "directory" and .source_type == "static"' >/dev/null
if color show missing >/dev/null 2>&1; then exit 1; fi
color add app_test deployment child --hex '#FFAA55'
[ "$(get_color_by_role app_test)" = '#FFAA55' ]
jq -e --slurpfile old "$work/builtins" 'map(select(.role != "app_test")) == $old[0]' "$schema" >/dev/null
color edit app_test '#42B3FF'
[ "$(get_color_by_role app_test)" = '#42B3FF' ]
color edit app_test operations alert --hex '#FFAA55'
color show app_test | jq -e '.category == "operations" and .hierarchy == "alert" and .source_type == "dynamic"' >/dev/null
# Built-in identity metadata remains intact when explicitly recoloured.
color edit directory '#FFAA55'
jq -e --slurpfile old "$work/builtins" 'map(select(.role == "directory"))[0] == ($old[0][0] + {hex_value:"#FFAA55"})' "$schema" >/dev/null
cp "$schema" "$work/before"
cp "$cache" "$work/cache"
reject() {
  if "$@" >/dev/null 2>&1; then printf 'Unexpected acceptance: %s\n' "$*" >&2; exit 1; fi
  cmp "$work/before" "$schema"
  cmp "$work/cache" "$cache"
}
reject color add app_test deployment child --hex '#42B3FF'
reject color edit nonexistent '#FFAA55'
reject color add bad deployment invalid --hex '#FFAA55'
reject color add bad deployment child --hex '#FFFFFF'
reject color add bad deployment child --hex ''
reject color add 'bad name' deployment child --hex '#FFAA55'
reject color add APP_TEST deployment child --hex '#FFAA55'
reject color edit app_test '#GGGGGG'
reject color edit app_test '#000000'
reject color preview nonexistent '#FFAA55'
reject color preview app_test '#FFFFFF'
[ "$(color preview app_test '#42B3FF')" = 'app_test #42B3FF' ]
[ "$(get_color_by_role app_test)" = '#FFAA55' ]
cmp "$work/before" "$schema"
cmp "$work/cache" "$cache"
mkdir "$rt.update-lock"
reject color add locked deployment child --hex '#FFAA55'
reject "$hook" locked deployment child --hex '#FFAA55'
reject color preview app_test '#42B3FF'
rmdir "$rt.update-lock"

# Inject failure ONLY for the post-promotion validation of a changed live file.
mv "$rt/validate_color_roles.sh" "$rt/validator-real"
cat > "$rt/validate_color_roles.sh" <<'MOCK'
#!/usr/bin/env bash
rt="$(dirname "$0")"
if [ "$1" = --quiet ] && [ "$2" = "$rt/color_roles.json" ] &&
   jq -e 'any(.[]; .role == "rollback_test")' "$2" >/dev/null; then
  exit 1
fi
exec "$rt/validator-real" "$@"
MOCK
chmod +x "$rt/validate_color_roles.sh"
reject color add rollback_test deployment child --hex '#FFAA55'
[ ! -e "$rt.update-lock" ]
mv "$rt/validator-real" "$rt/validate_color_roles.sh"
color validate >/dev/null
color doctor >/dev/null
printf 'CLI role management contract passed.\n'
