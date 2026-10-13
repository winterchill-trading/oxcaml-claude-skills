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

## Unix libraries, dune cache and profiling (skills round)

- **`Core.X` moved to `X_unix`.** Core has no Unix-dependent code; the old names are
  deprecated stubs. Library names on the ox switch (`core_unix` 0.18 preview):
  `Command.run` is `Command_unix.run` (`core_unix.command_unix`); `Core.Unix` is
  `Core_unix` (`core_unix`); `Sys.command`, `Sys.readdir`, `Sys.remove`,
  `Sys.executable_name` are `Sys_unix` (`core_unix.sys_unix`); `Filename.temp_dir` is
  `Filename_unix` (`core_unix.filename_unix`); zone-aware `Time_ns` is `Time_ns_unix`
  (`core_unix.time_ns_unix`), `Time_float_unix`, `Date_unix`; `Bigstring_unix`
  (`core_unix.bigstring_unix`), `Iobuf_unix`, `Signal_unix`, `Linux_ext`. The
  deprecation text on `Core.Sys.*` says "available from opam as `core_kernel.sys_unix`",
  which is wrong for dune: the library is `core_unix.sys_unix`.
- **`Bigstring_unix.write ?min_len`.** With the default `min_len = 0` it is one
  `write()` call: it can return a short count and does not retry on `EINTR`. Pass
  `~min_len:len` to loop until everything is written, or use `really_write` (unit
  result). `read ?min_len` is the same on the read side. Both raise `Invalid_argument` if
  `min_len > len` and `IOError` if the minimum is not reached.
- **dune's shared cache does not serve per-agent build directories.** dune 3.22's
  default (`enabled-except-user-rules`) restored nothing here: after `rm -rf _build` the
  same library recompiled every module, and `dune cache size` stays 0B. With
  `DUNE_CACHE=enabled` (or `--cache=enabled`) a rebuild into the *same* build directory
  path is fully restored, but a different `DUNE_BUILD_DIR` recompiles everything, so
  `_build-<repo>` directories per agent never share artifacts. Budget a cold build per
  agent directory; reuse one `DUNE_BUILD_DIR` per repo across sessions instead of
  creating new ones.
- **perf, bpftrace and magic-trace.** None runs on macOS: there is no `perf` or
  `bpftrace`, `dtrace` is limited by SIP, and Apple silicon has no Intel Processor Trace.
  Profile on Linux. magic-trace needs an Intel CPU with PT exposed, which means bare
  metal or a VM that passes PT through; GitHub runners, Rancher Desktop VMs on a Mac
  and most cloud instances do not. `perf` and bpftrace uprobes inside a container need
  `--cap-add SYS_ADMIN` (or `CAP_PERFMON` plus `CAP_BPF`) and a host
  `kernel.perf_event_paranoid` of 1 or lower. OxCaml symbols carry build stamps,
  e.g. `camlMarket_recorder__Raw_writer__append_32_100_code`; the numbers change between
  builds, so attach with a glob (`uprobe:/app/bin/market-recorder:camlMarket_recorder__Raw_writer__append_*_code`).
- **Syscall tracing an Async program**: most `strace` output is the scheduler's
  `epoll_wait`/`futex`/`timerfd` noise; filter with `strace -f -e trace=network,read,write`
  (or a viewer such as strace-ui) before looking for socket problems.
- The shared opam switch can be broken mid-session by another agent's `opam install`
  (here `core_unix` and `async` vanished and `core`'s sub-library directories were
  emptied while `core_kernel` rebuilt). Install packages only from the main session,
  never from parallel agents.
- Kraken spot v2: symbols are `BTC/USD` (not XBT); the book checksum is a CRC32 over the venue's exact decimal strings, so parse with `Yojson.Raw` to keep digits; trim the book to the subscribed depth or checksums fail; resync needs `unsubscribe` then `subscribe`. Kraken Futures has no JSON ping (send a websocket ping frame every 30 s) and `next_funding_rate_time` is an absolute epoch-ms time despite the docs. A `/` in a symbol breaks path-based layouts; escape it.
- `[%matches? ...]` is not available under ppx_jane on the ox switch ("Uninterpreted extension"); use a `match`. `Error.raise` in a Command body prints a backtrace; for user-facing config errors use `eprint_s` then `exit 1`. `pgrep -f <name>` matches other agents' shells mentioning the name; check the listening port with `lsof`. `gh run rerun` needs the admin identity.
- Installing `mdx` (or any package whose solution pulls a non-preview `core`) on the ox switch makes opam downgrade the entire switch including the compiler; interrupted, it leaves `core` half-removed. Recovery: `opam reinstall core`, then `opam switch import ~/.opam/5.2.0+ox/.opam-switch/backup/state-<before>.export` with the openssl3 `PKG_CONFIG_PATH`. Always `opam install --dry-run` first and abort if the plan touches `ocaml-variants`, `core`, `base`, `async` or `ppx_jane`.
- Async synthetic clocks: `Time_source.next_alarm_fires_at` shows the sleep the code scheduled, so a test can wait on it before advancing; alarms land on timing-wheel slots, so round printed delays to milliseconds. Compare `Sys.readdir "/dev/fd"` lengths to test that descriptors are released. `Cohttp_async.Client.Connection.close` cannot cancel an in-flight request.
- Inside `[%message ...]` a labelled argument cannot come first (start with `""`); inside `[%sexp ...]` a type annotation cannot follow `{ r with ... }`.
- `dune build --release` implies `--root .` and cannot be combined with `--root`; use `--profile release`. `OCAMLPARAM='_,O3=1'` turns on flambda2 `-O3` for everything built from source, not for opam libraries; most of the order-book gain came from inlining comparisons from fixed-decimal and exchange-core, so `-O3` per repo is pointless. Allocation counts differ between core_bench and an inline test for the same function; pin them in expect tests, they matched between macOS and Linux CI. Calling a function on a local value in tail position needs `[@nontail]`. A `local_` option of an abstract non-immediate type is useless to callers.
- zsh does not word-split variables: `opam install $PKGS` passes one argument; use `${=PKGS}` or `bash -c`. Serialize opam installs across agents.
- Pinning compiler error text in a dune rule (`with-accepted-exit-codes 2 (run %{ocamlopt} -i f.ml)`
  diffed against `f.expected`) works, but on GitHub Actions the compiler colours its
  output and the diff fails; pass `-color never`. A unique value passed to an `@ local`
  parameter without `borrow_` counts as a use, so consuming it later fails.

## TradFi simulators (nyse-sim, cboe-sim, cme-sim)

- A library module named `Session` cycles with `Equities_core.Session` when sibling modules open Equities_core; name it `Boe_session`. `open! Async` hides a library's own `Clock`; alias it in both `.ml` and `.mli`.
- 64-bit bitfields do not fit OCaml ints (NYSE Pillar puts Side at bits 60-63); use `Int64`, and `Bigstring.set_int64_le` sign-extends bit 62. In MDP 3.0 group headers `numInGroup` is at offset 7.
- On OxCaml `List.split_n` returns an unboxed tuple; use `List.take`/`List.drop`. `let%bind x : T = e` annotates `e`; write `let%bind (x : T) = e`. Partial applications passed as labelled arguments fail with "This value is local"; wrap in `fun`. Nested variant constructors inside a list need qualification.
- TCP feed servers need `Writer.set_raise_when_consumer_leaves w false` and should watch `Writer.consumer_left`. Async `exit` returns a Deferred; CLI error paths use `Stdlib.exit`. Hung Async expect tests print nothing; append to a file to debug.
- Read helpers that skip heartbeats need a fixed deadline, not a per-message timeout. Send the order ack before draining engine events so it precedes the execution reports. An engine without in-place quantity reduction needs an engine-id to public-id map so modifies keep the gateway and feed ids stable; publish a feed Delete only for ids previously published as Adds.
- `dune fmt` at the root of a symlink workspace formats every linked repo; use `dune build @<repo>/fmt --auto-promote`. ocamlformat rewrites `(*@@X@@*)` marker comments. `cmd | head && git commit` commits on a failed build; set `pipefail`. Tee-ing an e2e script into `head` kills it with SIGPIPE before cleanup.
- The public iLink 3 schema copy is `paulbeerkens/cme_Ilink3_simulator` (v8.5); the MDP3 templates download with curl from `ftp://ftp.cmegroup.com`.

## Roadmap wave one

- `[%message]` must start with a string before labelled fields; bare variables print without labels, so annotate `(x : t)`. An `[@@alert]` must also appear on the module type in the `.ml`. `type t [@@immediate]` in a signature needs `[@@warning "-unused-type-declaration"]`. For must-fail compile tests pass `-color never` and a literal file name.
- core_bench shows 3 minor words for an empty benchmark; count allocations with `Gc.minor_words` in an expect test. `Time_ns.Stable.Span.V2` has no quickcheck functions; `Quickcheck.Shrinker.atomic` does not exist, use `Shrinker.empty ()`. Opening `Quickcheck.Generator.Let_syntax` at the top of a file shadows Async's `let%bind`.
- Synthetic-clock live tests need `Time_source.advance_by_alarms_by` then `Scheduler.yield_until_no_jobs_remain`, and every component must stamp times from the same source. In lists like `[ name, fun t x -> ...; ... ]` an unparenthesised `fun` swallows the `;`.
- Bigbuffer plus a reused bin_prot scratch buffer makes appends allocation-free. pyarrow skips `_`-prefixed names, so side files next to Parquet go in `_manifest/`. DuckDB `ASOF LEFT JOIN` and `epoch_ns` work on `TIMESTAMP_NS`.
- `pgrep -f "opam install"` matches the shell running the loop; anchor the pattern. `git ls-remote <url> <sha>` returns nothing for a commit id. cAdvisor on Rancher Desktop needs `--containerd=/var/run/docker/containerd/containerd.sock` and `pid: host`; k3s's kubelet already exports container socket and FD metrics. `OCAMLRUNPARAM=v=0x400` prints nothing on the ox runtime; `o=80` saves about 10% RSS. rclone takes about 150 s to give up on a DNS failure, so alert on `upload_pending`, not failures. memtrace builds on the ox base image.
- dune's cache does NOT share artifacts across different `DUNE_BUILD_DIR`s; `DUNE_CACHE=enabled` restores only into the same path. Core's deprecation text says `core_kernel.sys_unix` but the library is `core_unix.sys_unix`. OxCaml symbol names carry build numbers, so uprobes need wildcards; perf, bpftrace and magic-trace do not run on macOS.

## Roadmap wave two

- Async `Writer.close` still accepts writes while flushing; a write queued behind the close fails with `EBADF unix_fcntl` from the writer's error handler. A failed writer never reports flushed: use `Writer.flushed_or_failed_unit`, give `close` a `~force_close` timeout, and `Monitor.detach_and_iter_errors (Writer.monitor w)` to keep writer errors from killing the program.
- The inline test runner always writes a `.corrected` file even on success; compare with the original to detect failure, and `-partition <file>.ml` reruns one file. `dune-build-info` reports `version=unknown` through a symlinked workspace.
- `n lsr k` on a negative int loses the sign when encoding big-endian 64-bit values; use `asr` then `land 0xff`. Inside `Int64.( ... )` array indices become int64 too. Yojson `Safe.t` has `` `Tuple `` and `` `Variant `` constructors that matches must handle. The Hyperliquid SDK's `to_hex` strips leading zeros, so vector `r`/`s` values can be 63 digits.
- `ppx_sexp` cannot call a hand-written `sexp_of_t` on a phantom-typed value through `[%sexp]`; call it directly. `module X = Info` must be bound before `open! Core`. Inline tests that read fixtures need `(deps (source_tree fixtures))` or `(glob_files ...)`.
- A must-fail compile test run with plain `ocamlc` and only the library's `.cmi` files can fail with "layout ... is any because the .cmi is missing" instead of the intended error; pick a call whose types need no other library. There is no `ocamlfind` on the switch.
- `Zstd.decompress` handles concatenated frames; only `get_decompressed_size` stops at the first, so grow the buffer on "Destination buffer is too small". OxCaml alerts on `Domain.spawn` (wants `Domain.Safe.spawn` with portable closures), so child processes are the simple way to use several cores from Core/Async code. One `In_thread` hand-off per pipe chunk cost 4x in kernel time; batch hand-offs.
- `Hashtbl.sum` does not exist; `List.sum (module Int64)` fails under local mode, convert to Int. Under `set -euo pipefail`, `x=$(find missing | head -1)` aborts; add `|| true`. `export DUNE_BUILD_DIR` does not persist between agent shell calls.
- Binance depth diffs decode at about 6 minor words per byte with Yojson; JSON decoding is about 60% of the recorder's per-frame cost.
- hl-sim: `Writer.transfer` waits per batch, so a client that stops reading backs up the server's outgoing pipe; bound it with `Pipe.length` and close with `Writer.close ~force_close:Deferred.unit`. A client that never reads is `Websocket.create` over `Reader.of_pipe` of an empty pipe. Polling the connection count is racy on Linux; count drops instead. Dune's cache in setup-ocaml saved 479 bytes and cost 100 s: CI time is opam building dependencies (about 15 min), so cache the opam switch keyed on the pins instead.

## Roadmap wave three

- setup-ocaml v3 creates its switch at `$GITHUB_WORKSPACE/_opam`; that directory is what to cache after `opam install`, keyed on OS, image, compiler, ox commit and every pin's resolved commit. Its own cache key includes the repository URLs, so adding `#commit` to the ox URL forces a one-time compiler rebuild of about 16 minutes per repo. With a warm switch hl-sim CI drops from 17 minutes to under 2; a cached switch is 2.5 GB against a 10 GB per-repo cache.
- `opam pin add --no-action` to a new commit does not rebuild an installed package; `opam reinstall <pkg>` is needed. A composite action shows as one step in the run summary, so per-step timings come from job log timestamps.
- Adding a constructor to a shared wire type breaks exhaustive matches in every dependent repo at once. Route new data through a separate module reachable from an existing `Unknown` branch, and only add the real constructor after dependents carry wildcards.
- A module named like a stdlib or Core one (for example `Asset_ctx` next to `Ctx`) shadows silently inside `open!`; check `dune build @check` of dependents, not only the library.
- Feed fixtures: capture one raw frame per message kind with `-on_raw`, store them under `fixtures/` and run them through the `Normalizer.S` adapter in an expect test; the inline test runner needs `(deps (glob_files fixtures/*))`.
- `ubuntu-latest` moves to Ubuntu 26 on 2026-10-19. The `ox-setup` cache key includes the runner image, so every repo takes one full cache miss (17 to 33 minutes) that week; pin `ubuntu-24.04` if that matters.
- markdownlint's line-length rule allows long reference-link definitions, so commit links in long lists are best written reference-style.
- `rebuild-norm` only rebuilds for venues whose normalizer is linked into the binary that runs it; the market-data binary links none, so only feed binaries with a `Normalizer.S` adapter can rebuild their own files.
- `[%sexp (a : int), (b : float)]` fails with "ppx_sexp_value: don't know how to handle this construct"; use `[%message "" ~a:(...) ~b:(...)]`. `[@sexp_drop_default.equal]` and `[@sexp.option]` on new record fields keep dependents' printed sexps unchanged.
- `Market_data.Venue` has no comparator, so `Map.empty (module Market_data.Venue)` does not compile; group with a hashtable and sort by `Venue.compare`. A pure strategy value wants a functional queue for rolling windows, not a mutable ring buffer, or shadow strategies and log replay diverge.
- After hl-client's frame dedupe, Hyperliquid `bbo` gets no raw frames when `l2` is also subscribed; health checks that expect raw frames per stream must exclude it. promtool is not on the machine; the darwin-arm64 release tarball runs directly.
- CI cache rollout: with setup-ocaml's default `builtin-0install` solver, `opam install --deps-only` on a cache-restored switch is not a no-op; it downgraded sedlex via core_bench and recompiled half the switch. Skip all opam commands on an exact hit; use `builtin-mccs+glpk` for partial hits. Git pin checkouts restored from a cache cannot be re-synced (`refs/remotes/opam-ref-<sha>` missing, exit 40): delete `_opam/.opam-switch/sources` before re-pinning. A repo cannot `opam pin add <pkg> .` before the action that installs opam; stage the opam file in a side directory instead. `gh run rerun`/`gh workflow run` need the viatsko token. All 25 repos: warm CI 1.5 to 2.5 minutes, cold 9 to 21.
- `sexp_of_t` of a record with `[@sexp_drop_default]`/`[@sexp.option]` fields drops those names at default values, so it cannot serve as the list of known fields for a params file; `[@sexp.option]` file syntax is `(field 30000)`, not `(field (30000))`. `Live.connect_and_start` hands back no venue, so observers that wrap the venue need `Live.start` instead.
- The CI cache's exact hit skipped system packages: `libsecp256k1-dev` lives outside the switch, so hl-client failed to link. ox-setup now installs `opam list --installed --depexts` with apt on every exact hit.
- `dune fmt` takes no directory argument; format one repo from the workspace root with `dune build @<repo>/fmt --auto-promote`. A mean-reversion "half-life" needs `k = 1 - 0.5 ** (dt / half_life)` per tick, not `gap / half_life`. Anchor-style controls can stay out of `Input.t` when every effect goes through journaled calls (`set_mark`, `deposit`, `cancel`); replay stays bit-identical.
- Passing a first-class module with an abstract type to a helper fails with "type constructor N.t would escape its scope"; bind it: `let run (type a) (module N : S with type t = a) (t : a)`. `Time_ns` has no `round_down_to_minutes`; use `to_int_ns_since_epoch t / 60_000_000_000`. In a shared workspace another agent's half-written untracked `.ml` can break your build for a minute; retry before debugging.
- Offline normalizers need a replay mode: a Binance `GET /depth` reply carries no symbol, so a rebuild applies it to the symbol of the latest depth update, and books are created on demand instead of from a symbol list. A recorded disconnect line must reset books and merged tickers, with deltas skipped until the next snapshot.
- Never run `dune fmt --root <workspace>`: it formats every repo, including files other agents are mid-edit on. The default sexp of `Time_ns` prints in the local zone (+01:00 locally, Z in CI); print through `Time_ns.to_string_iso8601_basic ~zone:Time_float.Zone.utc` in expect tests. ppx_yojson_conv error text includes the source path, which differs between the workspace and CI; keep it out of expectations.
- `match x with None -> fun _ -> true | Some ...` parses the `Some` case into the lambda; parenthesise the `fun`. Async has no `Pipe.Read_result` module; write `` [ `Eof | `Ok of 'a ] ``. zsh does not word-split a command held in a variable (`$B build` fails); use a wrapper script. A default `on_error` that logs with `Log.Global` leaks wall-clock timestamps into expect output; tests pass their own handler.
- A pipe-merge raw reader does about 0.5 to 0.7 M lines/s; a hand-written timestamp parser changed nothing, the per-line pipe hand-off dominates. Adding a field to a widely implemented module type (`Feed.S`) breaks every implementor; add a wrapper (`Feed.With_gaps`) with `of_feed`/`to_feed` instead.
- Resync hooks that take `unit` must read `now` from the shared time source; the test checks the hook sees the loop's time. mm-core CI ran 19 minutes after its own change: a repo's own opam files are in the cache key, so touching them is a full miss.
- `Live.connect_and_start` closes the venue through `V.close` on its error paths, which is a no-op for a wrapper venue; keep the venue from `?on_venue` and shut it down yourself. Mirror strategies need every live input replayed, including resyncs: a `Resync` log line removed gave 93 of 200 ticks mismatching.
- macOS bash 3.2 under `set -u` treats an empty array `"${a[@]}"` as unbound; write `${a[@]+"${a[@]}"}`. Async's `Unix` has no `realpath`; use `In_thread.run (fun () -> Filename_unix.realpath p)`. `Sys.is_directory` follows symlinks, so a directory of symlinks is a cheap filtered view of a data tree.
- The rebuilt `norm/` of a 20 s three-sim recording was byte-identical to the live logs (22 files, 2545 events), but the rebuild does not write the per-minute L2 snapshot index.
- Filtering build output with `grep` hid a compile error and a run looked green; filter whole `File "..."` blocks by repo with awk. `Bvar.wait` inside `Deferred.any` on every paced frame piles up waiters until the next broadcast; use a replaceable `Ivar`. `Pipe.map'` with one string per batch keeps chunked HTTP bodies from sending a chunk per line.
- Replaying raw files back to clients: recorded Binance `l2` files contain the REST depth body (`{"lastUpdateId"`) and Bybit files contain acks and pongs; filter them before sending. binance-client strips query strings from its URLs, and needs a `GET /fapi/v1/depth` to sync its book. `Hl_protocol.Subscription` has no `activeAssetCtx`; parse that subscribe by hand.
- In zsh a dune target list held in a plain variable is one argument ("too many s-expressions"); use an array, `T+=(...)` and `"${T[@]}"`. Reusing the live `Event_log.Writer ?snapshot_interval` in the rebuild path gave a byte-identical snapshot index for free.

## Price anchor

- Inside `[%sexp ...]` a field access needs the whole expression parenthesised: `[%sexp ((f x).field : T)]`. `Side` has no quickcheck generator; use `Quickcheck.Generator.of_list Side.all`. `Process.run_expect_no_output_exn` is a deprecation error on the ox Async; `Unix.system_exn` in tests. `Time_source.create` is read-write; pass `Time_source.read_only ts` to APIs and keep the original to advance. `Order_book.iter` takes an `@ local` callback and needs `[@nontail]`.
- macOS `sample <pid>` profiles without SIP changes; a fresh `Hash_set` per event was the hotspot, a generation stamp on entries removed it (500 resting orders: 88 us to 36 us per event). `Replay_feed` splits events into one pipe per stream and loses exact `recv_ts` order; use `Event_log.read_merged` when order matters. mm-core's `Reconciler` matches within price tolerance and age, so exact-match shadow levels need their own planner.
- Piping `build.sh | head` hides a failed exit code, and `dune fmt --auto-promote` after a failed build can overwrite the edit; build, then format. A harness that feeds events in several runs must reuse the anchor's fixed time offset. Every push cancels the running CI job, so no run finishes until pushes pause.
- The CI cache action's partial hit rebuilds moved pins without system packages, so any repo depending on hl-client failed to link secp256k1; ox-setup now installs depexts on partial hits too (before the reinstall). To commit only your part of a shared file with someone else's uncommitted edits: build a blob from the committed version plus your edit (`git hash-object -w`, then `git update-index --cacheinfo`).
- Replication merge: identical frame text within a 5 s window is one message, earlier recv_ts wins; a disconnect line survives only when both copies have a gap. One core merges 0.4 M compressed lines/s, about 8 minutes for the busiest stream's day.
- Adding a pin changes ox-setup's restore prefix, so the run is a full miss, and `builtin-mccs+glpk` can fail on an empty switch with a large dependency set ("Mip solver failure", exit 60); the action now uses mccs only when a switch was restored. A sim gaining a dependency (hl-sim on price-anchor and binance-client) silently breaks every dependent's pin list; run `check-pins.sh -a` after such a change.
- Adding an optional argument to a module-type function breaks callers that pass no positional argument (the optional cannot be erased); pass `?time_source:None`. hl-sim's `Server.create ~now` takes a synthetic clock; a test can mix synthetic time with real sockets by alternating `advance_by_alarms_by`, `yield_until_no_jobs_remain` and a 1 ms `Clock_ns.after`. hl-sim does not verify signatures, so a signing test must journal requests and recover the signer.
- Async expect tests need `open! Async` in scope; in a mostly sync test file wrap them in a submodule. `let open Async in` shadows a local helper named `at`. When the shared specs checkout holds other agents' edits, commit from a separate clone in the scratchpad. A series-anchored TradFi sim must restart the noise price from the venue's last trade after an auction or halt, then pull it back; settlements come from the sim's own trades, not the anchor target.
- nyse-sim anchor: noise orders through `Venue.with_engine` skip the venue's LULD checks, so a fast or anchored walk trades outside the bands; clamp the anchor target inside the bands (30 bps). `Market_sim` half-life counts noise ticks on the wall clock while series points follow venue time, so on an accelerated clock the walk lags. A harness whose LULD timer starts at creation freezes reference updates if the clock is moved backwards; create it at the right time.
- The TradFi sims could not use `Price_anchor.Anchor` directly: it has no `?half_life`, no session-phase pause, marks sparse series stale after 5 s, and steps the exchange clock itself. All three sims wrote their own `Anchoring` module around `Market_sim.set_reference`.
- hl-sim anchor: the JSON `-journal` records only client requests, so an anchored run needs `-input-journal` (every engine input) to replay. `Source.of_feed` does not close the feed; hook `Pipe.closed` to `F.close`. `[%message "" ~x:(expr).field]` needs a type annotation or the ppx treats it as a string. `dune promote` after building `@all` without `@runtest` promotes nothing, so an empty `[%expect]` can get committed. The market-maker exits on an empty book; wait for `/status` to show the anchor fresh before starting it.
- `open! Async` in an expect-test file makes `let%expect_test` expect `unit Deferred.t`; keep it unopened and use `Thread_safe.block_on_async_exn` with a local `let open Async`. With `open! Async`, `eprintf` before `Stdlib.exit` loses the message; use `Core.eprintf` on CLI error paths. `Source.of_series` raises `Unix_error` on a missing file; wrap in `Monitor.try_with_or_error`. A LULD reference taken from the mark pins the band to the anchor; take it from the venue's own prints over the last 5 minutes.
- A simulator whose client's tests depend on it cannot take that client as a dependency (opam cycle in the client's CI); split the binary into a second package in the same repo (`binance-sim-anchor`). Replaying recorded data at a speed other than 1 against a wall-clock exchange marks the anchor stale (`Silent`); the server clock must follow the replay speed. `Async.after` takes a float span; use `Clock_ns.after` with `Time_ns.Span`. A slowed replay stamps data in recorded time, so a market maker's `max_data_age_ms` must be raised.
- `Command.async` does not run `Shutdown.at_shutdown` on SIGINT/SIGTERM by default; add `Signal.handle Signal.terminating ~f:(fun _ -> shutdown 0)` so journals flush. Warning 23 (useless record `with`) is an error when the literal lists every field. `Source.run` with speed above 0 paces on the wall clock, which `yield_until_no_jobs_remain` does not wait for; tests use speed 0. `dune promote` promotes every pending correction in the shared build dir, not only yours.
- The service image read pins by grepping `opam pin add` lines from ci.yml; after the ox-setup rollout those lines are gone, so it now also parses the `pins: |` block. Infra's action self-test keeps its own copy of hl-sim's pin list, which must follow hl-sim's dependencies.
- Adding fields to a `[@@deriving sexp_of]` stats record changes every expect test that prints it; promote them in the same commit. `Async.Reader.file_lines` raises on a missing file and the OS text is too system-specific for expect output; wrap and print only the path. For a series-only anchor, staleness must be off by default or a sparse series drops the pull after 5 s.

## Roadmap wave six

- Inside a first-class module built in the same function, a record field named `gaps` shadows a pipe writer of the same name and the compiler complains about a Reader where it wanted a Writer; name the writer `gaps_w`. Jittered reconnect waits (400 to 600 ms) must be range-checked, not printed. `dune fmt --root .` inside a repo creates a stray `_build` there. A Hyperliquid reconnect loses the wait window (about 0.5 s) of trades and BBO changes, and a silent stall takes up to the 50 s keepalive to detect.
- Binance gaps: a stream reconnect is one gap naming the stream; a broken L2 sequence is a gap naming `L2` and the symbol; the first sync is not a gap. A 0.5 s outage at mainnet BTCUSDT rates loses about 17 trades and 80 BBOs; book changes fold into the next snapshot. A fake websocket test server must read the request line before upgrading so it can also answer a plain depth request. A gap is always written before its snapshot, so `Pipe.read_now` on the gaps pipe after the snapshot is race-free.
- An `[%expect]` test returning a Deferred only compiles in a file with `open! Async`. Migrating a sim onto `Price_anchor.Anchor`: the default pins the price (pass `half_life`), `marks_set` counts changes not ticks, `create` sets the noise-trader count (pass your own or it drops to 0) and funds two idle anchor accounts, and prices are rounded to the tick.
- Bybit gaps: the reconnect callback runs after resubscribe, so a frame from the new socket could beat it; send the gap from whichever happens first, the callback or the first frame after the reconnect counter rises. A synthetic clock's next alarm may be the 20 s keepalive, not the reconnect timer; wait until the next alarm is under 1 s away before advancing, or the test never reconnects.
- cboe-sim on `Anchor`: the anchor does not start paused, so a venue that boots outside its trading phase counts one pause before the first follow; the LULD clamp stops a large reference jump from ever tripping a pause, so tests that relied on that pause need rewriting; `to_path` keeps the first price change per interval, not the last.
- cme-sim on `Anchor`: `Venue.set_time` never moves backwards, so tests stepping several anchors on one venue must visit times in increasing order; set the venue time before creating anchors because each path starts at the exchange time at creation. `Anchor.reference_price` keeps following the path while paused. After `clear_reference`, `Market_sim.reference_price` still returns the last reference.
- `.corrected` files in `_build-*` sandbox dirs can be stale; use `dune promote` and read `git diff`. `Source.to_path` silently drops an out-of-order series point; sims validate order themselves until `Source.of_series` rejects it. All three TradFi sims now wrap `Price_anchor.Anchor`; their own anchoring code is gone.
- Extending a stable variant without breaking dependents: keep the in-memory type separate and hand-write its bin_io sharing the stable type's tags, pinned by a byte-equality test; append the new digest to the compatible list and check in a fixture written by the old code. 64k-row Parquet row groups cut a five-minute range query from 12 ms to 2 ms on 2M rows for 2% more bytes.
- Dune's inline-test sandbox holds fixtures as symlinks, so `cp -R` copies broken links; use `cp -RL`. Core `Command` reads an anonymous argument starting with `-` (SQL beginning with a `--` comment) as a flag; add a `-file` flag. In DuckDB a CTE named like a column alias binds as a struct, and `time_bucket` returns a microsecond timestamp. Lead-lag on an 85 s mainnet sample: Binance leads Bybit by 17 ms, OKX by 20 ms, Bitget by 33 ms, Coinbase trails everything by 150 to 220 ms.
- `Time_ns.sexp_of_t` prints in the local zone; use `Time_ns.Alternate_sexp` in error messages so expect output is the same on every machine. `git revert -q` is not a flag. Tightening a library's input validation changes the error text dependents' expect tests print; promote them in the same wave.
- On the ox runtime `Gc.quick_stat`'s `top_heap_words` reads below `heap_words`; do not report it as the peak. The scratchpad is shared between agents: use per-repo output file names. `--auto-promote` on fmt after a failed test run also promotes the stale `.corrected` and overwrites new edits; promote tests first, then format. A type change to a widely used record (Params durations) cannot stay OCaml-compatible even when the sexp format does; keep it on a branch until dependents adapt. Code needing market-data goes in a second package (`mm-core-replay`) so repos pinning `mm-core` do not inherit the dependency.
- proctopus does not build on macOS (`mmap` needs `mremap`/`off64_t`, `procfs` reads `/proc`), and its opam packages do not declare Linux-only, so the failure comes at C compile time; on Linux it installs in 24 minutes. The duckdb CLI releases ship gzipped per architecture (`duckdb_cli-linux-arm64.gz`), so an image needs only `gunzip`. hadolint wants the `pipefail` `SHELL` line before any piped `RUN`. An empty `MEMTRACE` is a no-op in `trace_if_requested`, so wrappers can always set it. `docker compose --profile '*' config` validates every profile with no engine running.
- The root `dune-workspace` covers every repo, so `dune fmt --root .` from inside one repo still formats all of them (it keeps rewriting `fixed-decimal/test/must_fail/dune`). An unquoted zsh variable holding several names stays one argument in a loop; use an array or `bash -c`. The Obj.magic check flags `Obj.repr` too; allowlist test files that use it on purpose via `.obj-magic-allowlist`.
- Replaying feeds: Coinbase numbers every frame per connection and resyncs on any gap, so a replay server must renumber `sequence_num` and drop recorded `subscriptions`/`heartbeats`. Kraken spot and futures share one path; tell them apart by request shape. Expect output for feed tests should print connection and reply counts only, since the frame count at close is timing-dependent. binance-client refetches its depth snapshot 200 ms after one that does not join its buffered diffs, so a speed-0 hold must wait for a fetch followed by a quiet period.
- `(optional)` on a dune executable does not keep it out of `dune build`, and `enabled_if %{lib-available:...}` is rejected on executables; a `select` with a fallback module works for an optional bonsai_term UI. Session tests that open a file must wait on the wall clock for the first quotes before driving the synthetic clock. bonsai_term under `script` shows nothing unless the pty has a size (`stty rows 24 cols 80`). `Scheduler.long_cycles` cannot be unsubscribed; a stop flag ignores later cycles. In 30 s e2e runs no Async cycle exceeded 20 ms; a 42 ms p99 was a book update queued behind an in-flight plan.
- memtrace is on the ox base image but not on the local switch; a dune `select` with a stub module keeps local builds working while CI smoke-tests the real trace. In Python heredocs a trailing `\` inside a string joins lines, which breaks OCaml multi-line literals. `Scheduler.long_cycles` returns `Async_kernel.Stream`, and `Async_stream` is not visible outside the library. `Time_ns.pause` is deprecated; use `Time_ns_unix.pause`. binance-client opens one connection per symbol and stream, so 3 symbols and 2 streams give 6 subscribe frames with ids depending on connection order. A stalled event-log disk does not push back on the feeds (10000 events buffered with pipes at zero), so watch the writer's buffered count, not pipe length.
- OKX gaps: a reconnect gap is stamped at the reconnect (0.6 s after a drop) and precedes the first frame of the new socket; a book sequence break costs one unsubscribe/subscribe round trip; funding returns only once rate, mark and index are all known again, up to a minute when the index is quiet. Hard rule for agents: never run `dune fmt` in the shared workspace, only `dune build @<repo>/fmt --auto-promote`.
- Bitget gaps: a silent socket is noticed only after two 30 s ping intervals, up to 60 s of loss; on subscribe Bitget resends the last 50 trades, so short outages lose no trades once consumers dedupe by `trade_id`. `Pipe.peek_all` does not exist; use `Pipe.read_now'`. `Market_data.Instrument.t` prints as `((venue Bitget) (symbol BTCUSDT))`. `Pipe.length` on an unconsumed reader from inside `on_raw` shows whether gaps were written before frames.
- Deribit gaps: `Ws_client` runs `on_connect` synchronously before reading the new connection's first frame, so a gap written there always precedes that connection's events (no double-report trick needed). Deribit public channels have no replay: trades in the window are gone, the book restarts from a full snapshot, and the first ticker after reconnect re-emits funding.
- Coinbase gaps: frames are numbered per connection, so one sequence break gives one gap per synced product and one resubscribe for all; Coinbase resends a batch of recent trades on subscribe, so only older trades are lost after dedupe by trade id. In `[%message]` an unlabeled field expression `(update.kind : t)` prints with the label `update.kind`; write `~kind:(...)`.
- Kraken gaps: spot has no sequence numbers, so a book checksum mismatch is the break signal; the reconnect clears books and writes one gap before the first event of the new connection. `dune promote <path>` with `--root` did not promote test output; `--auto-promote` on `@<repo>/runtest` did. All eight venues now report `Resync` gaps through `feed_with_gaps`.

## OxCaml performance (research round, 2026-10-13)

Verified in a scratch project on `5.2.0+ox`; notes and numbers in specs
`research/oxcaml-performance/`, syntax in `skills/oxcaml-performance`.

- **Loopify does not unbox floats.** A self-tail-recursive sum with a `float`
  accumulator allocates 2 words per iteration (2000 per 1000 elements) in dev, release
  and release `-O3`, with or without `[@@loop]`. A `let mutable` loop or a `float#`
  accumulator drops it to the 2 words of the boxed result.
- **`[@unrolled n]` is a call-site attribute.** On a definition (`[@@unrolled 3]`) it is
  warning 53, an error in the dev profile; write `(f [@unrolled 3]) x`.
- **Two `Float_u` modules.** `Stdlib_upstream_compatible.Float_u` has `add`, `sub`,
  `mul`, `div`; the `unboxed.float_u` library's `Float_u` has `add` and `sub` but no
  top-level `mul`/`div` (use `Float_u.O.( * )`), and is the one with `compare`, `equal`,
  sexp and quickcheck. `[@@deriving compare, equal, hash, bin_io]` on a field typed
  `float#` fails with `Unbound value "compare_float_u"` etc.; type the field `Float_u.t`
  from `unboxed.float_u`. `[@@deriving sexp]` on a bare `float#` field works.
- **Mixed blocks break polymorphic compare at run time.** `x = x` on a record with a
  `float#` field compiles and raises `Invalid_argument("compare: mixed block value")`.
- **Docs lag the compiler.** `type t = K of int64# | L` compiles although oxcaml.org lists
  it as a restriction; `exception E of float#` is still rejected. `ppx_template`
  instantiation (`f [@mode local]`) works outside a `%template` block.
- **Gated features.** `ocaml_simd*`, `parallel`, the `Multicore` library and
  `ocaml-probes` are not installed. The vector type `int64x2#` type-checks; `[%probe]`
  compiles and is silently ignored (`probes: false`, `-probes` "option not available").
  `Domain.spawn` carries alerts `unsafe_multidomain` and `do_not_spawn_domains`; use
  `Domain.Safe.spawn [@alert "-do_not_spawn_domains"]`.
- **Extension universe.** The default enables layouts, small numbers, `let mutable`,
  labeled tuples and iarrays with no flag; `-extension-universe upstream_compatible`
  rejects `float32` and unboxed records.
- **zero_alloc details.** `val f : ... [@@zero_alloc]` and `val[@zero_alloc] f : ...`
  both work and are enforced against an unannotated implementation.
  `[@zero_alloc strict]` passes with `failwith "literal"` and fails with a formatted
  message. Must-fail tests for zero_alloc need `ocamlopt -c` (the check is in the
  backend, `-i` passes) and the symbol names in the error (`(camlM__f_2_5_code)`) stripped
  with sed.
- **Iobuf on v0.18** takes three type parameters: `(read, Iobuf.seek, Iobuf.global)
  Iobuf.t`; library `core_kernel.iobuf`.
- **Measure words, not nanoseconds.** Removing an option, tuple or float box changed
  time by 0.3-1.5 ns on a hot minor heap; words went to 0. `-O3` changed no words-per-call
  figure in these cases. The `core_bench` command has no test-name filter.
- **JSON.** One Binance aggTrade frame: `Yojson.Safe.from_string` plus member lookups
  298 words, 2.4 us; a `[@zero_alloc]` scanner 0 words, 0.26 us. The first scanner
  (restart every key search, compare every byte) was 0.88 us.
- **Copying build outputs.** Files under `_build` are read-only; `cp` onto an earlier
  copy fails with `Permission denied`. `rm -f` the destination first.
- **`core_kernel.iobuf` needs `core_kernel` in the opam depends.** It builds locally
  because the switch has it, and fails in CI with `Library "core_kernel.iobuf" not
  found`. The words-per-call figures and the pinned zero_alloc errors matched on amd64 CI.

## Performance wave

- `Pipe.read_now` allocates about 13 words per call even with no consumer, and `Pipe.iter_without_pushback` calls it per element; `Pipe.read_now'` pays it once per batch. venue-net's old relay paid it twice per frame (26 words); batched delivery is 13 and the `on_message` callback is 0. Most of the remaining 35 words per frame are inside async_websocket (payload copy, frame record). Word counts are exact and reproducible across dev, release, O3 and amd64; nanoseconds on a loaded laptop are not, so pin words.
- order-book: a cancel that filtered a 1000-order level allocated about 1500 words straight onto the major heap, invisible to a minor-words test; count major words too. Per-level linked nodes with the id index pointing at the node make cancel O(1): 24.8 us to 0.26 us, 2094 to 40 words. core_bench shows 3 words for an or_null query that an expect test shows as 0 (harness overhead). `[@@zero_alloc]` fails through a call into fixed-decimal until that library annotates its own functions. Never create a git worktree inside the workspace root (dune sees duplicate packages); `_`-prefixed dirs are ignored. `dune promote` from the root promotes only the caller's `DUNE_BUILD_DIR`.
- market-data: batching the pipe merge with `Pipe.read'` (4096 items), an int-keyed heap and index-based line splitting took the raw reader from 0.6 M to 2.7 M lines/s and 332 to 39 words per line; `Merge.sorted` alone went 103 to 13 words per value. On this switch Core's `List.split_n` returns an unboxed tuple: write `let #(a, b) = List.split_n ...`. `Quickcheck.Generator.small_positive_or_zero_int` does not exist; use `Int.gen_incl`. `let open Quickcheck.Generator` inside `let%bind` hides Async's `Let_syntax`. `String.index_from` returns an option (2 words per call in a hot loop); write the scan by hand. `Time_ns.of_string_with_utc_offset` accepts an empty fraction and 10 digits, so a fast-path parser must fall back on those.
- fixed-decimal zero-alloc: parsing went 85 ns/14 words to 18 ns/0, printing 126 ns/48 words to 22 ns/3. `rem` is not infix under `open! Core`; use `Int.rem`. Aliases like `let mul = mul_units` or `let ( + ) = Int.( + )` in a functor body fail a `[@@zero_alloc]` signature ("weaker guarantee"); write `let[@zero_alloc] mul a b = ...`. A module type in the `.ml` must repeat the `.mli`'s `[@@zero_alloc]` attributes. `val compare ... [@@zero_alloc]` can be restated after `include Comparable.S` but the implementation must override with plain `Int` comparisons. A 0-words test can pass while `[@zero_alloc]` rejects: a rare slow path allocating a tuple is only caught by the checker. `Product.mul`/`div` pass once the functor argument's `to_units`/`of_units` carry the attribute. The fmt target keeps reformatting `test/must_fail/dune`; revert it (or fix the dune file to the formatter's style, once).
- parquet: a bare `dune promote --root .` applied a stale pending promotion and silently restored an old `lib/writer.ml` over a rewrite; only ever `dune promote <file>`. A byte buffer with a mutable `bytes` field read via `Bytes.length` and checked `set_int64_le` was 5x slower than `Stdlib.Buffer`; copy Buffer's layout (immutable storage record behind one mutable field, unchecked stores). `external box_float : float# -> float = "%box_float"` gives a `float#` entry point without the `unboxed` library; a boxed float across modules costs 2 words per call when not inlined. The ctypes zstd binding copies input and output through C memory; a 20-line C stub over `ZSTD_compress` needs no header and links on macOS and Linux. On a loaded host benchmark old and new binaries alternately (old from a scratch worktree) and take the best run.
- mm-core: quote 354 to 48 words, idle tick 45 to 0 through `tick_u` (unboxed pair, same state object), `on_book` 39 to 8. The dev profile does not inline across workspace modules, so a `Price.to_float` call boxes its result; `_u` variants taking or returning `float#` avoid the box without relying on inlining. `Stdlib_upstream_compatible.Float_u` ships with the compiler (no `unboxed` dep). `[@@zero_alloc]` cannot go on a function whose error branch builds a variant; pin 0 words in a test instead. A release build in a separate build dir can keep an old binary after `git checkout <old> -- lib`; check `nm` for the new symbols before comparing. Building the result list directly beats rung arrays by about a word per level per side. What is left of a requote tick (3050 words) is `Reconciler.reconcile`.
- okx-feed scanner: trades 2.4 us/431 words to 0.48 us/25, bbo 531 to 22 words, l2 snapshot 115k to 5k words, with Yojson as fallback and a fixture test that both paths agree. `ignore (Sys.opaque_identity (ref x))` does not trip `[@zero_alloc]` (flambda removes the ref); use `String.make` to confirm the check is on. Arrays over 256 words go straight to the major heap, so start scratch buffers small and grow on demand. Minor-word counts on Yojson/Hashtbl paths differ about 3.5% between macOS and Linux; pin between the two instead of a 2% tolerance. The zsh heredoc here turns `A` into `A` even with a quoted delimiter; write files with backslash escapes from Python.
- binance-client scanner: trades 2.48 us/440 words to 0.49 us/24, bbo 420 to 21 words; a strict scanner that validates every value so its output equals Yojson's costs about 420 ns against the research scanner's 260 ns that reads four keys. What the fast path still allocates is the output itself (event records, trade-id string, result list). Pin zero with a `Gc.minor_words` expect test, not core_bench's 3-word column. Sibling changes can shift a repo's pinned allocation counts while nobody touches it; re-pin on the next visit.
- bybit-client scanner: trades 5.6 us/806 words to 1.1 us/54, bbo 577 to 77, l2 1327 to 536, via an `?intercept` hook on the websocket stream; what still allocates is the events and the local book's map updates. Reject other topics as soon as the topic string is read, or frames the scanner does not handle cost more than before (340 ns to 59 ns). A scanner that skips unused fields without validating them accepts frames Yojson would reject; document it. bybit-client's `test_sim` is flaky under heavy load (a post-only race in the test).
- hl-client scanner: trades 4.2 us/603 words to 1.3 us/41, full l2Book 19 us/3883 words to 6 us/274, bbo-only 22 words; the remaining cost is the scan at about 2 ns per byte. `Gc.For_testing.measure_allocation` returns an unboxed tuple here: `let #((), report) = ...`. An optional argument with a default on a `[@zero_alloc]` function fails ("indirect tailcall" from the wrapper); use a required labelled argument. The 64-bit FNV offset basis does not fit a 63-bit int literal. Include an over-capacity book in every scanner test: a capped read silently truncated deep books instead of refusing them.
- price-anchor: an event with 500 resting orders went 34.8 us to 7.0 us by grouping queue-ahead entries by price, skipping the refresh while `Exchange.next_event_seq` has not moved, and walking the book once for eligible fills. The old refresh cost 30 ns per order, mostly Base `Hashtbl` lookups and `Order_id.to_int_exn` on a boxed int64; store an int key. Under churn two thirds of the time is `Exchange.place` with 500 open orders (margin lookups): the next engine hotspot. `git checkout <rev> -- lib/<file>` overwrites an uncommitted file; commit before fetching a baseline.

## Hyperliquid parity

- Gitbook docs pages download as Markdown by appending `.md` to the URL, far easier than WebFetch output. hl-protocol decoders ignore unknown fields, so unsupported options pass through silently. Hyperliquid STP is "expire maker" (resting own order cancelled, taker keeps matching); base perp fees are 4.5/1.5 bp; rejected orders still produce `orderUpdates`; liquidation cancels are `liquidatedCanceled`; idle websockets close after 60 s; l2Book pushes are at least 0.5 s apart; at most 10 user addresses per websocket connection. Approvals use the `HyperliquidSignTransaction` v1 domain, network chosen by `hyperliquidChain`, not chain id.

## Copy-trading platform

- Hyperliquid approvals: user-signed EIP-712 with the `HyperliquidSignTransaction` v1 domain, signature chain id `0x66eee` on both networks, `hyperliquidChain` picks the network; the SDK's `usdSend` test vector and `eth_account` digests cross-check byte for byte (`pip install eth-account` in a scratch venv). The testnet stats host does not resolve; the testnet board is `stats-data.hyperliquid.xyz/Testnet/leaderboard` (20 MB, amounts with up to 10 decimals, so floats not fixed-decimal). `orderUpdates` frames name no user, so only fills can be shared across addresses on one connection. `User_fill` drops `builderFee` and `liquidation`; a server decoding `/exchange` with `Exchange_request` loses the builder field. Inside a module that opens `Hl_protocol`, an `Ok ()` pattern on `Hash_set.strict_add` fails ("constructor Ok expects 0 arguments"). Mask nonces and signatures in printed bodies; `Time_ns.now` in a test is not repeatable.
- hl-copy-core: `Fixed_decimal.mul_units`/`div_units` wrap silently out of range, so quickcheck generators must bound ratios. `Map.M(Market_data.Symbol).t` derives `bin_io` directly. Assert a replacement pattern exists before a scripted edit; ocamlformat can reflow the text first. A broken dune stanza in any repo (a missing `modules_without_implementation`) blocks every repo in the shared workspace; a scratchpad workspace of symlinks to your dependencies is the escape. One `Mirror.apply` costs 186 ns / 89 words at one symbol; the leverage cap's sum over positions makes it grow with symbol count.
- Compose: `docker compose --profile X up` also starts every service without a profile; name services explicitly. A named volume shared by two containers takes its owner from the first mount point, so mount it read-only in the second and order the start. `make` recipes that pipe into `python3 -c ...; git add` keep going after a failure; chain with `&&`. An API that rate-limits per client IP sees one IP behind an nginx proxy.
- hl-sim copy-trading: signed approvals from pinned eth_account vectors carry nonces near 1.7e12 ms, so tests need a server clock at 1.7e18 ns for the nonce window. Simulated accounts (leaders, noise traders) must be marked as already seen or the first info request credits them the initial balance again. `Float.to_string` prints `1000000.`; leaderboard strings need their own decimal formatting. Pushing commits quickly keeps cancelling CI through the concurrency group; pause to let one run finish. Pushing l2Book at once after a quiet spell broke market-maker's signed test (book update before order ack); keep one 50 ms block of delay. Synthetic leaders lose money on thin noise books: fees and slippage beat their strategies; cap their slippage (20 bps) or give them an edge.
- hl-leaderboard on mainnet (read-only): most top traders never go flat inside the 10,000-fill window, so insert a synthetic opening fill for positions held at the start of history or pnl reads zero; 17 of 34 candidates are truncated (10k fills is an hour or two for busy accounts); only 5 of 34 reach five round trips. `userFillsByTime` pages hold the oldest 2000 fills at or after `startTime`, oldest first; `userFills` is newest first. Use `portfolio` `month` (not `perpMonth`, which omits spot collateral) as the equity curve. Fill histories include spot coins (`@210`) and builder perps (`xyz:NVDA`). A sibling's new module with the same name as yours (hl-protocol `Leaderboard`) shadows it in the shared workspace. A collect of 34 candidates cost 10,436 weight over 10.6 minutes with no retries.
- hl-copy-api: the switch's cryptokit 1.16 has ChaCha20 (8-byte nonce) and HMAC but no AEAD; keys are sealed encrypt-then-MAC, cross-checked against pycryptodome. Two approvals signed in the same millisecond share a nonce and the sim rejects the second; make nonces strictly increase per process. `open Hl_protocol` hides a local `Ws_message` module. `Clock_ns.every'` fires immediately; pass `~start:(Clock_ns.after span)`. Any `*.hyperliquid.xyz` exchange URL is refused at startup as the mainnet guard.

## Bonsai web (js_of_ocaml)

- A fresh switch resolves upstream dune 3.24.2, whose ppx_css inliner writes `include ./app__generated` and breaks bonsai_web with "Syntax error"; keep `dune < 3.23` in the opam file (ox dune 3.22.2+ox works). `let%arr` needs `bonsai.ppx_bonsai` (not in ppx_jane); `let%map` with `Bonsai.Let_syntax` works. `Bonsai.state_opt` takes no unit; the `For_proc` section of `cont.mli` has different signatures from the top-level ones. `Bonsai_web` exports `View`, shadowing a local one; inside `Float.( ... )`, `min`/`max` are the Float ones. js_of_ocaml `int` is 32 bits: millisecond timestamps must be floats; silence the effects warning with `-w no-missing-effects-backend` in `link_flags`; ojs libraries need `(modes byte)`; `Async_js.Http` only does GET/POST, PATCH/DELETE need raw `XmlHttpRequest`. Read `window.ethereum` inside `Effect.of_thunk`, not at render. Node 22 defines `navigator` as a getter: fake DOM globals need `defineProperty`. Release JS 1.58 MB (465 KB gzipped); dev 49 MB; CI cold 25 min, warm 2.3 min.
- hl-copy-engine: on the sim's thin default book a follower IOC racing the leader's own IOC usually gets "could not immediately match"; raise noise traders and the slippage bound in e2e. A test polling `/status` during a follower restart can see an empty list (only on Linux CI); keep the old entry until the replacement is up. `Log.Level.of_string "info"` fails; map names by hand. Inside `Deferred.Or_error.Let_syntax`, `return ()` is the Or_error one; use `Deferred.unit` in plain callbacks. binance-client now needs mm-core, so anything pinning hl-sim pins mm-core before binance-protocol. Past 10 leaders, polling `clearinghouseState` (weight 2) beats `userFills` for a position-copying mirror. 60 s run: lag p50 1.75 ms, slippage p50 4.8 bps.
- hl-sim leaders: an informational edge needs about 60 s of lookahead to beat fees and slippage on thin noise books; 2 to 30 s never did. A mean-reversion signal computed from the future price trades against the coming move; compare the current mid with the future price instead. Leaders at 0.5 to 3x leverage on $100k swamp books that offer $20 to $2000 per order. `set -o pipefail` with `git log | head` returns 141 (SIGPIPE) after a successful commit.
- Builder fee path: adding fields to `User_fill.t` breaks every sibling that builds fill records; use a wrapper record (`User_fill.Detailed`) decoding the same JSON. `Address.of_string` accepts any string, so validate CLI addresses. ppx_expect captures stderr too, so debug prints inside a hanging test are lost; write markers to a file. `dune build @all` does not rebuild the inline test runner. `maxBuilderFee` costs 20 weight, so recheck every 5 minutes once approved. In Python `open(p,'w').write(open(p).read())` truncates before reading.
- Recorder: `Raw_writer.open_file` opens in a thread and `roll` waits only for old files to close, so a test must `flush` before listing the new minute file (a Linux-only flake). zsh has `pipestatus`, not `PIPESTATUS`; piping a build through a filter hides its exit code, so run dune in a bash script. `dune promote` takes no `--root`; run it from the workspace root with the right `DUNE_BUILD_DIR`. All eight venues now write disconnect lines from `feed_with_gaps`.
- exchange-core: step with 1000 accounts went 388 us/77k words to 70 us/20 words by keeping a sorted map of accounts with positions (flat ones pruned lazily on the next step; eager map updates cost 270 words per submit) and iterating a plain position list; place with 500 own open orders went 44 us to 0.95 us with a per-account reserved-margin cache updated on rest/fill/cancel. Base `Hashtbl.fold`/`exists` allocate about 19 words per element even with a local closure; `find_and_call2` with capturing continuations allocates more. amd64 allocates 7 to 14 fewer words than arm64 on submit paths; the test accepts either exact value and prints the measured one otherwise. Sibling changes (order-book's cancel) move pinned counts.
- O3 images (amd64 CI, alternating rounds): order-book fill 95 to 57 ns, mm-core quote 2x, price-anchor 15 to 20%, feeds 10 to 25%, but binance-client's zero-alloc scanner gets 4 to 9% slower and zstd writes and the raw reader are unchanged. So O3 is the default tag for the sims and the market maker only; recorder and replay stay default. O3 adds about 1 MiB and up to a minute of build. Under `pipefail`, `grep -o` with no match fails a Dockerfile pin step for a repo with no sibling pins. The service image must install `libsecp256k1-dev` at build and `libsecp256k1-1` at runtime for anything depending on hl-client.
- Recorder hot path: looking up counters and the output file once per stream and blitting the line into the file buffer took `on_raw` from 832 ns/186 words to 383 ns/0 words; one core now does about 600k frames/s end to end. The first ~1000 writes after a file opens allocate about 475 words once, and each `Buffer` doubling costs 3 words, so words-per-call tests need a warm-up sized to avoid a doubling. `Quickcheck.test` cannot run async code; use `Quickcheck.random_sequence ~seed` and iterate.
- market-data day close: the Direct Parquet path alone changed little; the real cost was two deferreds per frame in the event-log reader. Decoding frames a chunk at a time took reading from 1.6 M to 6.5 M events/s (268 to 35 words) and day close from 1.07 M to 2.9 M rows/s. Decimal columns stay `add_int` of fixed-decimal units to keep bytes identical; `add_float_u` only for the DOUBLE funding rate. When pinning words for a call writing several rows, keep them inside one row group (a group flush allocates). The `Event` quickcheck generator yields NaN funding rates, so compare events by bin_io bytes. `test_frame_log.ml` flush-policy test is flaky on Linux CI (size flush races `immediately`).
- order-book STP policy: `Expire_maker` removes own resting orders with no fill and no fee and lists them in `Result.expired_makers`; cost one extra word per submission. The engine must run its normal cleanup (indexes, reserved margin, cloids) for each expired maker and emit a cancel event with a self-trade reason.
- Clients on `on_message`: exactly 13 fewer words per frame in every client; throughput within noise because decoding and socket reads dominate. Words measured end to end over a loopback socket are exact and platform-identical if you subtract a bare `Ws_client` on the same server; Yojson paths still differ by a few words. Frames that arrive with the upgrade response reach the callback before `connect` returns, so callbacks needing post-connect state must queue them. Comment text starting a line with a parenthesised number like "(466)" makes ocamlformat insert a blank line.
- Feeds on `on_message`: 13 words per frame saved everywhere, time only moves for OKX (10%) because JSON decoding dominates the others. Keep the old pipe path under `For_testing` and a delivery test that both paths produce identical events, gaps and stats. A test polling with `Clock_ns.after` adds its own allocations to a words measurement; fill an `Ivar` from `on_raw`. An expect test pinning sexp text with timestamps (or its length) fails on UTC CI. Several repos' pinned normalizer word counts dropped when fixed-decimal gained in-place parsing; repin on the next visit.
- STP across the engine: reuse the existing `Self_trade` cancel reason for expired makers so no exhaustive match breaks; emit their cancel events after the taker's fills and before the taker's own events so event-rebuilt books stay consistent. A non-default policy needs a journal header (`EXJRNL02`) or replay quietly diverges; default journals stay byte-identical. bin_prot `Read_error` messages carry the source path relative to the dune root, which differs between the workspace and a single-repo CI checkout; never pin them. Changing a sim's self-trade policy shifts every seeded test that uses its noise traders.
- Flaky sim tests: a market maker test must own the market-sim clock (warm the book, then step the market only inside the maker's periodic account check) so no quote is priced on a stale book; "post-only would cross, bbo none@none" means the venue did not fill the BBO in the reject, not an empty book. Tests reading pushed books must skip updates until the expected order appears (pushes are at most every 20 ms). The inline test runner with `-diff-cmd -` always writes `.corrected` and exits 0; `cmp` it against the source. In zsh a variable holding several dune targets is one argument; use an array.
