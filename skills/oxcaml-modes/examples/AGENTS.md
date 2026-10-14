# skills/oxcaml-modes/examples/

A standalone dune project that proves the claims in `../SKILL.md`: `src/` holds the
patterns, `test/` pins their behaviour with expect tests, and `rejected/` holds
programs the compiler must refuse, each diffed against a `.expected` file holding the
error text.
Accept an intended change to an expected output with `dune promote` (same `--root` and
build directory), then review the diff.

Build and test from the repository root:
`DUNE_BUILD_DIR=_build-skills opam exec --switch 5.2.0+ox -- dune build --root .. @oxcaml-claude-skills/skills/oxcaml-modes/examples/runtest`.
CI builds it on its own with `opam install . --deps-only --with-test`, then
`dune build @all` and `dune test` in this directory.

- Rejected programs run the compiler with `-color never`; CI colours output otherwise
  and the diff fails.
- Allocation pins are zero words where the claim is zero allocation; a non-zero count
  differs between macOS arm64 and Linux amd64, so pin a range if one is needed.
- When an example changes, update the text and numbers in `../SKILL.md` with it.
