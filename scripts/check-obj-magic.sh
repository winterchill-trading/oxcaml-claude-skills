#!/usr/bin/env bash
# Fail when Obj.magic, Obj.repr or Obj.obj appears in OCaml sources outside an
# allowlist. Usage: check-obj-magic.sh [root] (default: current directory).
#
# The allowlist is <root>/.obj-magic-allowlist: one path per line, relative to
# the root, with shell globs allowed (`vendor/*`). Blank lines and lines
# starting with # are ignored. Files under _build*/ and _opam/ are skipped.
set -euo pipefail

root=${1:-.}
cd "$root"

allowlist=.obj-magic-allowlist
patterns=()
if [[ -f $allowlist ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -n $line ]] && patterns+=("$line")
  done <"$allowlist"
fi

allowed() {
  local f=$1 p
  for p in "${patterns[@]+"${patterns[@]}"}"; do
    # shellcheck disable=SC2053
    [[ $f == $p ]] && return 0
  done
  return 1
}

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  files=$(git ls-files --cached --others --exclude-standard -- '*.ml' '*.mli')
else
  files=$(find . \( -name '_build*' -o -name _opam -o -name .git \) -prune \
    -o -type f \( -name '*.ml' -o -name '*.mli' \) -print | sed 's|^\./||')
fi

status=0
while IFS= read -r f; do
  [[ -z $f || ! -f $f ]] && continue
  case $f in _build*/* | _opam/*) continue ;; esac
  hits=$(grep -nE '\bObj\.(magic|repr|obj)\b' "$f" || true)
  [[ -z $hits ]] && continue
  if allowed "$f"; then continue; fi
  while IFS= read -r h; do
    echo "$f:$h"
  done <<<"$hits"
  status=1
done <<<"$files"

if [[ $status -ne 0 ]]; then
  echo "Obj.magic/Obj.repr/Obj.obj outside $allowlist; justify and allowlist the file, or remove the cast." >&2
fi
exit $status
