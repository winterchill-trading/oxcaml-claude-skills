# oxcaml-claude-skills

Claude Code skills, gotchas and workarounds collected while building the
`hl-protocol` / `hl-sim` / `hl-mm` projects with [OxCaml](https://oxcaml.org)
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
| `skills/oxcaml-modes` | Verified `local_`/`exclave_`/`global_`/`@ local` patterns with compiler error texts |
| `skills/async-http-websocket` | cohttp-async + async_websocket servers and clients, same-port upgrades, logging in tests |
| `skills/janestreet-ocaml-style` | Writing Base/Core/Async code the Jane Street way, ppx_jane, expect tests |

`GOTCHAS.md` is the running log; entries are promoted into skills once stable.

## Ecosystem map

Repos in this org, dependency order (each builds on the ones above):

| Repo | What |
|------|------|
| `fixed-decimal` | Fixed-point decimals, generative functor for distinct Price/Size/Usd types, mixed products |
| `hl-protocol` | Hyperliquid wire types and JSON codecs (info, exchange, websocket) |
| `order-book` | Price-time priority book and matching with OxCaml stack allocation in the hot loop |
| `hl-client` | Async HTTP + websocket client; read-only parts work against real Hyperliquid |
| `hl-sim` | Exchange simulator: clearinghouse, margin, funding, liquidation, noise traders, HTTP/WS server |
| `hl-mm` | Market maker: Avellaneda-Stoikov-lite quoter, reconciler, risk, live loop, e2e script |

Local layout: all checkouts side by side under one directory holding an
untracked `dune-workspace` and `dune-project` (`(lang dune 3.17)`), so dune
resolves siblings by public name without opam pins. CI pins siblings from
GitHub instead.
