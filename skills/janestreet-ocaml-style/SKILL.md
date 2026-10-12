---
name: janestreet-ocaml-style
description: Write OCaml in the Jane Street style using Base/Core/Async and ppx_jane. Use when a dune project depends on core, base, async or ppx_jane, or when the user asks for Jane Street conventions.
---

# Jane Street style OCaml

## Outcomes

After reading this skill a session should be able to:

1. Add a module to a library with an `.mli`, ppx_jane derivations and labelled
   arguments, and have `dune build @all @runtest` and `dune fmt` pass.
2. Make two numeric types that cannot be mixed up (a generative functor) and
   re-export them from another library with type equality kept.
3. Fix a bug test-first: an expect test showing the wrong output, then the fix.
4. Write a `Base_quickcheck` property for a function's contract and pin a shrunk
   counterexample.

## Reference modules (org repos)

| File | Shows |
|------|-------|
| `fixed-decimal/lib/fixed_decimal.mli` | `Make ()` generative functor, `Comparable`/`Hashable`, documented `.mli` |
| `exchange-core/lib/price.mli` | Re-export with type and `comparator_witness` equality |
| `mm-core/lib/params.mli` | Validated config record with `Or_error` |
| `mm-core/test/test_properties.ml` | Base_quickcheck contract properties |
| `order-book/test/test_bisim.ml` | Bisimulation against a naive model with Quickcheck |
| `market-data/lib/trade.mli` | `Stable.V1` types with pinned `[%bin_digest]` in tests |

## Exercises

1. In `fixed-decimal`, write a test that `Price.t` and `Size.t` do not unify
   (expected: a type error naming both types when the test is uncommented).
2. Add `Fixed_decimal.abs` to the `.mli` first, build to see the error, then
   implement it with an expect test and a quickcheck property
   (`abs x >= zero`, `abs (neg x) = abs x`).
3. Take any quickcheck property, break the function on purpose, and pin the
   shrunk counterexample in `~examples`; revert the break and keep the example.

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

## Agent workflow

1. **Plan, then get it reviewed.** Before editing, write the plan as a short
   list: which `.mli` files change, which types are added, which tests prove
   it. Show it to the user (or the orchestrating agent) for anything that
   touches a public interface, and keep each change small enough to review
   (tens to a few hundred lines).
2. **Signatures and types first.** Write the `.mli` before the `.ml`. For a
   new venue or backend, write the module type (`Venue.S`, `Feed.S`) or the
   functor seam first and make an empty implementation compile. For a
   refactor, change the type in the `.mli`, run `dune build`, and fix the
   errors in dependency order; the compiler's error list is the to-do list.
   Then rerun the expect tests and read every diff.
3. **State the contract as a property.** Each public `.mli` change comes with
   a `Base_quickcheck` property for the function's contract (round trips,
   invariants, monotonicity), not only hand-picked examples.
4. **Failing test before the fix.** A bug fix lands as an expect test that
   shows the wrong output first (commit it, or keep it in the same commit with
   the old output visible in the history of the change), then the fix that
   changes the trace. A fix without a test that would have caught it is not
   done.
5. **Pin counterexamples.** When Quickcheck finds a failure, copy the shrunk
   value into the property's `~examples` (or a dedicated expect test) in the
   same change as the fix, so it is checked on every run, not only when the
   random seed finds it again.
6. **Justify removals.** Before deleting a function, test, field or
   dependency, say why in the commit message: who used it, what replaces it,
   and which test shows nothing depended on it. Never delete a failing test to
   get a green build.
