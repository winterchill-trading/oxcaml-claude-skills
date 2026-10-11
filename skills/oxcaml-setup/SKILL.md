---
name: oxcaml-setup
description: Create and maintain an OxCaml (Jane Street OCaml) opam switch locally and in CI. Use when a project targets OxCaml, mentions 5.2.0+ox, oxcaml.org, or Jane Street's OCaml extensions (modes, local_, unique, unboxed types).
---

# OxCaml setup

## Local switch

```sh
brew install autoconf            # macOS depext, otherwise opam aborts (exit 10)
opam repo add --dont-select ox git+https://github.com/oxcaml/opam-repository.git
opam switch create 5.2.0+ox --repos ox,default --yes
eval $(opam env --switch 5.2.0+ox --set-switch)
opam install dune core async ppx_jane ppx_yojson_conv yojson --yes
```

The compiler builds from source: 15-30 minutes. Run it in the background and
scaffold while waiting.

## Checking a package builds on OxCaml

The `ox` repo pins OxCaml-compatible versions of Jane Street packages. Third
party packages come from `default` and may fail to compile against the
extended type checker. Check with `opam install --dry-run <pkg>` first, and
prefer Jane Street packages (`async_websocket`, `cohttp-async`) over
alternatives.

## CI (GitHub Actions)

Cache `~/.opam` keyed on `5.2.0+ox` and the opam files, create the switch only
when `opam switch list --short` lacks it. See the `ci.yml` in any
`winterchill-trading/hl-*` repo.
