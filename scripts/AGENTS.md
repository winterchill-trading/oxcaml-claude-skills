# scripts/

- `check-obj-magic.sh [root]`: fails when `Obj.magic`, `Obj.repr` or `Obj.obj` appears in
  a `.ml`/`.mli` file not listed in `<root>/.obj-magic-allowlist` (one path or glob per
  line, `#` comments). Other repositories run it through the shared `obj-magic.yml`
  workflow in `../infra`.
- `test-check-obj-magic.sh`: its test.

Check with `shellcheck scripts/*.sh && scripts/test-check-obj-magic.sh` from the
repository root; CI runs the same plus the check on this repository. Keep the scripts
POSIX-friendly bash with no OCaml dependency, since CI runs them without a switch.
