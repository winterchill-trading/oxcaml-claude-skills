#!/usr/bin/env bash
# Tests for check-obj-magic.sh against throwaway source trees.
set -euo pipefail

check=$(cd "$(dirname "$0")" && pwd)/check-obj-magic.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

expect() {
  local name=$1 want=$2 dir=$3 got=0
  "$check" "$dir" >"$tmp/out" 2>&1 || got=$?
  if [[ $got -ne $want ]]; then
    echo "FAIL $name: exit $got, wanted $want"
    cat "$tmp/out"
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
}

mk() { mkdir -p "$(dirname "$1")" && printf '%s\n' "$2" >"$1"; }

d=$tmp/clean
mk "$d/src/a.ml" 'let x = 1'
mk "$d/src/obj_like.ml" 'let magic = Objective.magic'
expect clean 0 "$d"

d=$tmp/magic
mk "$d/src/a.ml" 'let f x = Obj.magic x'
expect magic 1 "$d"

d=$tmp/repr
mk "$d/lib/b.mli" 'val f : Obj.t'
mk "$d/lib/b.ml" 'let f x = Obj.repr x'
expect repr 1 "$d"

d=$tmp/allowed
mk "$d/vendor/c.ml" 'let f x = Obj.magic x'
mk "$d/.obj-magic-allowlist" '# vendored code
vendor/*'
expect allowlisted 0 "$d"

d=$tmp/partly
mk "$d/vendor/c.ml" 'let f x = Obj.magic x'
mk "$d/src/d.ml" 'let g x = Obj.obj x'
mk "$d/.obj-magic-allowlist" 'vendor/c.ml'
expect partly-allowlisted 1 "$d"

d=$tmp/build-dirs
mk "$d/_build/default/e.ml" 'let f x = Obj.magic x'
mk "$d/_build-skills/default/e.ml" 'let f x = Obj.magic x'
expect build-dirs-skipped 0 "$d"

if [[ $failures -ne 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
