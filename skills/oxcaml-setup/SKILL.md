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

## Known package pitfalls

- `async_websocket`: force the ox preview version, v0.13.0 resolves to an
  empty stub.
- `async_ssl` on macOS with Homebrew `openssl@4`: see GOTCHAS.md "From
  hl-client" for the pkg-config override; without it TLS silently is absent.

## Checking a package builds on OxCaml

The `ox` repo pins OxCaml-compatible versions of Jane Street packages. Third
party packages come from `default` and may fail to compile against the
extended type checker. Check with `opam install --dry-run <pkg>` first, and
prefer Jane Street packages (`async_websocket`, `cohttp-async`) over
alternatives.

## Inline tests (ppx_expect / ppx_inline_test)

The ox build of ppx_expect needs the runner's source root pointed at the test
directory, or every partition fails with `Sys_error "../foo.ml"`:

```
(library
 (name foo_test)
 (inline_tests (flags (:standard -source-tree-root .)))
 (preprocess (pps ppx_jane)))
```

## CI (GitHub Actions)

Do not use apt's opam (2.1, breaks on git repositories). Use:

```yaml
- uses: ocaml/setup-ocaml@v3
  with:
    ocaml-compiler: ocaml-variants.5.2.0+ox
    opam-repositories: |
      ox: https://github.com/oxcaml/opam-repository.git
      default: https://github.com/ocaml/opam-repository.git
- run: opam install . --deps-only --with-test
- run: opam exec -- dune build && opam exec -- dune test
```

The first run compiles the compiler (30+ min); setup-ocaml caches it afterwards.
