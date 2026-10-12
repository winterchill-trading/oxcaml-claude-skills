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

### From the hl-mm live loop

- With `open Async`, every `let%expect_test` in the file must return
  `unit Deferred.t`, even pure ones.
- Serialize strategy ticks, plan execution and REST polls on one queue; an
  open-orders snapshot requested before a plan lands can be mistaken for its
  confirmation and orders get placed twice.
- A websocket client that resends the fills snapshot on resubscribe needs
  de-duplication by trade id on the consumer side.
- End-to-end runs are not bit-repeatable even with a seeded simulator, because
  request timing changes matching order; assert on ranges, not exact numbers.

### From hl-client (switch and TLS)

- `opam install async_websocket` on the ox switch can pick v0.13.0, an empty
  stub with no modules. Pin the ox preview version
  (`async_websocket.v0.18~preview.130.106+341`); it pulls cryptokit and zarith.
- `async_ssl` does not compile against Homebrew `openssl@4` (`ASN1_STRING_data`
  removed), and even when built against `openssl@3` the link picks up
  `/opt/homebrew/lib/libssl` via zarith's `-L`. Workaround: write an
  `openssl.pc` under `~/.opam/5.2.0+ox/share/openssl3-pkgconfig/` whose `Libs`
  names the openssl@3 libraries by absolute path (first entry must start with
  `-` or dune rejects it), then `PKG_CONFIG_PATH=<dir> opam reinstall async_ssl`.
  Without async_ssl, conduit-async silently has no TLS.
- `Conduit_async.V3.resolve_uri` builds an OpenSSL config without SNI hostname
  for `wss`; rebuild it with `Ssl.Config.create ~hostname ()`. cohttp-async
  sets SNI itself for `https`.
- `Uri` has no `sexp_of_t` without `uri-sexp`.
- Under ox Base, `Random.State.make_self_init` raises inside inline tests
  ("nondeterministic seed is forbidden"); seed from `Time_ns.now`.
- Base `List.init` calls `f` from the last index down.
- A library module named `Info` shadows `Core.Info` for siblings and for
  `open Hl_client`; use `Core.Info` explicitly.
- Async's `eprintf`/`eprint_s` are deprecated as errors; use `Print.eprintf`.
- ppx_yojson_conv error text embeds the source path, which differs between
  workspace and opam builds; keep it out of expect output.
- A `dune build` can hold `_build/.lock` with no child processes for 30+
  minutes; wrap agent builds in `timeout`.

## 2026-10-12

### From the exchange-core extraction

- **Package cycle.** The engine needs `order-book`, and `order-book` needs the
  primitives, so one opam package cannot hold both (opam rejects the cycle, even when
  dune would resolve it per library). Ship two packages from one repo
  (`exchange-core`, `exchange-core-engine`). Its own CI pins the checkout first
  (`opam pin add exchange-core . --no-action`), then pins `order-book` from GitHub, then
  `opam install ./exchange-core-engine.opam --deps-only --with-test`. Consumers pin the
  same URL twice, once per package name, in dependency order.
- **Re-export with type equality.** To make `Hl_protocol.Price.t = Exchange_core.Price.t`
  write `include Exchange_core.Price` in the `.ml` and
  `include module type of struct include Exchange_core.Price end` in the `.mli`; that
  keeps `comparator_witness` equal too, so `Price.Map.t` values pass between libraries.
  A hand-written `include Comparable.S with type t := t` creates a fresh witness; add
  `and type comparator_witness = M.comparator_witness`.
- Re-export a variant with its constructors: `type t = M.t = Buy | Sell [@@deriving ...]`
  in the `.mli`, `include M` plus the extra codecs in the `.ml`.
- After `include M`, redefining `of_string` (e.g. lowercasing addresses) changes only
  that function; `Comparable`/`Hashable` sexp converters from `M` still use the base
  parser. Override `t_of_sexp` as well when it must validate.
- Venue-neutral cores should not derive yojson on primitives: wire encodings differ per
  venue (`"B"`/`"A"` vs `"BUY"`/`"SELL"`). Keep codecs in the venue protocol library.
- Keeping the old venue-level expect tests in the adapter, unchanged, is a cheap proof
  that an engine extraction is behaviour-preserving (here even the seeded market
  simulation numbers matched); put the neutral copies, with promoted output, in the
  core.
- `dune build ./engine` from inside a repo in the workspace builds just that directory;
  handy while a sibling repo is mid-refactor and does not compile.
- **git.** `git rm` stages deletions; a later `git add a b && git commit` sweeps them into
  that commit. When splitting a refactor into small commits, commit by path
  (`git commit -m ... -- paths`) or keep deletions unstaged (`rm`, not `git rm`).

### Protocol libraries round (Binance, Bybit, mm-core)

- Never name a library module `Error` or `Info`: `open! Core` hides it even
  inside the library. Use `Api_error`.
- Bybit order and execution ids are UUID strings; an integer `Order_id` in a
  shared core cannot represent them. Venue adapters must keep their own id type
  and map to the core only where it is numeric.
- Bybit sends timestamps as both ints and strings, and uses `""` for absent
  values; write `Or_empty` and `As_string` codecs so round trips preserve shape.
- Public and private pongs have different shapes on Bybit; decode both to one
  variant.
- Pushing after every commit cancels earlier CI runs via the concurrency
  group; only the last push's run completes. Expected, not a failure.
- A half-written `dune` file in any sibling repo breaks `dune build` for the
  whole workspace. Build `@./all @./runtest` from inside your repo, or set up a
  private workspace of symlinks for the repos you need.
- Shared scratchpad helper scripts collide between agents; use per-agent
  subdirectories.
- Attribution trailers (`Claude-Session:` etc.) must be stripped when the
  history has to look human; `git filter-branch --msg-filter` then force push.

### Venue simulators round (binance-sim, bybit-sim)

- Venue front ends need order attributes the neutral engine does not keep
  (type, tif, reduce-only, cumulative fills, reject reason); keep a per-venue
  `Orders` table fed by the engine's event stream exactly once, and drop
  finished orders so noise flow does not grow it.
- Binance depth sequencing (`U = pu + 1`) requires publishing events both
  before and after each engine mutation, else `GET /depth` lags the book.
- Flush pending orderbook deltas before registering a new websocket
  subscriber, or its first message is a delta rather than the snapshot.
- Async: `Bus.iter_exn` does not exist in the ox Async; use
  `Bus.subscribe_permanently_exn`. `Cohttp.Code.meth` has no `equal`; use
  `Poly.equal`.
- `Clock_ns.every ~start ~stop:(Pipe.closed w)` is the idiom for per-connection
  ping timers that stop on close.

### From venue-net

- `Websocket.frame_received` is a Bus delivering every frame including control
  frames, and async_websocket answers server pings itself, so a silence
  watchdog can count pongs with no custom frame code. Check `Bus.is_closed`
  before subscribing to a socket that is closing.
- Async `Clock` is `Time_float`; use `Clock_ns` for `Time_ns.Span`, converting
  with `Time_ns.Span.of_span_float_round_nearest`.
- `dune fmt` does not format `dune` files; edit library lists by hand carefully.
- When a repo gains a sibling dependency, put the CI pin in the same commit.

### Venue clients round (binance-client, bybit-client)

- OxCaml rejects `exception E of t [@@deriving sexp_of]` when a field's sexp
  converter is not portable; carry a tagged sexp or an int code instead.
- `Uri` re-encodes query strings (`%3A` becomes `:`); sign the query in the
  form `Uri` actually sends, or signatures fail on the real venue.
- `Clock_ns.with_timeout` around `Pipe.read` leaves the read pending and it
  swallows the next value; wait on `Pipe.values_available` then `read_now`.
- Read websocket frames with your own `iter_without_pushback`; a
  `Pipe.filter_map` stage stalls acks when nobody reads downstream.
- `dune promote` overwrites test edits made after the failing run; promote
  first. Filtering build output with `grep '^[-+] '` hides compile errors.
- Bybit: by-id order lookup on linear needs `symbol` or `settleCoin`; the
  private stream must wait for the auth ack before subscribing.
- Exception sexps embed the source path; keep them out of expect output.

## Writing Parquet from pure OCaml (repo `parquet`)

- Thrift compact field headers carry the field id *delta* from the previous field, not the id; nested structs restart the delta at 0. Bool fields put their value in the type nibble and have no body. Union types (`LogicalType`, `TimeUnit`) encode as a struct with exactly one empty-struct field.
- `TIMESTAMP(NANOS, isAdjustedToUTC=true)` makes DuckDB read the column as `TIMESTAMP WITH TIME ZONE`, which is microsecond-only and silently drops nanoseconds. Default to `isAdjustedToUTC=false` to get `TIMESTAMP_NS`.
- DuckDB rejects a whole file if any STRING value is invalid UTF-8; use `bytes` for opaque payloads. Without `ORDER BY`, rows across row groups come back in any order, so tests should read with `file_row_number = true` and order by it.
- The `zstd` opam binding (0.4, ctypes based) builds on the ox switch. Compress only the page body; the page header stays uncompressed and records both sizes.
- `(*` inside an OCaml comment opens a nested comment, so `count(*)` in a comment breaks the build.
- Inside `Int64.( ... )`, literals and `*` become int64 operations.
- `Expect_test_helpers_core` is not on the ox switch; use `Or_error.try_with` and print.
- A repo with no sibling dependencies can build with `dune build --root .` and is then immune to another agent's half-written sibling `dune` files.
- On GitHub Actions, pushing while the first run is still building the compiler cancels it; let that first run finish so the compiler cache exists. `gh run rerun --failed` is the fix for transient opam download errors.

## Live feeds (market-data `Feed.S` in the three clients)

- `Time_ns` sexps print in the local zone, so expect tests that print timestamps differ between a Mac and CI (UTC). Rewrite to UTC in the test helper, or print `Time_ns.to_int63_ns_since_epoch`.
- A sibling library can gain a new dependency on GitHub (market-data now needs `parquet`) and every consumer's CI then fails with "unknown package" until it pins it too. Pin order is a dependency order, keep it in the common rules.
- A library with a `.mli` listing its modules needs the new module added there as well as in the `.ml`, or the library builds but tests cannot see it.
- Parallel agents in one dune workspace see each other's half-written `dune` files. A private workspace in the scratchpad with symlinks to the needed repos, and `git archive origin/main` snapshots of repos others are editing, isolates a build.
- `dune exec` runs the binary from `_build-*/install/default/bin/<name>`, so `pkill -f main.exe` misses it; kill by pid or by the `<name> -port` pattern. Check `lsof -iTCP:<port> -sTCP:LISTEN` before starting a sim; a stray `ssh` listener held 3000.
- Binance mainnet sends `@bookTicker` on the `/public` route only; `/market` is silent for it.
- Hyperliquid sends a backlog of recent trades on subscribe with `exch_ts` well before `recv_ts`; every `l2Book` message is a full snapshot; `activeAssetCtx` has no venue timestamp.
- Bybit `orderbook.N` deltas before the first snapshot must be dropped; a sequence gap means resubscribe.
- In `Command.Param`, `optional_with_default` takes the parsed value as default, not the string form.

## Parquet sink and DuckDB queries (market-data)

- Multiplying two `DECIMAL(18,8)` columns in DuckDB overflows ("Overflow in multiplication of DECIMAL(18)"); cast to DOUBLE or DECIMAL(38,16) first.
- DuckDB refuses `CREATE VIEW` over a `read_parquet` glob that matches no files; create views only for tables that have files.
- Write Parquet to `<path>.tmp` and rename on close so globs never see a partial file.
- A library module that opens Async cannot refer to its own `Stream` module; alias it before the open.
- `print_endline` inside `Command.basic` prints nothing when Async is opened because the scheduler never starts; use `Command.async`.
- `open! Async` shadows `Sys`; use `Core.Sys.get_argv`. `Deferred.List.exists` takes no `~how`.
- `Time_source.create ~now ()` plus `advance_directly` is a good fake clock for rotation tests.

## Recorder (market-recorder)

- `print_s` under `open! Async` in a `Command.basic` body goes to Async's stdout writer and never flushes; use `Core.print_s` or `Command.async`.
- On the ox Async, `Clock_ns.with_timeout` returns `Clock_ns.Or_timeout.t`; annotate it.
- `Command.async` takes `?behave_nicely_in_pipeline`, not `~behave_nicely_with_pipes`.
- `Throttle.capacity_available` waits for one slot; `Throttle.prior_jobs_done` waits for all running jobs.
- Concatenated zstd frames decode as one stream with `zstd -d`, so appending a frame to an existing `.zst` is a valid restart strategy; the OCaml binding's `get_decompressed_size` reads only the first frame.
- `on_raw` callbacks carry no symbol, so per-symbol raw files need one websocket per symbol.
- Fixed high ports (3510/3520/3530/9910) for e2e scripts avoid stray listeners on 3000/3001.

## Containers (infra)

- Core's `Time_ns` crashes at startup without `/etc/localtime`; runtime images need `tzdata` and a UTC symlink.
- An Async binary as PID 1 ignores SIGTERM; run it under `tini` or pods hang until the grace period ends.
- OxCaml under QEMU is too slow for multi-arch builds; use native `ubuntu-24.04-arm` runners and merge per-arch digests. Building the compiler in a 2 CPU / 6 GB Rancher Desktop VM needs swap on `/mnt/data` (`/` is tmpfs).
- `RUN git clone` layers cache forever; `ADD https://github.com/<org>/<repo>.git#ref` re-checks the remote, and a `PIN_EPOCH` build arg busts the sibling pin cache.
- hadolint 2.12 (the default in hadolint-action) rejects `ADD --keep-git-dir`; download 2.15+. The `docker/dockerfile:1.7` frontend crashed under Rancher Desktop buildkit; the built-in frontend works.
- MinIO no longer publishes images on Docker Hub; `pgsty/minio` and `pgsty/mc` are the community builds that include `mc` and `curl`.
- `gh workflow run` on org repos needs the admin identity; the secondary account gets 403.
- GHCR makes every new package private by default, even when pushed from a public repo. Put `org.opencontainers.image.source=https://github.com/<org>/<repo>` in the Dockerfile `LABEL` and in build-push-action `labels` so the package links to the repo and inherits its visibility; an already-created package must be flipped in the web UI, there is no API.

## Feed repos wave one (OKX, Coinbase, Kraken, Deribit, Bitget)

- Venue docs move: Deribit's per-channel pages are found via `https://docs.deribit.com/llms.txt`; Bitget's v2 per-channel URLs redirect to the v3 docs, so capture live frames instead (Node 22's built-in `WebSocket` via `node -e` needs no packages); OKX's docs page is 5 MB, download and grep it; Cboe publishes `.md` versions of its specs on cdn.cboe.com; the CME wiki is JavaScript-rendered, use the Confluence REST API `/wiki/rest/api/content/<id>?expand=body.view`.
- Book checksums are mostly gone: OKX `checksum` is always 0, Bitget `books` sends none; sequencing relies on `seqId`/`prevSeqId` and `seq`/`pseq`. OKX `seqId` exceeds 2^31, so use 63-bit ints. Coinbase `sequence_num` counts per connection across channels, so a gap resubscribes every book on that connection.
- Keepalives differ: OKX and Bitget want the plain text frame `ping` answered by text `pong`; Deribit uses `public/test`; Coinbase closes idle channels after 60 to 90 s unless `heartbeats` is subscribed and drops connections that send no subscribe within 5 s.
- Trade batches arrive newest first on Coinbase and Bitget; every venue resends a backlog on subscribe, so de-duplicate by trade id.
- Coinbase `market_trades` `side` is the maker's side; the old Exchange `level2` feed now needs authentication, use Advanced Trade. Deribit's `raw` interval needs authentication, use `100ms`. The Coinbase BTC-USD snapshot is one 4.5 MB frame.
- Deribit funding accrues continuously and sizes are USD notional; OKX swap sizes are contracts. `Feed.S` has no field for size unit, instrument type (spot vs perp with the same symbol), funding interval, open interest or liquidations: candidates for market-data V2 types.
- `[@sexp.opaque]` on a `Uri.t` field still fails under `[@@deriving sexp_of]` on ox; hand-write `sexp_of_t`. `[%of_yojson: X.t list]` needs `Primitives` opened. ppx_yojson_conv has no `Yojson.Safe.t_of_yojson`; pass raw JSON through with an identity function.
- `cmd | grep -v ... && git commit` skips the commit when grep filters every line; never put a filtering grep in an `&&` chain. A `;` chain once pushed a non-compiling commit. In zsh `echo ======` fails with "not found".
- GitHub pushes can fail transiently with `remote: fatal error in commit_refs` or `[remote rejected] (failure)`; retry. A fresh repo's first CI run can fail on "Bad checksum" for the compiler tarball; rerun.
- `Time_ns.Span.to_int63_ns` returns `Int63.t`; divisions need `Int63.( / )`. `Time_ns.Alternate_sexp` keeps sexps in UTC and avoids time-zone diffs in expect tests.
