---
name: oxcaml-setup
description: Create and maintain an OxCaml (Jane Street OCaml) opam switch locally and in CI. Use when a project targets OxCaml, mentions 5.2.0+ox, oxcaml.org, or Jane Street's OCaml extensions (modes, local_, unique, unboxed types).
---

# OxCaml setup

## Outcomes

1. Create the `5.2.0+ox` switch and install the Jane Street stack without
   picking a stub or a broken package.
2. Write a GitHub Actions workflow that builds an OxCaml repo and its sibling
   pins in dependency order.
3. Configure inline expect tests so they run under the ox `ppx_expect`.
4. Build several sibling repos together locally without opam pins.

## Reference modules (org repos)

| File | Shows |
|------|-------|
| `hl-protocol/.github/workflows/ci.yml` | setup-ocaml with the `ox` repository, sibling pins, concurrency group |
| `exchange-core/.github/workflows/ci.yml` | Two packages from one repo installed in stages |
| `hl-protocol/test/dune` | `-source-tree-root .` inline-tests flag |
| `infra/images/oxcaml-base/Dockerfile` | Switch build pinned to an `ox` repository commit (`OX_REPO_COMMIT`) |
| `oxcaml-claude-skills/skills/oxcaml-modes/examples/dune-project` | Minimal project with generated opam file, built in CI |

## Exercises

1. Scaffold a new repo with a library and an expect test; run `dune test`
   without the `-source-tree-root .` flag and record the error
   (expected: `Sys_error "../foo.ml: No such file or directory"`), then fix it.
2. Write the CI workflow for a repo depending on `order-book`; list the pins it
   needs in order (expected: `fixed-decimal`, `exchange-core`, `order-book`).
3. With `opam install --dry-run async_websocket`, check which version opam
   would pick and say whether it is the stub (v0.13.0) or the ox preview.

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
