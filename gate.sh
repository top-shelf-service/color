#!/usr/bin/env bash
# Acceptance gate for the colour role system.
#
# Every case runs against a throwaway $HOME under /tmp. Nothing touches your
# real environment.
#
# Requires: bash, jq. Optional: shellcheck, python3+pyyaml (those cases report
# SKIP rather than FAIL when the tool is absent, so a missing linter never
# looks like a broken product).
#
#   ./gate.sh              run everything
#   ./gate.sh --plain      no spinner or colour (for CI logs)
#   ./gate.sh -v           show output of failing cases in full

cd "$(dirname "$(readlink -f "$0")")" || exit 1

PLAIN=false
VERBOSE=false
for a in "$@"; do
  case "$a" in
    --plain) PLAIN=true ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
[ -t 1 ] || PLAIN=true

if $PLAIN; then
  G=''; R=''; Y=''; B=''; DIM=''; NC=''
else
  G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; B='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
fi

TOTAL=37
n=0; pass=0; fail=0; skip=0
declare -a FAILED=()
START=$(date +%s)

# Log path: one per run, so parallel runs don't clobber each other.
GATE_LOG="$(mktemp)"
trap 'rm -f "$GATE_LOG"' EXIT

hms() { local s=$1; printf '%dm%02ds' $((s/60)) $((s%60)); }

bar() {   # bar <done> <total> <width>
  local done=$1 total=$2 width=${3:-24}
  local filled=$(( done * width / total ))
  local i out=''
  for ((i=0; i<width; i++)); do
    if [ $i -lt $filled ]; then out+='#'; else out+='.'; fi
  done
  printf '%s' "$out"
}

status() {  # transient line while a case runs
  $PLAIN && return 0
  printf '\r\033[K%b[%s]%b %2d/%d  %brunning%b %s %b(%s)%b' \
    "$B" "$(bar "$n" "$TOTAL")" "$NC" "$n" "$TOTAL" \
    "$DIM" "$NC" "$1" "$DIM" "$(hms $(( $(date +%s) - START )))" "$NC"
}

emit() {  # emit <symbol> <colour> <name> <extra>
  $PLAIN || printf '\r\033[K'
  printf '%b%s%b %2d/%d  %-46s %b%s%b\n' \
    "$2" "$1" "$NC" "$n" "$TOTAL" "$3" "$DIM" "${4:-}" "$NC"
}

t() {
  local name="$1"; shift
  n=$((n+1))
  status "$name"
  local t0 t1
  t0=$(date +%s%N)
  if "$@" >"$GATE_LOG" 2>&1; then
    t1=$(date +%s%N)
    emit "PASS" "$G" "$name" "$(( (t1-t0)/1000000 ))ms"
    pass=$((pass+1))
  else
    t1=$(date +%s%N)
    emit "FAIL" "$R" "$name" "$(( (t1-t0)/1000000 ))ms"
    FAILED+=("$name")
    if $VERBOSE; then sed 's/^/        /' "$GATE_LOG"
    else tail -4 "$GATE_LOG" | sed 's/^/        /'; fi
    fail=$((fail+1))
  fi
}

t_skip() {  # t_skip <name> <reason>
  n=$((n+1))
  emit "SKIP" "$Y" "$1" "$2"
  skip=$((skip+1))
}

section() { $PLAIN || printf '\r\033[K'; printf '\n%b== %s ==%b\n' "$B" "$1" "$NC"; }

# ---------------------------------------------------------------- helpers ---
# Every invocation runs through CLEAN so an inherited COLOR_* from the parent
# shell cannot redirect a case at the real schema instead of the temp one.
CLEAN=(env -u COLOR_RUNTIME_HOME -u COLOR_ROLE_SCHEMA_PATH -u COLOR_LAWS_PATH
       -u COLOR_PROMPT_DISABLE -u COLOR_QUIET)

newhome() { H=$(mktemp -d); RT="$H/.local/share/tss/color"; }
inst()  { "${CLEAN[@]}" HOME="$H" ./install.sh "$@" >/dev/null 2>&1; }
hook()  { "${CLEAN[@]}" HOME="$H" "$RT/install_hook.sh" "$@"; }
valid() { "${CLEAN[@]}" "$RT/validate_color_roles.sh" --quiet "$RT/color_roles.json" "$RT/laws/color/color-laws.json"; }
corrupt() { jq "$1" "$RT/color_roles.json" > "$H/x" && mv "$H/x" "$RT/color_roles.json"; }

# Build a PATH holding the coreutils the loader needs but deliberately NOT jq.
# Hardcoding PATH=/usr/bin:/bin does not work: on Debian jq lives in /usr/bin
# alongside everything else, so it stays visible and the case is meaningless.
make_jqless_path() {
  local d; d=$(mktemp -d)
  local tool src
  for tool in bash readlink dirname mkdir mktemp mv cat sort rm cp basename; do
    src=$(command -v "$tool" 2>/dev/null) && ln -sf "$src" "$d/$tool"
  done
  printf '%s' "$d"
}

command -v jq >/dev/null 2>&1 || { echo "jq is required to run this gate." >&2; exit 2; }
HAVE_SHELLCHECK=false; command -v shellcheck >/dev/null 2>&1 && HAVE_SHELLCHECK=true
HAVE_YAML=false; python3 -c "import yaml" >/dev/null 2>&1 && HAVE_YAML=true

printf '%bColour role system — acceptance gate%b\n' "$B" "$NC"
printf '%b%s%b\n' "$DIM" "$(pwd)" "$NC"

# ------------------------------------------------------------------ static --
section "STATIC"
if $HAVE_YAML; then
  t "workflow YAML parses" python3 -c "import yaml;yaml.safe_load(open('.github/workflows/main.yaml'))"
else
  t_skip "workflow YAML parses" "no pyyaml — see note at end"
fi
# Must mirror the CI invocation exactly, including severity. Running -S warning
# here while CI runs the default hid SC1091/SC2009/SC2015/SC2016 until CI failed.
c_lint() {
  local -a files
  if git rev-parse --git-dir >/dev/null 2>&1; then
    mapfile -t files < <(git ls-files '*.sh')
  else
    # No git checkout (e.g. the Docker image, a zip/rsync copy): approximate
    # `git ls-files` with find, but skip hidden directories — that is where
    # the installed runtime and its generated cache live, and linting
    # generated files fails the gate on files that are not repo sources.
    mapfile -t files < <(find . -name '*.sh' -not -path './.*' | sed 's|^\./||')
  fi
  shellcheck "${files[@]}" \
    ctl_environment_template/install_hook.sh.template \
    ctl_environment_template/colors.source.sh.template
}
if $HAVE_SHELLCHECK; then t "shellcheck clean repo-wide" c_lint
else t_skip "shellcheck clean repo-wide" "shellcheck not installed"; fi
c_json() {
  local rc=0 f
  while IFS= read -r -d '' f; do
    jq -e . "$f" >/dev/null 2>&1 || { echo "invalid JSON: $f"; rc=1; }
  done < <(find . -name '*.json.template' -print0)
  return $rc
}
t "all JSON templates valid" c_json
t "shipped palette obeys laws" ./validate_color_roles.sh --quiet \
    ctl_environment_template/color_roles.json.template \
    ctl_environment_template/laws/color/color-laws.json.template

# Enforcement must be tested from the negative side. Twice now a refactor has
# left a law silently not firing while the positive case still passed.
c_laws() {
  local R=ctl_environment_template/color_roles.json.template
  local L=ctl_environment_template/laws/color/color-laws.json.template
  local rc=0 name filter tmp
  local -a cases=(
    "pure white|.[0].hex_value=\"#FFFFFF\""
    "pure black|.[0].hex_value=\"#000000\""
    "too dark|.[0].hex_value=\"#0A0A0A\""
    "too bright|.[0].hex_value=\"#FAFAFA\""
    "malformed hex|.[0].hex_value=\"#GGG\""
    "duplicate role|. + [.[0]]"
    "missing required role|map(select(.role!=\"prompt\"))"
    "two missing required roles|map(select(.role!=\"prompt\" and .role!=\"errors\"))"
    "missing field|.[0] |= del(.hierarchy)"
    "bad hierarchy|.[0].hierarchy=\"wizard\""
    "empty category|.[0].category=\"\""
    "low contrast on dark bg|.[0].hex_value=\"#4169E1\""
  )
  for entry in "${cases[@]}"; do
    name="${entry%%|*}"; filter="${entry#*|}"
    tmp=$(mktemp); jq "$filter" "$R" > "$tmp"
    if ./validate_color_roles.sh --quiet "$tmp" "$L" >/dev/null 2>&1; then
      echo "law NOT enforced: $name"; rc=1
    fi
    rm -f "$tmp"
  done
  tmp=$(mktemp)
  jq '.[1].hex_value = .[0].hex_value' "$R" > "$tmp"
  ./validate_color_roles.sh --quiet "$tmp" "$L" >/dev/null 2>&1 || { echo "duplicate hex should be advisory by default"; rc=1; }
  ./validate_color_roles.sh --strict --quiet "$tmp" "$L" >/dev/null 2>&1 && { echo "--strict did not flag duplicate hex"; rc=1; }
  rm -f "$tmp"
  return $rc
}
t "every law rejects a violation" c_laws

c_contrast() {
  # Every generated colour must clear the contrast floor, not just the ones
  # shipped in the template.
  newhome; inst
  local i
  for i in $(seq 1 12); do hook "gen$i" deployment child >/dev/null 2>&1 || return 1; done
  valid || return 1
  # and an explicit low-contrast request must be refused
  hook toodark infra parent --hex '#4169E1' >/dev/null 2>&1 && return 1
  return 0
}
t "generated colours meet the contrast floor" c_contrast

# ----------------------------------------------------------------- install --
section "INSTALL"
c1() { newhome; inst; }
t "fresh install" c1
c2() { newhome; inst && inst && inst; }
t "idempotent x3" c2
c3() { newhome; inst; local a; a=$(wc -l < "$H/.bashrc"); inst; inst; [ "$a" = "$(wc -l < "$H/.bashrc")" ]; }
t "no .bashrc growth on re-run" c3
c4() { newhome; HOME="$H" ./install.sh --runtime-dir "$H/custom/rt" >/dev/null 2>&1 && [ -f "$H/custom/rt/colors.source.sh" ]; }
t "custom --runtime-dir honoured" c4
c5() { newhome; printf 'export FOO=keepme\n' > "$H/.bashrc"; inst; inst; grep -q 'export FOO=keepme' "$H/.bashrc"; }
t "unmanaged .bashrc lines preserved" c5

# ---------------------------------------------------------------- contract --
section "CONTRACT"
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c6() { newhome; inst; rm -f "$H/ctl_environment" "$H/.color_roles.json"
       "${CLEAN[@]}" HOME="$H" bash -c 'unset COLOR_RUNTIME_HOME; . "$HOME/.local/share/tss/color/colors.source.sh"; [ "$COLOR_SYSTEM_READY" = 1 ] && get_color_by_role prompt >/dev/null'; }
t "loader works with compat links DELETED" c6
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c7() { newhome; inst; mv "$RT" "$H/moved"
       "${CLEAN[@]}" HOME="$H" bash -c 'unset COLOR_RUNTIME_HOME; . "$HOME/moved/colors.source.sh"; [ "$COLOR_SYSTEM_READY" = 1 ]'; }
t "loader works from a relocated runtime" c7
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c8() { newhome; inst
       local p; p=$(make_jqless_path)
       "${CLEAN[@]}" HOME="$H" PATH="$p" "$(command -v bash)" -c '
         command -v jq >/dev/null && exit 1
         . "$HOME/.local/share/tss/color/colors.source.sh" 2>/dev/null
         [ "$COLOR_SYSTEM_READY" = 1 ] && color_apply success ok >/dev/null'
       local rc=$?; rm -rf "$p"; return $rc; }
t "shell start needs no jq (cache hit)" c8
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c9() { newhome; inst; rm -rf "$RT/cache"
       "${CLEAN[@]}" HOME="$H" bash -c '. "$HOME/.local/share/tss/color/colors.source.sh"; [ "$COLOR_SYSTEM_READY" = 1 ]'; }
t "cache is rebuilt if deleted" c9
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c10() { newhome; inst; printf 'not json' > "$RT/color_roles.json"
        "${CLEAN[@]}" HOME="$H" bash -c '. "$HOME/.local/share/tss/color/colors.source.sh" 2>/dev/null; true'; }
t "broken schema does not kill the shell" c10

# ------------------------------------------------------------- enforcement --
section "ENFORCEMENT"
c11() { newhome; inst; corrupt '.[0].hex_value="#FFFFFF"'; ! inst; }
t "reinstall FAILS on illegal schema" c11
c12() { newhome; inst; corrupt '.[0].hex_value="#FFFFFF"'; inst --force && valid; }
t "--force resets an illegal schema" c12
c13() { newhome; inst; ! hook bad infra parent --hex '#FFFFFF' >/dev/null 2>&1; }
t "hook rejects illegal --hex" c13
c14() { newhome; inst; cp "$RT/color_roles.json" "$H/before"
        hook bad infra parent --hex '#000000' >/dev/null 2>&1
        cmp -s "$H/before" "$RT/color_roles.json"; }
t "rejected hook leaves schema byte-identical" c14
c15() { newhome; inst; ! hook bad infra wizard >/dev/null 2>&1; }
t "hook rejects hierarchy outside vocabulary" c15
c16() { newhome; inst; hook myapp deployment child >/dev/null 2>&1 && [ "$(jq length "$RT/color_roles.json")" = 12 ]; }
t "hook registers a legal role" c16
c17() { newhome; inst; hook myapp deployment child >/dev/null 2>&1; [ -L "$H/.color_roles.json" ]; }
t "hook preserves the symlink" c17
c18() { newhome; inst; local i; for i in $(seq 1 20); do hook "app$i" deployment child >/dev/null 2>&1 || return 1; done; valid; }
t "20 generated colours all obey laws" c18
c19() { newhome; inst; hook myapp deployment child >/dev/null 2>&1; inst
        [ "$(jq -r 'any(.[]; .role == "myapp")' "$RT/color_roles.json")" = true ]; }
t "custom roles survive reinstall" c19
# shellcheck disable=SC2016  # single quotes are deliberate: bash -c payload
c20() { newhome; inst; hook myapp deployment child >/dev/null 2>&1
        "${CLEAN[@]}" HOME="$H" bash -c '. "$HOME/.local/share/tss/color/colors.source.sh"; get_color_by_role myapp >/dev/null'; }
t "new role visible after reload" c20

c20b() { newhome; inst
         # Poison the environment the way a loaded shell would, pointing at a
         # schema that already contains the role we are about to register.
         local decoy="$H/decoy.json"
         jq '. + [{role:"myapp",category:"x",color_code:"C",hex_value:"#7FB3F5",hierarchy:"child"}]' \
            "$RT/color_roles.json" > "$decoy"
         COLOR_ROLE_SCHEMA_PATH="$decoy" COLOR_RUNTIME_HOME="$H/nowhere" \
           "${CLEAN[@]}" HOME="$H" "$RT/install_hook.sh" myapp deployment child >/dev/null 2>&1
         [ "$(jq -r 'any(.[]; .role == "myapp")' "$RT/color_roles.json")" = true ]; }
t "hook immune to inherited COLOR_* env" c20b

# ---------------------------------------------------------------- selfheal --
section "SELF-HEAL"
c21() { newhome; inst; rm -f "$RT/colors.source.sh" "$RT/install_hook.sh"; inst && [ -x "$RT/install_hook.sh" ]; }
t "missing code files restored" c21
c22() { newhome; inst; rm -f "$H/ctl_environment"; inst && [ -L "$H/ctl_environment" ]; }
t "broken compat link repaired" c22
c23() { newhome; mkdir -p "$H/ctl_environment"
        cp ctl_environment_template/color_roles.json.template "$H/ctl_environment/color_roles.json"
        jq '. + [{role:"legacyapp",category:"x",color_code:"C",hex_value:"#7FB3F5",hierarchy:"child"}]' \
          "$H/ctl_environment/color_roles.json" > "$H/y" && mv "$H/y" "$H/ctl_environment/color_roles.json"
        inst && [ "$(jq -r 'any(.[]; .role == "legacyapp")' "$RT/color_roles.json")" = true ]; }
t "pre-3.0 layout migrates, roles kept" c23

c23b() { newhome; mkdir -p "$H/ctl_environment"
         jq '. + [{role:"legacydark",category:"x",color_code:"C",hex_value:"#4169E1",hierarchy:"child"}]' \
           ctl_environment_template/color_roles.json.template > "$H/ctl_environment/color_roles.json"
         inst && return 1                       # must fail closed
         inst --force || return 1               # --force is the documented way out
         valid; }
t "legacy low-contrast role fails closed" c23b

# --------------------------------------------------------------- uninstall --
section "UNINSTALL"
c24() { newhome; inst; HOME="$H" ./uninstall.sh -y >/dev/null 2>&1
        [ ! -d "$RT" ] && [ ! -e "$H/ctl_environment" ] && [ ! -e "$H/.color_roles.json" ]; }
t "removes runtime and both compat links" c24
c25() { newhome; printf 'export FOO=keepme\n' > "$H/.bashrc"; inst
        "${CLEAN[@]}" HOME="$H" ./uninstall.sh -y >/dev/null 2>&1
        grep -q 'export FOO=keepme' "$H/.bashrc" && ! grep -q 'COLOR_RUNTIME_HOME' "$H/.bashrc"; }
t "strips only the managed block" c25
c26() { newhome; inst; HOME="$H" ./uninstall.sh -y >/dev/null 2>&1; inst && valid; }
t "install after uninstall works" c26
c27() { newhome; inst --runtime-dir "$H/custom/rt"; HOME="$H" ./uninstall.sh -y >/dev/null 2>&1
        [ ! -d "$H/custom/rt" ]; }
t "uninstall finds a custom runtime dir" c27

# Regression: light background must not make the hook reject dark roles.
# The emit once produced only a lighter-side threshold, which is impossible
# against a white background, so the hook refused every colour. The fix emits
# a darker-side bound too; this case proves a dark role registers.
c28() { newhome; inst
        jq '.rules.require_contrast_ratio.background = "#FFFFFF"' "$RT/laws/color/color-laws.json" > "$H/laws.json" && mv "$H/laws.json" "$RT/laws/color/color-laws.json"
        jq 'map(.hex_value = "#1E1E1E")' "$RT/color_roles.json" > "$H/dark.json"
        HOME="$H" COLOR_ROLE_SCHEMA_PATH="$H/dark.json" COLOR_RUNTIME_HOME="$RT" \
          "$RT/install_hook.sh" newrole deployment child --hex '#2A2A2A' >/dev/null 2>&1 &&
        [ "$(jq -r 'any(.[]; .role == "newrole")' "$H/dark.json")" = true ]; }
t "hook registers a dark role against a light background" c28

section "FILESYSTEM RENDERING"
c29() { newhome; inst && "${CLEAN[@]}" HOME="$H" bash scripts/test-filesystem-rendering.sh "$RT/colors.source.sh"; }
t "semantic filenames and classification symbols" c29

# ----------------------------------------------------------------- summary --
ELAPSED=$(( $(date +%s) - START ))
$PLAIN || printf '\r\033[K'
echo
printf '%b[%s]%b  %d passed' "$B" "$(bar "$n" "$TOTAL" 30)" "$NC" "$pass"
[ "$fail" -gt 0 ] && printf ', %b%d failed%b' "$R" "$fail" "$NC"
[ "$skip" -gt 0 ] && printf ', %b%d skipped%b' "$Y" "$skip" "$NC"
printf '   %bin %s%b\n' "$DIM" "$(hms $ELAPSED)" "$NC"

if [ "$fail" -gt 0 ]; then
  echo
  printf '%bFailed:%b\n' "$R" "$NC"
  for f in "${FAILED[@]}"; do echo "  - $f"; done
fi

if ! $HAVE_YAML || ! $HAVE_SHELLCHECK; then
  echo
  printf '%bSkipped cases need optional tools:%b\n' "$Y" "$NC"
  $HAVE_YAML      || echo "  pyyaml      sudo apt-get install -y python3-yaml"
  $HAVE_SHELLCHECK|| echo "  shellcheck  sudo apt-get install -y shellcheck"
  echo "  These lint the repo; skipping them does not affect whether the"
  echo "  colour system itself works."
fi

[ "$fail" -eq 0 ]
