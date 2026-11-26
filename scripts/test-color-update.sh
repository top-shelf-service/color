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
[ "$(color version)" = 3.4.0 ]
color list > "$work/list"
grep -q directory "$work/list"
color validate >/dev/null
if color nonexistent || color update extra; then exit 1; fi
# Lookup uses the installed canonical bytes and never mutates role or shell data.
cmp "$work/checkout/docs/vocabulary.json" "$rt/vocabulary.json"
cp "$rt/vocabulary.json" "$work/original-vocabulary"
cp "$rt/color_roles.json" "$work/lookup-roles"
cp "$HOME/.bash_aliases" "$work/lookup-aliases"
cp "$HOME/.bashrc" "$work/lookup-bashrc"
color man file > "$work/term"
grep -Fxq 'file [filesystem]' "$work/term"
grep -Fq 'Meaning:' "$work/term"
grep -Fq 'Example: README.md' "$work/term"
grep -Fq 'Color roles: files' "$work/term"
color man 'REGULAR FILE' > "$work/alias"
cmp "$work/term" "$work/alias"
color man 'symbolic-link' > "$work/term"
color man symlink > "$work/alias"
cmp "$work/term" "$work/alias"
grep -Fq 'Color roles: links' "$work/term"
color man > "$work/manual"
grep -Fq '=== Filesystem and storage ===' "$work/manual"
grep -Fq 'Example: README.md' "$work/manual"
color search 'regular file' > "$work/search"
grep -q '^file —' "$work/search"
color search 'SYMLINK' > "$work/search"
grep -q '^symbolic_link —' "$work/search"
reject() {
  local expected="$1" actual=0
  shift
  color "$@" > "$work/reject-out" 2> "$work/reject-err" || actual=$?
  [ "$actual" -eq "$expected" ] && [ ! -s "$work/reject-out" ] && [ -s "$work/reject-err" ]
}
reject 1 man no_such_color_term_987
grep -Fq 'unknown term' "$work/reject-err"
reject 1 search no_such_color_term_987
grep -Fq 'no matches' "$work/reject-err"
reject 1 search '"; error("injected"); #'
reject 2 man file extra
reject 2 man ''
reject 2 search
reject 2 search '   '
reject 2 search file extra
reject 2 version extra
cmp "$work/lookup-roles" "$rt/color_roles.json"
cmp "$work/lookup-aliases" "$HOME/.bash_aliases"
cmp "$work/lookup-bashrc" "$HOME/.bashrc"
cmp "$work/original-vocabulary" "$rt/vocabulary.json"
# Missing data fails rather than falling back to the checkout.
mv "$rt/vocabulary.json" "$work/missing-vocabulary"
reject 1 man file
grep -Fq 'installed vocabulary unavailable' "$work/reject-err"
mv "$work/missing-vocabulary" "$rt/vocabulary.json"
"$rt/install_hook.sh" test_custom test child --hex '#FFAA55' >/dev/null
cp "$rt/color_roles.json" "$work/roles"
cp "$HOME/.bashrc" "$work/bashrc"
cp "$HOME/.bash_aliases" "$work/aliases"
# Doctor is observational; repair/reload share the transaction lock.
color reload
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
cp -a "$rt" "$work/doctor-original"
cache_stat=$(stat -c '%i:%s:%y' "$rt/cache/roles.sh")
color doctor > "$work/doctor"
grep -Fq 'HEALTHY' "$work/doctor"
diff -qr "$work/doctor-original" "$rt"
[ "$(stat -c '%i:%s:%y' "$rt/cache/roles.sh")" = "$cache_stat" ]
[ ! -e "$rt.update-lock" ]
reject 2 doctor extra
reject 2 doctor --fix extra
reject 2 reload extra
rm "$rt/cache/roles.sh"
status=0
color doctor > "$work/doctor" 2>&1 || status=$?
[ "$status" -eq 3 ]
grep -Fq 'REPAIRABLE' "$work/doctor"
[ ! -e "$rt/cache/roles.sh" ] && [ ! -e "$rt.update-lock" ]
color doctor --fix
cmp "$work/doctor-original/cache/roles.sh" "$rt/cache/roles.sh"
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
# Byte drift even with a current timestamp/header must not be sourced.
printf 'touch %q\n' "$work/unsafe-cache-executed" >> "$rt/cache/roles.sh"
cp "$rt/cache/roles.sh" "$work/corrupt-cache"
status=0
color doctor > "$work/doctor" 2>&1 || status=$?
[ "$status" -eq 3 ]
cmp "$work/corrupt-cache" "$rt/cache/roles.sh"
[ ! -e "$work/unsafe-cache-executed" ]
color reload
[ ! -e "$work/unsafe-cache-executed" ]
cmp "$work/doctor-original/cache/roles.sh" "$rt/cache/roles.sh"
# Prove reload updates the calling shell even when cache bytes are current.
unset 'COLOR_ROLE_HEX[test_custom]'
if get_color_by_role test_custom; then exit 1; fi
color_reload > "$work/legacy-reload" 2>&1
[ ! -s "$work/legacy-reload" ]
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
# Legacy reload must also be silent when it repairs a missing cache.
rm "$rt/cache/roles.sh"
color_reload > "$work/legacy-reload" 2>&1
[ ! -s "$work/legacy-reload" ]
cmp "$work/doctor-original/cache/roles.sh" "$rt/cache/roles.sh"
[ "$(get_color_by_role test_custom)" = '#FFAA55' ]
# Unknown conditions are not repair authorization.
doctor_refuses() {
  local status=0
  color doctor > "$work/doctor" 2>&1 || status=$?
  [ "$status" -eq 1 ]
  grep -Fq 'UNKNOWN' "$work/doctor"
  if color doctor --fix || color reload; then
    echo 'Unsafe repair/reload accepted' >&2
    exit 1
  fi
}
mkdir "$rt.update-lock"
doctor_refuses
if color_reload > "$work/legacy-reload" 2>&1; then exit 1; fi
grep -Fq "owns the lock" "$work/legacy-reload"
[ -d "$rt.update-lock" ]
rmdir "$rt.update-lock"
mv "$rt/colors.source.sh" "$work/missing-loader"
doctor_refuses
[ ! -e "$rt/colors.source.sh" ]
mv "$work/missing-loader" "$rt/colors.source.sh"
mv "$rt/laws/color/color-laws.json" "$work/missing-laws"
doctor_refuses
[ ! -e "$rt/laws/color/color-laws.json" ]
mv "$work/missing-laws" "$rt/laws/color/color-laws.json"
printf '%s\n' '{broken' > "$rt/color_roles.json"
doctor_refuses
grep -Fxq '{broken' "$rt/color_roles.json"
cmp "$work/doctor-original/cache/roles.sh" "$rt/cache/roles.sh"
cp -p "$work/roles" "$rt/color_roles.json"
mv "$rt/cache/roles.sh" "$work/outside-cache"
ln -s "$work/outside-cache" "$rt/cache/roles.sh"
doctor_refuses
[ -L "$rt/cache/roles.sh" ]
cmp "$work/doctor-original/cache/roles.sh" "$work/outside-cache"
rm "$rt/cache/roles.sh"
mv "$work/outside-cache" "$rt/cache/roles.sh"
color reload
diff -qr "$work/doctor-original" "$rt"
cmp "$work/roles" "$rt/color_roles.json"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/aliases" "$HOME/.bash_aliases"
[ ! -e "$rt.update-lock" ]
printf 'CLI diagnostics and safe cache repair contract passed.\n'
sed -i 's/VERSION="3.4.0"/VERSION="3.4.1"/' "$work/upstream/install.sh"
# Change the reference in the candidate, not the trusted checkout.
jq '(.terms[] | select(.id == "file") | .example) = "updated-reference-fixture.txt"' \
  "$work/upstream/docs/vocabulary.json" > "$work/updated-vocabulary"
cp "$work/updated-vocabulary" "$work/upstream/docs/vocabulary.json"
git -C "$work/upstream" add install.sh docs/vocabulary.json
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm update
color update
[ "$(color version)" = 3.4.1 ]
cmp "$work/updated-vocabulary" "$rt/vocabulary.json"
cmp "$work/original-vocabulary" "$work/checkout/docs/vocabulary.json"
color man file > "$work/updated-man"
grep -Fq 'Example: updated-reference-fixture.txt' "$work/updated-man"
cmp "$work/roles" "$rt/color_roles.json"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/aliases" "$HOME/.bash_aliases"
color update > "$work/repeat"
grep -q 'already current' "$work/repeat"
# A second updater must refuse while the lock is held.
mkdir "$rt.update-lock"
if color update; then echo 'Concurrent update accepted' >&2; exit 1; fi
rmdir "$rt.update-lock"
# Force the promotion rename to fail, after the old runtime has been moved.
sed -i 's/VERSION="3.4.1"/VERSION="3.4.2"/' "$work/upstream/install.sh"
git -C "$work/upstream" add install.sh
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm promotion
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
if PATH="$work/bin:$PATH" color update; then echo 'Failed promotion reported success' >&2; exit 1; fi
[ "$(color version)" = 3.4.1 ]
cmp "$work/roles" "$rt/color_roles.json"
color validate >/dev/null
[ ! -e "$rt.update-lock" ]
cmp "$work/updated-vocabulary" "$rt/vocabulary.json"
# A malformed reference package must not replace the accepted runtime.
printf '%s\n' '{broken' > "$work/upstream/docs/vocabulary.json"
git -C "$work/upstream" add docs/vocabulary.json
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm malformed-vocabulary
if color update; then echo 'Invalid vocabulary update accepted' >&2; exit 1; fi
[ "$(color version)" = 3.4.1 ]
cmp "$work/updated-vocabulary" "$rt/vocabulary.json"
cmp "$work/roles" "$rt/color_roles.json"
[ ! -e "$rt.update-lock" ]
cp "$work/updated-vocabulary" "$work/upstream/docs/vocabulary.json"
# A candidate with a stricter policy rejects the current roles.
laws="$work/upstream/ctl_environment_template/laws/color/color-laws.json.template"
jq '.rules.require_contrast_ratio.min_ratio = 21' "$laws" > "$work/laws"
mv "$work/laws" "$laws"
git -C "$work/upstream" add .
git -C "$work/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm rejected
if color update; then echo 'Invalid update accepted' >&2; exit 1; fi
[ "$(color version)" = 3.4.1 ]
cmp "$work/roles" "$rt/color_roles.json"
cmp "$work/bashrc" "$HOME/.bashrc"
cmp "$work/aliases" "$HOME/.bash_aliases"
color validate >/dev/null
cmp "$work/updated-vocabulary" "$rt/vocabulary.json"
printf 'CLI vocabulary and update contracts passed.\n'
