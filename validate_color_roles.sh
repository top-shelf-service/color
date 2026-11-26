#!/usr/bin/env bash
# validate_color_roles.sh
#
# The single enforcement engine for the colour policy. Every rule comes from
# color-laws.json; nothing is hardcoded here except the fallback used when no
# laws file can be found. install.sh and install_hook.sh both call this rather
# than reimplementing checks, so there is exactly one place where policy lives.
#
# Usage:
#   validate_color_roles.sh [--strict] [--quiet] [ROLES_JSON] [LAWS_JSON]
#
# Exit codes:
#   0  schema satisfies policy
#   1  policy violation
#   2  usage / missing dependency / unreadable input

set -euo pipefail

STRICT=false
QUIET=false
EMIT=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=true ;;
    --quiet)  QUIET=true ;;
    --emit-constraints) EMIT=true; QUIET=true ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *)  ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# Runtime home is derived from this script's own location when it is running
# from inside a deployed runtime; otherwise it falls back to the env/default.
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_RUNTIME="${COLOR_RUNTIME_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/tss/color}"
if [ -f "$SELF_DIR/color_roles.json" ]; then
  DEFAULT_RUNTIME="$SELF_DIR"
fi

ROLES="${1:-$DEFAULT_RUNTIME/color_roles.json}"
LAWS="${2:-$DEFAULT_RUNTIME/laws/color/color-laws.json}"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
say()     { $QUIET || echo -e "$1"; }
info()    { say "${BLUE}[INFO]${NC} $1"; }
success() { say "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

command -v jq >/dev/null 2>&1 || { error "jq is required."; exit 2; }
[ -e "$ROLES" ] || { error "Roles file not found: $ROLES"; exit 2; }
ROLES="$(readlink -f "$ROLES")"

jq empty "$ROLES" >/dev/null 2>&1 || { error "Roles file is not valid JSON: $ROLES"; exit 1; }
[ "$(jq -r 'type' "$ROLES")" = "array" ] || { error "Roles file must be a JSON array."; exit 1; }
jq -e 'all(.[]; type == "object")' "$ROLES" >/dev/null 2>&1 \
  || { error "Roles file entries must be objects (found a non-object entry)."; exit 1; }

# ---------- load policy ----------
if [ -f "$LAWS" ] && jq empty "$LAWS" >/dev/null 2>&1; then
  LAWS="$(readlink -f "$LAWS")"
  LAWS_VERSION="$(jq -r '.schema_version // 1' "$LAWS")"
  if [ "$LAWS_VERSION" -lt 2 ] 2>/dev/null; then
    warn "color-laws.json is v$LAWS_VERSION (legacy). Policy rules will use built-in defaults."
    warn "Re-run install.sh --force to upgrade the laws file to v2."
    LAWS=""
  fi
else
  [ -f "$LAWS" ] && warn "color-laws.json is not valid JSON: $LAWS"
  LAWS=""
fi

# One jq call reads the entire policy into shell variables. Doing this per
# rule cost ~14 forks before a single check ran.
load_policy() {
  if [ -z "$LAWS" ]; then
    R_HEXFMT=true; R_WHITE=true; R_BLACK=true; R_DUPROLE=true
    R_DUPHEX=false; R_RANGE=true; R_FIELDS=true; R_CONTRAST=true
    CONTRAST_BG='#1E1E1E'; CONTRAST_MIN=4.5
    CH_MIN=24; CH_MAX=247
    PATTERN='^#[0-9A-Fa-f]{6}$'; W='#FFFFFF'; B='#000000'
    HIER_STR='parent child cousin alert feedback language runtime'
    REQ_ROLE_STR='directory files scripts links prompt errors warnings success'
    REQ_FIELD_STR='role category hex_value hierarchy'
    return
  fi
  eval "$(jq -r '
    def b($r; $d): (.rules[$r].enabled // $d) | tostring;
    "R_HEXFMT=\(b("require_hex_format"; true))",
    "R_WHITE=\(b("forbid_pure_white"; true))",
    "R_BLACK=\(b("forbid_pure_black"; true))",
    "R_DUPROLE=\(b("forbid_duplicate_roles"; true))",
    "R_DUPHEX=\(b("forbid_duplicate_hex"; false))",
    "R_RANGE=\(b("require_luminance_range"; true))",
    "R_FIELDS=\(b("require_fields"; true))",
    "R_CONTRAST=\(b("require_contrast_ratio"; true))",
    "CONTRAST_BG=\((.rules.require_contrast_ratio.background // "#1E1E1E") | @sh)",
    "CONTRAST_MIN=\(.rules.require_contrast_ratio.min_ratio // 4.5)",
    "CH_MIN=\(.rules.require_luminance_range.min // 24)",
    "CH_MAX=\(.rules.require_luminance_range.max // 247)",
    "PATTERN=\((.rules.require_hex_format.pattern // "^#[0-9A-Fa-f]{6}$") | @sh)",
    "W=\((.rules.forbid_pure_white.value // "#FFFFFF") | @sh)",
    "B=\((.rules.forbid_pure_black.value // "#000000") | @sh)",
    "HIER_STR=\((.allowed_hierarchies // [] | join(" ")) | @sh)",
    "REQ_ROLE_STR=\((.required_roles // [] | join(" ")) | @sh)",
    "REQ_FIELD_STR=\((.rules.require_fields.fields // [] | join(" ")) | @sh)"
  ' "$LAWS")"
}
law_num() {   # retained for --emit-constraints
  [ -n "$LAWS" ] || { echo "$3"; return; }
  jq -r --arg r "$1" --arg f "$2" --arg d "$3" '.rules[$r][$f] // ($d|tonumber)' "$LAWS"
}
law_bool() {
  [ -n "$LAWS" ] || { echo "$2"; return; }
  jq -r --arg r "$1" --arg d "$2" '.rules[$r].enabled // ($d == "true")' "$LAWS"
}
law_list() {
  [ -n "$LAWS" ] || return 0
  jq -r --arg k "$1" '.[$k][]? // empty' "$LAWS"
}

if $EMIT; then
  # Machine-readable policy for callers that need to pre-filter candidates.
  # Rules still live in the laws file; only their extraction lives here.
  printf "COLOR_LAW_HEX_PATTERN=%s\n" \
    "$([ -n "$LAWS" ] && jq -r '.rules.require_hex_format.pattern // "^#[0-9A-Fa-f]{6}$"' "$LAWS" || echo '^#[0-9A-Fa-f]{6}$')"
  printf "COLOR_LAW_FORBID_WHITE=%s\n" \
    "$([ -n "$LAWS" ] && jq -r 'if .rules.forbid_pure_white.enabled != false then (.rules.forbid_pure_white.value // "#FFFFFF") else "" end' "$LAWS" || echo '#FFFFFF')"
  printf "COLOR_LAW_FORBID_BLACK=%s\n" \
    "$([ -n "$LAWS" ] && jq -r 'if .rules.forbid_pure_black.enabled != false then (.rules.forbid_pure_black.value // "#000000") else "" end' "$LAWS" || echo '#000000')"
  printf "COLOR_LAW_LUM_MIN=%s\n" "$(law_num require_luminance_range min 24)"
  printf "COLOR_LAW_LUM_MAX=%s\n" "$(law_num require_luminance_range max 247)"
  printf "COLOR_LAW_LUM_ENABLED=%s\n" "$(law_bool require_luminance_range true)"
  printf "COLOR_LAW_DUP_HEX=%s\n" "$(law_bool forbid_duplicate_hex false)"
  printf "COLOR_LAW_CONTRAST_ENABLED=%s\n" "$(law_bool require_contrast_ratio true)"
  CBG="$([ -n "$LAWS" ] && jq -r '.rules.require_contrast_ratio.background // "#1E1E1E"' "$LAWS" || echo '#1E1E1E')"
  CRATIO="$([ -n "$LAWS" ] && jq -r '.rules.require_contrast_ratio.min_ratio // 4.5' "$LAWS" || echo 4.5)"
  printf "COLOR_LAW_CONTRAST_BG=%s\n" "$CBG"
  # Contrast is symmetric: a role clears the floor by being lighter than the
  # background (relative luminance at least ratio*(lbg+0.05)-0.05) OR darker
  # than it (at most (lbg+0.05)/ratio-0.05). The old code emitted only the
  # lighter bound, so against a light background it demanded an impossible
  # luminance and the hook rejected every colour. Both bounds, scaled by 1e6.
  jq -rn --arg bg "$CBG" --argjson ratio "$CRATIO" '
    def chan($h; $i): ($h[$i:$i+2] | ascii_downcase
      | explode | map(if . >= 97 then . - 87 else . - 48 end) | .[0] * 16 + .[1]);
    def srgb($c): ($c / 255) as $x
      | if $x <= 0.04045 then $x / 12.92 else pow(($x + 0.055) / 1.055; 2.4) end;
    ($bg[1:]) as $h
    | (0.2126 * srgb(chan($h;0)) + 0.7152 * srgb(chan($h;2)) + 0.0722 * srgb(chan($h;4))) as $lbg
    | "COLOR_LAW_MIN_RELLUM_1E6=\((($ratio * ($lbg + 0.05) - 0.05) * 1000000) | floor)",
      "COLOR_LAW_MAX_RELLUM_1E6=\((((($lbg + 0.05) / $ratio) - 0.05) * 1000000) | floor)"'
  # 256-entry sRGB linearisation table scaled by 1e6. Exact, so a caller can
  # reproduce WCAG luminance without floating point or extra subprocesses.
  jq -rn '"COLOR_LAW_SRGB_LIN=(" + ([range(0;256)
      | (. / 255) as $x
      | (if $x <= 0.04045 then $x / 12.92 else pow(($x + 0.055) / 1.055; 2.4) end)
      | (. * 1000000) | floor | tostring] | join(" ")) + ")"'
  printf "COLOR_LAW_HIERARCHIES='%s'\n" "$(law_list allowed_hierarchies | tr '\n' ' ')"
  printf "COLOR_LAW_REQUIRED_FIELDS='%s'\n" \
    "$([ -n "$LAWS" ] && jq -r '.rules.require_fields.fields[]? // empty' "$LAWS" | tr '\n' ' ' || echo 'role category hex_value hierarchy ')"
  exit 0
fi

load_policy
$STRICT && R_DUPHEX=true

read -r -a REQUIRED_ROLES  <<< "$REQ_ROLE_STR"
read -r -a ALLOWED_HIER    <<< "$HIER_STR"
read -r -a REQUIRED_FIELDS <<< "$REQ_FIELD_STR"
[ ${#REQUIRED_ROLES[@]} -eq 0 ]  && REQUIRED_ROLES=(directory files scripts links prompt errors warnings success)
[ ${#REQUIRED_FIELDS[@]} -eq 0 ] && REQUIRED_FIELDS=(role category hex_value hierarchy)

errors=0
bump() { errors=$((errors + 1)); }
# NOTE: must not be used on the right-hand side of a pipe — that runs the loop
# in a subshell and discards every bump(). Always call as: report "$(jq ...)"
report() {
  local blob="$1"
  [ -n "$blob" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] && { error "$line"; bump; }
  done <<< "$blob"
}

info "Roles: $ROLES"
info "Laws:  ${LAWS:-<none — using built-in defaults>}"

# ---------- rules ----------
VIOLATIONS=$(jq -r \
  --argjson fields   "$(printf '%s\n' "${REQUIRED_FIELDS[@]}" | jq -R . | jq -s .)" \
  --argjson hier     "$(printf '%s\n' "${ALLOWED_HIER[@]+"${ALLOWED_HIER[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
  --arg     pattern  "$PATTERN" \
  --arg     white    "$W" \
  --arg     black    "$B" \
  --argjson lo       "$CH_MIN" \
  --argjson hi       "$CH_MAX" \
  --arg     doFields "$R_FIELDS" \
  --arg     doRole   "$R_DUPROLE" \
  --arg     doFmt    "$R_HEXFMT" \
  --arg     doWhite  "$R_WHITE" \
  --arg     doBlack  "$R_BLACK" \
  --arg     doCon    "$R_CONTRAST" \
  --arg     bg       "$CONTRAST_BG" \
  --argjson minratio "$CONTRAST_MIN" \
  --arg     doLum    "$R_RANGE" '
  def chan($h; $i): ($h[$i:$i+2] | ascii_downcase
    | explode | map(if . >= 97 then . - 87 else . - 48 end)
    | .[0] * 16 + .[1]);
  def srgb($c): ($c / 255) as $x
    | if $x <= 0.04045 then $x / 12.92 else pow(($x + 0.055) / 1.055; 2.4) end;
  def rellum($hex): ($hex[1:]) as $h
    | 0.2126 * srgb(chan($h;0)) + 0.7152 * srgb(chan($h;2)) + 0.0722 * srgb(chan($h;4));
  def ratio($a; $b): (rellum($a)) as $la | (rellum($b)) as $lb
    | ((if $la > $lb then $la else $lb end) + 0.05)
      / ((if $la < $lb then $la else $lb end) + 0.05);
  . as $roles
  | [
      (if $doFields == "true" then
         $roles | to_entries[] as $e
         | $fields[] | select((($e.value[.]) // "") == "")
         | "Entry \($e.key) is missing required field: \(.)"
       else empty end),
      (if $doRole == "true" then
         [$roles[].role] | group_by(.) | map(select(length > 1))[]
         | "Duplicate role: \(.[0])"
       else empty end),
      ($roles[]
       | . as $r
       | (.hex_value // "") as $hex
       | (
           (if $doFmt == "true" and ($hex | test($pattern) | not)
              then "Invalid hex format: \($r.role) = \(if $hex == "" then "<missing>" else $hex end)"
              else empty end),
           (if $doWhite == "true" and ($hex | ascii_upcase) == ($white | ascii_upcase)
              then "Forbidden pure white: \($r.role) = \($hex)" else empty end),
           (if $doBlack == "true" and ($hex | ascii_upcase) == ($black | ascii_upcase)
              then "Forbidden pure black: \($r.role) = \($hex)" else empty end),
           (if $doLum == "true" and ($hex | test("^#[0-9A-Fa-f]{6}$"))
              then ($hex[1:]) as $h
                 | (0.2126 * chan($h;0) + 0.7152 * chan($h;2) + 0.0722 * chan($h;4)) as $lum
                 | if $lum < $lo or $lum > $hi
                     then "Luminance \($lum | floor) outside [\($lo)-\($hi)]: \($r.role) = \($hex)"
                     else empty end
              else empty end),
           (if $doCon == "true" and ($hex | test("^#[0-9A-Fa-f]{6}$"))
              then (ratio($hex; $bg)) as $cr
                 | if $cr < $minratio
                     then "Contrast \(($cr * 100 | floor) / 100):1 against \($bg) is below \($minratio):1 — \($r.role) = \($hex)"
                     else empty end
              else empty end),
           (if ($hier | length) > 0 and (($hier | index($r.hierarchy // "")) == null)
              then "Hierarchy not in allowed vocabulary: \($r.role) = \(if ($r.hierarchy // "") == "" then "<missing>" else $r.hierarchy end)"
              else empty end)
         ))
    ] | .[]' "$ROLES")
report "$VIOLATIONS"

if [ ${#REQUIRED_ROLES[@]} -gt 0 ]; then
  REQ_JSON=$(printf '%s\n' "${REQUIRED_ROLES[@]}" | jq -R . | jq -s .)
  # Bind the required role to $r first. Piping into index(.) rebinds . to the
  # array itself, so index(.) would always be 0 and this law could never fire.
  report "$(jq -r --argjson req "$REQ_JSON" '
    [.[].role] as $have
    | $req[] as $r
    | select(($have | index($r)) == null)
    | "Missing required role: \($r)"' "$ROLES")"
fi

DUPHEX=$(jq -r '
  [.[] | select(.hex_value) | {h: (.hex_value | ascii_upcase), r: .role}]
  | group_by(.h) | map(select(length > 1))
  | .[] | "\(.[0].h) shared by \([.[].r] | join(", "))"' "$ROLES")
if [ -n "$DUPHEX" ]; then
  while IFS= read -r d; do
    if [ "$R_DUPHEX" = true ]; then error "Duplicate hex: $d"; bump
    else warn "Duplicate hex (advisory; --strict to fail): $d"; fi
  done <<< "$DUPHEX"
fi

say ""
if [ "$errors" -eq 0 ]; then
  success "Policy satisfied: $(jq length "$ROLES") roles, 0 violations."
  exit 0
fi
error "Policy violated: $errors error(s)."
exit 1
