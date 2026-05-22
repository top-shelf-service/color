#!/usr/bin/env bash

# validate-color-system.sh
# Validates role schema, color law alignment, and alias role references.

set -u
set -o pipefail

ERRORS=0

fail() {
  echo "[FAIL] $*" >&2
  ERRORS=$((ERRORS + 1))
}

pass() {
  echo "[PASS] $*"
}

need_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    fail "Missing file: $file"
    return 1
  fi

  return 0
}

has_role() {
  local needle="$1"
  local role=""

  for role in "${ROLES[@]}"; do
    if [ "$role" = "$needle" ]; then
      return 0
    fi
  done

  return 1
}

COLOR_ROLES_FILE="ctl_environment_template/color_roles.json.template"
COLOR_LAWS_FILE="ctl_environment_template/laws/color/color-laws.json.template"
ALIASES_FILE="bash_aliases_template.sh"

need_file "$COLOR_ROLES_FILE"
need_file "$COLOR_LAWS_FILE"
need_file "$ALIASES_FILE"

if [ "$ERRORS" -ne 0 ]; then
  echo "Cannot continue validation because required files are missing." >&2
  exit "$ERRORS"
fi

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required for validation"
  exit "$ERRORS"
fi

jq empty "$COLOR_ROLES_FILE" >/dev/null 2>&1 || fail "Invalid JSON: $COLOR_ROLES_FILE"
jq empty "$COLOR_LAWS_FILE" >/dev/null 2>&1 || fail "Invalid JSON: $COLOR_LAWS_FILE"

if [ "$ERRORS" -ne 0 ]; then
  exit "$ERRORS"
fi

mapfile -t ROLES < <(jq -r '.[].role' "$COLOR_ROLES_FILE" | sort)
mapfile -t LAW_ROLES < <(jq -r '."RULE-COLOR-SYSTEM-01".roles | keys[]' "$COLOR_LAWS_FILE" | sort)

if [ "${#ROLES[@]}" -eq 0 ]; then
  fail "No roles found in $COLOR_ROLES_FILE"
else
  pass "Loaded ${#ROLES[@]} color roles"
fi

DUPLICATES="$(printf '%s\n' "${ROLES[@]}" | sort | uniq -d)"
if [ -n "$DUPLICATES" ]; then
  fail "Duplicate roles found: $DUPLICATES"
else
  pass "No duplicate roles"
fi

while IFS=$'\t' read -r role hex; do
  if [[ ! "$hex" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    fail "Role '$role' has invalid hex value: $hex"
  fi

  upper_hex="$(printf '%s' "$hex" | tr '[:lower:]' '[:upper:]')"

  if [ "$upper_hex" = "#FFFFFF" ]; then
    fail "Role '$role' uses prohibited pure white"
  fi

  if [ "$upper_hex" = "#000000" ]; then
    fail "Role '$role' uses prohibited pure black"
  fi
done < <(jq -r '.[] | [.role, .hex_value] | @tsv' "$COLOR_ROLES_FILE")

while IFS= read -r role; do
  if ! printf '%s\n' "${LAW_ROLES[@]}" | grep -Fxq "$role"; then
    fail "Role exists in color_roles but not color-laws: $role"
  fi
done < <(printf '%s\n' "${ROLES[@]}")

while IFS= read -r role; do
  if ! printf '%s\n' "${ROLES[@]}" | grep -Fxq "$role"; then
    fail "Role exists in color-laws but not color_roles: $role"
  fi
done < <(printf '%s\n' "${LAW_ROLES[@]}")

mapfile -t ALIAS_COLOR_ROLES < <(
  grep -Eoh 'color_apply[[:space:]]+[A-Za-z0-9_-]+' "$ALIASES_FILE" \
    | awk '{print $2}' \
    | sort -u
)

for alias_role in "${ALIAS_COLOR_ROLES[@]}"; do
  if ! has_role "$alias_role"; then
    fail "Alias references undefined color role: $alias_role"
  fi
done

if [ "$ERRORS" -eq 0 ]; then
  pass "Color system validation passed"
else
  echo "[FAIL] Color system validation found $ERRORS error(s)" >&2
fi

exit "$ERRORS"
