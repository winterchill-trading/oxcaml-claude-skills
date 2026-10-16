# AGENTS.md (workspace hub)

This file has two jobs. It is the workspace-wide guide that every repository's own
`AGENTS.md` links to as `../oxcaml-claude-skills/AGENTS.md`, and it is the root
`AGENTS.md` of this repository (see "This repository" at the end).

Read this first, then the `AGENTS.md` of the repository you will change, then
`../specs/repos/<repo>.md`.

## Workspace model

- Every org repository is a sibling checkout in one directory. That directory holds an
  untracked `dune-workspace` and `dune-project` (`(lang dune 3.17)`), so dune resolves
  siblings by public library name with no opam pins. Use public names (`exchange-core`,
  `hl-protocol`) in `(libraries ...)`; private names do not cross repositories.
- One shared opam switch, `5.2.0+ox` (OxCaml, Jane Street v0.18 preview libraries).
  Run tools through `opam exec --switch 5.2.0+ox -- ...`.
- Build one repository from inside it:
  `opam exec --switch 5.2.0+ox -- dune build --root .. @<repo>/all @<repo>/runtest`.
  `@<repo>/doc` builds its odoc pages.
- Parallel agents share the `_build` lock. Give each repository its own build directory:
  `DUNE_BUILD_DIR=_build-<repo>` (with `--root ..` the path is taken relative to the
  workspace root). Reuse the same directory across sessions: dune's cache does not share
  artifacts between build directories, so a new one means a cold build.
- Format only your repository: `dune build --root .. @<repo>/fmt --auto-promote`, after
  tests pass. `dune fmt` at the workspace root rewrites every repository, including files
  other agents are editing.
- Standalone (outside the workspace): `opam repo add winterchill
  https://github.com/winterchill-trading/opam-repository.git`, install the published
  dependencies, then `dune build` and `dune test` in the checkout.
- Use `/bin/ls` in scripts; chain build, commit and push with `&&`, never `;`.

## Repository map

`../specs/overview.md` has the layers, status and the dependency graph; each row below
has a page at `../specs/repos/<repo>.md`.

Trading core
- `fixed-decimal`: 10^-8 fixed-point decimals, a distinct type per use (price, size, usd).
- `exchange-core`: venue-neutral types (package `exchange-core`) and the engine:
  clearinghouse, margin, funding, liquidation, noise traders (`exchange-core-engine`).
- `order-book`: price-time priority book and matching; sits between the two packages above.
- `mm-core`: pure quoter, reconciler, risk, `Venue.S` and the `Live.Make` event loop.
- `price-anchor`: anchors a simulated market to a live or recorded reference.

Venues
- `hl-protocol`, `binance-protocol`, `bybit-protocol`: wire types, JSON codecs, signing.
- `venue-net`: Async HTTP and reconnecting websocket transport.
- `hl-client`, `binance-client`, `bybit-client`: typed clients, local books, live feeds;
  the Binance and Bybit clients carry their `Mm_core.Venue.S` adapters.
- `okx-feed`, `coinbase-feed`, `kraken-feed`, `deribit-feed`, `bitget-feed`: read-only
  public market data as a `Market_data.Feed.t`.

Simulators
- `hl-sim`, `binance-sim`, `bybit-sim`: each venue's HTTP and websocket API over the engine.
- `equities-core`: US equities, options and futures semantics (sessions, ticks, auctions,
  halts, fees).
- `nyse-sim`, `cboe-sim`, `cme-sim`: NYSE Pillar/XDP, Cboe BOE/PITCH, CME iLink 3/MDP 3.0,
  binary over TCP.

Market data
- `parquet`: pure OCaml Parquet writer.
- `market-data`: normalized stable types, event logs, Parquet sink, day close, replay.
- `market-recorder`: records live feeds to raw minute files and event logs.
- `market-replay`: replays raw lines over HTTP and venue-native websockets.
- `backtest-stats`: deflated and probabilistic Sharpe ratios, reality check and SPA,
  probability of backtest overfitting, VaR backtests and a sexp acceptance gate.

Fiat rails
- `griffin-client`, `lightspark-client`, `striga-client`: Async clients and CLIs for
  banking APIs, sandbox by default.
- `griffin-provider`, `lightspark-provider`, `striga-provider`: `banking-provider`'s
  `Provider` over each client.

Banking libraries
- `money`: currencies, exact minor-unit amounts, FX rates, fees.
- `ledger`: double-entry ledger over an append-only Bin_prot journal.
- `fx-core`: reference rates, cross rates, spreads and customer rates.
- `kyc-core`, `payments-core`, `card-core`: customer due diligence, payment rails and
  transfer state machines, card lifecycle and authorization.
- `risk-rules`, `risk-models`: rule engine for transfers and cards; learned scores behind it.
- `banking-provider`: the `Provider` interface and a deterministic fake provider.
- `investing-core`: retail brokerage as pure values (orders, positions, cash entries).
- `scheduler-core`: recurring schedules and exactly-once runs.
- `auth-kit`, `webauthn`, `otp-mail`: passcodes and lockout, passkey verification,
  one-time codes and transactional email.

Apps
- `hl-mm`, `market-maker`: market-making binaries (Hyperliquid; all three venues).
- `hl-copy-core`, `hl-leaderboard`, `hl-copy-engine`, `hl-copy-api`, `hl-copy-web`:
  the copy-trading platform, ending in a Bonsai frontend.
- `leader-scoring`: track records, metrics, composite and learned leader scores, copy
  capacity and alerts; a read-only Hyperliquid source (`leader-scoring-hl`).
- `execution-algos`: venue-neutral execution algorithms (TWAP, VWAP, POV, passive,
  adaptive copy), impact estimates and cost reports; used by `hl-copy-engine`.
- `copy-backtest`: replays recorded markets and a leader's fills through the copy mirror
  and the algorithms; Parquet results checked with DuckDB.
- `neobank-api`, `neobank-web`: the neobank demo's HTTP API and Bonsai app.

Infra
- `infra`: container images, compose, Helm chart, the `ox-setup` CI action and the
  shared `obj-magic` workflow.
- `pg-async`: PostgreSQL client for Async over libpq.
- `service-kit`: building blocks for Async HTTP services on cohttp-async.
- `opam-repository`: the org's opam repository, entries pinned to audited commits.

Specs
- `specs`: architecture, per-repository pages, design docs, ADRs, research, roadmap.

Tooling
- `oxcaml-claude-skills`: this repository; skills, scripts and `GOTCHAS.md`.

## Cross-cutting rules

- Jane Street style: `open! Core`, an `.mli` for every module, labelled arguments,
  ppx_jane derivations, ppx_expect tests, Base_quickcheck for properties.
  See `skills/janestreet-ocaml-style`.
- Odoc comment on every public value; a short comment for humans at every non-obvious
  choice (a pinned number, a tolerance, a workaround) saying what and why.
- On-disk and wire types live in `Stable` modules with pinned digests; changing a type
  means a new version, never an edit in place.
- Allocation pins: word counts differ between macOS arm64 and Linux amd64 on Hashtbl and
  Yojson paths. Pin zero, or pin a range, never an exact non-zero count from one machine.
- Hot paths carry `[@zero_alloc]` and are checked by the compiler; see
  `skills/oxcaml-performance` before optimising and measure first.
- No `Obj.magic`, `Obj.repr` or `Obj.obj` outside a repository's `.obj-magic-allowlist`.
- User-visible changes get a line under "Unreleased" in `CHANGES.md`.
- Commits: author "WinterChill AI <hello@winterchill.xyz>", small conventional commits
  (`feat`, `fix`, `test`, `docs`, `build`, `refactor`), one step each, pushed right away,
  no attribution trailers. `git add` named paths only.
- Secrets come from the environment only; `.env` is gitignored. Never print a secret.
- Never install or upgrade opam packages that change the compiler, `core`, `base`,
  `async` or `ppx_jane` on the shared switch; check with `opam install --dry-run` first.
  Never publish, tag or release.

## Keeping specs and gotchas current

- `../specs/CLAUDE.md` says when a change needs a spec update: a new repository, library,
  binary or org dependency; a changed format, protocol or adapter contract; a new or
  reversed decision (an ADR). Update specs in the same session and add a line to
  `../specs/CHANGELOG.md`.
- The repository's README and `.mli` files win over specs when they disagree; fix specs.
- `GOTCHAS.md` here is a dated, append-only log of toolchain and library surprises.
  Append what you hit; stable entries are later promoted into `skills/`.
- When a repository's layout, commands or dependencies change, refresh its `AGENTS.md`
  in the same session (see `skills/agents-md`).

## CI model

- Every OCaml repository's `ci.yml` runs `winterchill-trading/infra/.github/actions/ox-setup`:
  it installs the OxCaml switch from the ox opam repository at a pinned commit, pins the
  sibling repositories from GitHub in dependency order, installs dependencies and caches
  the whole switch keyed on the pins. Warm runs take a few minutes.
- Pin order follows the graph: `fixed-decimal`, `exchange-core`, `hl-protocol`,
  `order-book`, `exchange-core-engine` (same URL as `exchange-core`), then the rest.
  When `dune-project` gains an org dependency, add its pin in the same commit.
- Most repositories also call the shared `obj-magic.yml` workflow; libraries with
  published docs build `@doc` in CI.
- Check a run with one `gh run list --limit 1` and at most one
  `gh run watch <id> --exit-status`. Never poll in a loop; the API quota is shared. On a
  rate-limit error, stop and report it.

## This repository

Purpose: Claude Code skills and the gotchas log used by every org repository; installable
as a plugin (`.claude-plugin/plugin.json`).

| Path | Holds |
| --- | --- |
| `skills/` | One directory per skill, each with `SKILL.md`; see `skills/AGENTS.md` |
| `skills/*/examples/` | Dune projects that prove the modes and performance claims |
| `scripts/` | `check-obj-magic.sh` and its test |
| `GOTCHAS.md` | The append-only log |
| `.github/workflows/ci.yml` | shellcheck, the script test, the `Obj` check, both example builds |

Build the examples from this checkout:
`DUNE_BUILD_DIR=_build-skills opam exec --switch 5.2.0+ox -- dune build --root .. @oxcaml-claude-skills/skills/oxcaml-modes/examples/runtest @oxcaml-claude-skills/skills/oxcaml-performance/examples/runtest`.
Check scripts with `shellcheck scripts/*.sh && scripts/test-check-obj-magic.sh`.
Markdown edits need no build; commit them as `docs:`.
