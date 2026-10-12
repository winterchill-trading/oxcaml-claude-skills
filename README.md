# oxcaml-claude-skills

Claude Code skills, gotchas and workarounds collected while building the
`exchange-core` / `hl-protocol` / `hl-sim` / `hl-mm` projects with [OxCaml](https://oxcaml.org)
and the Jane Street library stack.

Install as a plugin:

```sh
claude plugin add https://github.com/winterchill-trading/oxcaml-claude-skills
```

Or copy a skill directory into `~/.claude/skills/`.

## Skills

| Skill | What it covers |
|-------|----------------|
| `skills/oxcaml-setup` | Creating and maintaining an OxCaml opam switch, CI, depexts |
| `skills/oxcaml-modes` | Verified `local_`/`exclave_`/`global_`/`@ local`, `@ unique` and `borrow_` patterns with compiler error texts; `examples/` is a dune project built in CI |
| `skills/async-http-websocket` | cohttp-async + async_websocket servers and clients, same-port upgrades, logging in tests |
| `skills/janestreet-ocaml-style` | Writing Base/Core/Async code the Jane Street way, ppx_jane, expect tests |

`GOTCHAS.md` is the running log; entries are promoted into skills once stable.

Each skill opens with outcomes, 3-5 reference modules from the org repos and short
exercises for checking a fresh session against it.

Build the modes examples locally (from the workspace, with a per-agent build dir):

```sh
cd skills/oxcaml-modes/examples
DUNE_BUILD_DIR=../../../../_build-skills opam exec --switch 5.2.0+ox -- dune build --root . @all @runtest
```

## Scripts

`scripts/check-obj-magic.sh [root]` fails when `Obj.magic`, `Obj.repr` or `Obj.obj`
appears in a `.ml`/`.mli` file (tracked or untracked, `_build*/` and `_opam/` skipped)
that is not listed in `<root>/.obj-magic-allowlist`. The allowlist takes one path or
shell glob per line, relative to the root; `#` starts a comment. Put the reason for
each entry next to it. Every org repo passes with no allowlist today.

To enforce it in another repo, add a job to its workflow (no OCaml needed, it runs in
seconds):

```yaml
  obj-magic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -fsSL https://raw.githubusercontent.com/winterchill-trading/oxcaml-claude-skills/main/scripts/check-obj-magic.sh \
            | bash -s -- .
```

`scripts/test-check-obj-magic.sh` is its test; CI runs both plus shellcheck.

## Ecosystem map

Repos in this org, dependency order (each builds on the ones above; `exchange-core`'s
engine package comes after `order-book`):

| Repo | What |
|------|------|
| `fixed-decimal` | Fixed-point decimals, generative functor for distinct Price/Size/Usd types, mixed products |
| `exchange-core` | Venue-neutral primitives and views (package `exchange-core`), and the engine: clearinghouse, margin, funding, liquidation, noise traders (package `exchange-core-engine`, built on `order-book`) |
| `hl-protocol` | Hyperliquid wire types and JSON codecs (info, exchange, websocket); re-exports the exchange-core primitives |
| `order-book` | Price-time priority book and matching with OxCaml stack allocation in the hot loop; uses exchange-core primitives |
| `venue-net` | Venue-independent Async HTTP and websocket plumbing: reconnect with backoff, ping watchdog, resubscription |
| `hl-client` | Async HTTP + websocket client; read-only parts work against real Hyperliquid |
| `hl-sim` | Hyperliquid adapter over the exchange-core engine: asset indices, wire types, error wording, HTTP/WS server |
| `mm-core` | Venue-neutral market-making core: Avellaneda-Stoikov-lite quoter, reconciler, risk, `Venue.S` signature and the `Live.Make` event loop |
| `hl-mm` | Hyperliquid venue adapter for mm-core (`Hl_venue`) and the `hl-mm` executable, e2e script |
| `binance-protocol` | Binance USD-M Futures wire types, JSON codecs and HMAC signing |
| `binance-sim` | Binance USD-M simulator over the exchange-core engine: REST, depth sequencing, market and user streams |
| `binance-client` | Async Binance USD-M client (REST, local book, market and user streams) and the mm-core venue adapter |
| `bybit-protocol` | Bybit v5 (linear) wire types, JSON codecs and signing |
| `bybit-sim` | Bybit v5 simulator over the exchange-core engine: REST, public and private streams |
| `bybit-client` | Async Bybit v5 client (REST, local book, public and private streams) and the mm-core venue adapter |
| `market-maker` | One `market-maker` binary running mm-core on Hyperliquid, Binance or Bybit (or their simulators), with e2e scripts per venue |
| `parquet` | Pure OCaml Apache Parquet writer: thrift compact metadata, PLAIN encoding, zstd pages, verified with DuckDB |
| `market-data` | Normalized market data types (stable Bin_prot), event log, candle aggregation, `Feed.S`, replay, Parquet sink and day close, DuckDB query CLI |
| `market-recorder` | Records the venue live feeds to Tardis-style raw minute files and event logs, uploads closed files with a configurable command |
| `infra` | OxCaml base image, service image, Compose, Helm chart, local Rancher Desktop and AWS notes |
| `specs` | Architecture, per-repo pages, design docs, ADRs and the service map; read before touching a repo |

Local layout: all checkouts side by side under one directory holding an
untracked `dune-workspace` and `dune-project` (`(lang dune 3.17)`), so dune
resolves siblings by public name without opam pins. CI pins siblings from
GitHub instead.
