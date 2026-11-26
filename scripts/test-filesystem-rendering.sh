#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$1"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir "$fixture/directory"
touch "$fixture/run.sh" "$fixture/plain.sh" "$fixture/program" "$fixture/index.ts" "$fixture/app.js" "$fixture/README.md" "$fixture/literal*" "$fixture/escape"$'\033[0m*'
chmod +x "$fixture/run.sh" "$fixture/program" "$fixture/literal*"
ln -s run.sh "$fixture/link"
mkfifo "$fixture/pipe"
output=$(__color_ls_render "$fixture")
expect() {
  local role="$1" name="$2" sgr
  sgr=$(__color_ls_sgr "$role")
  if [[ "$output" != *$'\033['"${sgr}m${name}"$'\033[0m'* ]]; then
    printf 'Incorrect color or suffix: %s (%s)\n' "$name" "$role" >&2
    return 1
  fi
}
expect directory 'directory/'
expect scripts 'run.sh*'
expect scripts 'plain.sh'
expect files 'program*'
expect typescript 'index.ts'
expect javascript 'app.js'
expect files 'README.md'
expect files "'literal*'*"
expect files 'pipe|'
expect links 'link'
[[ "$output" != *'escape'$'\033[0m*'* ]]
plain=$(color_ls "$fixture")
[[ "$plain" != *$'\033'* ]]
if __color_ls_render "$fixture/missing" >/dev/null 2>&1; then
  echo 'Missing path unexpectedly succeeded' >&2
  exit 1
fi
printf 'Filesystem rendering contract passed.\n'
