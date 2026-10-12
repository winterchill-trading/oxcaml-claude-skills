---
name: janestreet-ocaml-style
description: Write OCaml in the Jane Street style using Base/Core/Async and ppx_jane. Use when a dune project depends on core, base, async or ppx_jane, or when the user asks for Jane Street conventions.
---

# Jane Street style OCaml

- `open! Core` (or `open! Base` in libraries that must stay small) at the top
  of every file. Stdlib functions are shadowed; use `List.map ~f`, `Int.to_string`,
  `String.split ~on`, labelled arguments everywhere.
- Derive with `[@@deriving sexp, compare, equal, hash]`; use
  `[@@deriving sexp_of]` only on types containing functions or abstract parts.
- Modules: `module Foo : sig ... end = struct ... end` with `.mli` files for
  every library module. Use `Comparable.Make`, `Hashable.Make`, `Identifiable`.
- Tests: `ppx_expect` in a `test/` dune library with `(inline_tests)` and
  `(preprocess (pps ppx_jane))`; run `dune test`, then `dune promote` to accept
  new `[%expect]` output. Property tests with `Base_quickcheck`.
- Async: `let%bind` / `let%map` from `ppx_let`, `Deferred.t` everywhere, never
  block. Entry point via `Command.async`.
- `.ocamlformat` with `profile = janestreet`; run `dune fmt` before committing.
- Errors: `Or_error.t` for recoverable, `raise_s [%message ...]` for bugs.
- No `Obj.magic`, `Obj.repr` or `Obj.obj`: they undo every type guarantee the
  rest of these rules buy. `scripts/check-obj-magic.sh` enforces this in CI;
  a genuine need goes in `.obj-magic-allowlist` with the reason beside it.
