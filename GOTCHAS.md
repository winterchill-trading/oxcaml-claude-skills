# Gotchas log

Dated, append-only. Promote stable entries into `skills/`.

## 2026-10-11

- **Name**: the project is `OxCaml` (oxcaml.org), not `0xCaml`. The opam switch
  is `5.2.0+ox` from `git+https://github.com/oxcaml/opam-repository.git`.
- **depext on macOS**: `opam switch create 5.2.0+ox` needs `autoconf`
  (Homebrew). Non-interactive opam aborts on missing depexts with exit 10
  instead of installing them; run `brew install autoconf` first, or pass
  `--confirm-level=unsafe-yes`.
- **Build time**: the OxCaml compiler is built from source; budget 15-30 min
  on an M-series Mac. Start the switch build in the background before
  scaffolding anything.
- **CI**: apt's opam on `ubuntu-latest` (2.1.x) fails to add the ox repository
  (`cp: cannot stat .git/objects/maintenance.lock`). Use `ocaml/setup-ocaml@v3`
  with `ocaml-compiler: ocaml-variants.5.2.0+ox` and an `opam-repositories`
  block listing `ox` before `default`; it ships a current opam and caches the
  switch.

### ppx_yojson_conv with Core (from hl-protocol)

- Generated code calls `string_of_yojson`, `int_of_yojson` etc. unqualified;
  `open! Core` does not provide them. Add
  `open Ppx_yojson_conv_lib.Yojson_conv.Primitives` in files that derive
  yojson, and only there (warning 33 fails the build on an unused open).
- `include Comparable.Make (T)` shadows `<`, `=` for type `t`; later int code
  like `if n < 0` breaks. Use `Int.(n < 0)` or put int helpers before the include.
- `[@yojson.option]` accepts a missing field but rejects explicit `null`. For
  APIs that send `null`, use `[@default None] [@yojson_drop_if Option.is_none]`.
  For bools: `[@default false] [@yojson_drop_if not]`.
- Records reject unknown fields unless `[@@yojson.allow_extra_fields]`; put it
  on every response type decoded from a third-party API.
- Derived variants encode as `["Ctor", ...]`, never matching tagged objects.
  Hand-write variant codecs over a derived helper record. Inline-record
  constructors cannot be passed as values; destructure field by field.
- `int64` encodes as `Intlit`; emit `Int` when it fits so the tree equals what
  Yojson parses.
- Distinct newtypes over one fixed-point implementation need a generative
  functor (`Make ()`), otherwise Price and Size unify.
- Tuples encode as JSON arrays, handy for pairs like `users: [buyer, seller]`.
- GNU sed is on PATH on this Mac: `sed -i ''` fails, use `sed -i`.

### ppx_expect under the ox switch

- `dune test` fails with `Sys_error "../test_foo.ml: No such file or directory"`
  for every inline-test partition. The `ox` ppx_expect (v0.18~preview) records
  bare file names, but dune calls the runner from the test directory with
  `-source-tree-root ..`. Fix in the test `dune` stanza:
  `(inline_tests (flags (:standard -source-tree-root .)))`.
- A `_build` directory produced by one switch confuses the other; `dune clean`
  when swapping switches.

### Multi-repo workflow (from the fixed-decimal extraction)

- Every push to CI rebuilds the OxCaml compiler until the first run finishes
  and seeds the setup-ocaml cache (30-60 min). Add a `concurrency` group with
  `cancel-in-progress: true` to every workflow, and let one run finish before
  pushing more.
- `gh run cancel` silently no-ops for an account without write access; switch
  to the org admin identity first.
- Consume a sibling library by its public (opam) name in `(libraries ...)`,
  e.g. `fixed-decimal`, not the internal `fixed_decimal`.
- A `dune-workspace` + `dune-project` at the parent directory of all checkouts
  makes dune resolve sibling repos without opam pins; `dune build @all
  @runtest` inside a sub-repo then builds via the parent root. `opam pin` with
  a local path only sees committed HEAD, not the working tree.
- Opam pins warn about missing `maintainer`/`authors` fields; harmless but
  add them to `dune-project` to keep logs clean.

### OxCaml modes (from the hl-sim matching engine)

See `skills/oxcaml-modes/SKILL.md` for the verified patterns and error texts:
`global_` fields on local records, `exclave_` on recursive returns, no local
tuples for heap results, `~(f @ local)` plus `[@nontail]` for callbacks.

### Workspace

- Across projects in one dune workspace only public library names resolve:
  `(libraries hl-protocol)`, not `hl_protocol`.
- `git add -A` in one repo while a subagent works in the same checkout sweeps
  its half-finished files into your commit. Serialize work per repo, or `git
  add` specific paths.
