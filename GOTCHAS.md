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

### From the hl-mm strategy core

- Inside a local open like `Price.( a + b )`, record field access `o.limit_px`
  fails with "Unbound record field" when the record type is not in `Price`;
  bind the field outside the local open.
- Constructors in tuple lists in test code need qualifying (`Side.Buy`), the
  type is not inferred early enough.
- `dune fmt` re-wraps doc comments; apply text edits before formatting.
- Multiple agents in one dune workspace share the `_build` lock; a run can
  queue behind another and return an empty output file. Re-run rather than
  trust an empty result.
- Unbounded `gamma * sigma^2` in Avellaneda-Stoikov quoting blows up on a
  single bad book print; cap the volatility estimate.
- A finished agent can leave a `dune build` process alive holding `_build/.lock`
  for everyone in the workspace. Parallel agents should each set
  `DUNE_BUILD_DIR=/abs/path/_build-<repo>` (dune honours it for build, test,
  fmt and promote) so locks never collide; add `_build-*/` to `.gitignore` at
  the workspace root.

### From the order-book / fixed-decimal extraction

- Keep extracted libraries wrapped (Jane Street style); submodules become
  `Order_book.Fill`, not top-level `Fill`. Do not `open! Order_book` when it
  defines a `Result` module: it shadows Core's.
- Mixed-type fixed-point arithmetic (Price * Size -> Usd) is a functor
  `Fixed_decimal.Product (Price) (Size) (Usd)`; one instance per call site.
- `ls` is aliased to `eza` in this shell and can hang in agents; use `/bin/ls`.
- Never chain `dune test; git commit; git push` with `;` — a killed test
  still commits. Use `&&`.

### From the hl-sim server

See `skills/async-http-websocket/SKILL.md`: same-port websocket upgrade via
`Server.create_expert` + `` `Expert ``, `Http.Response.make` for 101,
`Log.Global.set_output []` in tests, executable/library name clash.
