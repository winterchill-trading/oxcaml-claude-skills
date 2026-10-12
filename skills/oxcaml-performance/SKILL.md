---
name: oxcaml-performance
description: Make OxCaml hot paths faster with verified syntax for or_null, unboxed numbers and tuples (float#, int64#, #(a, b)), records with float# fields, let mutable, [@zero_alloc], stack_/exclave_, [@inline]/[@unrolled]/[@@loop], -O3, ocaml_intrinsics and zero-allocation parsing, plus the checklist to follow before optimising. Use when asked to speed up, reduce allocation in, or benchmark OCaml/OxCaml code, or when an error mentions zero_alloc, float64 layout, value_or_null, or "Mutable variable cannot be used inside a function".
---

# OxCaml performance

Verified on `5.2.0+ox` (flambda2; arm64 locally, amd64 in CI), dev profile, no `-extension`
flags. Research notes with measurements and sources:
`specs/research/oxcaml-performance/` in the specs repository; the org hot-path audit is
`audit.md` there. Mode rules and their errors are in the `oxcaml-modes` skill.

## Outcomes

1. Measure words per call and time before and after, in three builds.
2. Remove an option, tuple or float box from a hot function and pin 0 words in an
   expect test.
3. Prove a function allocation-free with `[@zero_alloc]` in its `.mli`.
4. Replace a JSON tree decode on a hot stream with a zero-allocation scanner and a
   fallback.
5. Read a layout or zero_alloc error and name the fix from this page.

## Checklist before optimising

1. Is there a bench? If not, add one (`core_bench`) and a words-per-call expect test
   first. Record the baseline in the repo README or `specs/repos/<repo>.md`.
2. Find the allocation, not the instruction: words per call per function, with the
   callee `[@inline never]` when asking "does this call allocate".
3. Prefer not building the structure at all (scanner instead of a JSON tree, precomputed
   key instead of a per-frame record and hash) over making the structure cheaper.
4. Then pick the smallest technique from the table below. Keep the old function as the
   reference and test the new one against it (fixtures or a quickcheck bisimulation).
5. Rebuild dev, `--profile release`, and release with `OCAMLPARAM='_,O3=1'`; report all
   three. Under 0.5 ns is noise; words are exact.
6. Pin the new words-per-call number in an expect test, and add `[@zero_alloc]` to the
   `.mli` where the function passes in the dev profile.
7. Log anything surprising in `GOTCHAS.md`.

## Which technique

| Allocation seen | Use | Measured here |
| --- | --- | --- |
| `Some x` returned and matched | `x or_null` (`Null`/`This`) or `option @ local` + `exclave_` | 2 to 0 words |
| tuple returned from a non-inlined call | `#(a, b)`, labeled `#(~bid:a, ~ask:b)` | 3 to 0 words |
| `float` fields copied per update | mutable record with `Float_u.t` fields | 8 to 0 words |
| float accumulator in recursion | `let mutable` loop or `float#` accumulator | 2000 to 2 words per 1000 |
| JSON tree per frame | `[@zero_alloc]` scanner into a reused record | 298 to 0 words, 2.4 us to 0.26 us |
| short-lived record or closure | `stack_` / `local` (see `oxcaml-modes`) | 0 words |
| cross-functor comparison not inlined | `type t : immediate` and `-O3` | order-book 66 to 37 ns |

## Syntax

```ocaml
(* or_null and local option *)
let best b : int or_null = if b.n = 0 then Null else This b.bids.(b.n - 1)
let best_local b : int option @ local =
  if b.n = 0 then exclave_ None else exclave_ Some b.bids.(b.n - 1)

(* unboxed numbers: library unboxed.float_u gives Float_u with compare/equal/sexp *)
let spread_ratio_u bid ask = Float_u.O.((ask - bid) / bid)     (* Float_u.t = float# *)
let one_bp = #0.0001
let ts : int64# = #1_700_000_000_000_000_000L

(* unboxed tuples and records *)
let[@zero_alloc] div_mod a b = #(a / b, a mod b)
let #(q, r) = div_mod 7 2
type level = #{ price : int; qty : int }
let add (a : level) b = #{ price = a.#price; qty = a.#qty + b.#qty }

(* mixed block, updated in place *)
type st = { mutable var : Float_u.t; mutable count : int }

(* let mutable *)
let[@zero_alloc] sum (a : int array) =
  let mutable acc = 0 in
  for i = 0 to Array.length a - 1 do acc <- acc + Array.unsafe_get a i done;
  acc

(* zero_alloc in a signature: either form *)
val sum : int array -> int [@@zero_alloc]
val[@zero_alloc] sum : int array -> int
val check : int -> int [@@zero_alloc strict]   (* error paths too *)

(* inlining *)
let[@inline never] cold x = failwithf "bad %d" x ()
let pow2_unrolled n = (pow2 [@unrolled 3]) n           (* call site, not definition *)
let rec count n acc = if n = 0 then acc else count (n - 1) (acc + n) [@@loop]

(* immediate abstract type *)
module Px : sig type t : immediate end = struct type t = int end

(* one source, local and global copies *)
let%template[@mode m = (global, local)] swap (p : pair @ m) : pair @ m =
  { a = p.b; b = p.a } [@exclave_if_local m]
let q = (swap [@mode local]) p

(* intrinsics and buffers *)
Ocaml_intrinsics.Int.count_leading_zeros x
Bigstring.get_int64_le_trunc b ~pos                     (* [@zero_alloc] ok *)
(buf : (read, Iobuf.seek, Iobuf.global) Iobuf.t)        (* three type parameters *)
```

## Errors and fixes

- `The layout of float# is float64 ... must be a value layout because the type argument
  of option ...` (or `... a tuple element`): unboxed values cannot go in `option`, lists or
  boxed tuples. Use `#(...)`, a record field, or keep it boxed at that boundary.
- `Annotation check for zero_alloc failed ... allocation of 16 bytes for float`: a boxed
  float result or argument. Use `Float_u.t`, or inline the caller.
- `... zero_alloc strict failed ... allocation of 24 bytes on a path to exceptional
  return`: the error message is formatted. Use a literal message or drop `strict`.
- `called function may allocate (indirect call)`: a closure or functor argument; zero_alloc
  code cannot call `List.iter`, `Map`, `Hashtbl` or Yojson.
- `Mutable variable cannot be used inside a function`: a closure captured a
  `let mutable`; use a loop.
- `Unboxed record labels cannot be mutable`: put the fields in a boxed record instead.
- `Unbound value "compare_float_u"` (or `equal_`, `hash_fold_`, `bin_shape_`) from
  `[@@deriving]`: write the field type as `Float_u.t` from `unboxed.float_u`.
- `Unbound value "Float_u.mul"`: `unboxed.float_u` has `add`, `sub` but no `mul`/`div`
  at top level; use `Float_u.O.( * )`, or `Stdlib_upstream_compatible.Float_u.mul`.
- `This value is "contended" ... expected to be "portable"`: a closure for another domain
  touches a captured `ref`. Use `Atomic`, or pass data in and results out.
- Warning 53 `the "unrolled" attribute cannot appear in this context`: `[@unrolled n]`
  goes on the call (`(f [@unrolled 3]) x`).

## Gated on this switch

- SIMD: no `ocaml_simd*` installed; amd64 only per oxcaml.org; dev machines are arm64.
- `parallel` and `Multicore` libraries not installed; `Domain.Safe.spawn` works with
  `[@alert "-do_not_spawn_domains"]`.
- `[%probe]` compiles but `probes: false`: it is ignored.
- Loopification does not unbox a `float` loop variable, even at `-O3` with `[@@loop]`.
- Polymorphic `compare`/`=`/`Hashtbl.hash` on a record with `float#` fields compiles and
  raises `Invalid_argument("compare: mixed block value")` at run time.

## Compiling examples

`examples/` is a dune project built in CI: `src/alloc_cases.ml` (each pair of
allocating and non-allocating versions), `src/json_scan.ml` (the trade scanner),
`src/syntax_examples.ml` (one compiling example per technique), `test/test_words.ml`
(words per call pinned in expect tests) and `rejected/` (each file must fail with the
error in its `.expected`).

```sh
cd skills/oxcaml-performance/examples
opam exec --switch 5.2.0+ox -- dune build --root . @all @runtest
```

## Exercises

1. Change `Alloc_cases.best_or_null` to return `int option`; predict the diff in
   `test_words.ml` (0 to 2).
2. Remove `[@@zero_alloc]` from `Json_scan.find_key` in the `.mli` and add a
   `String.sub` to it; predict which annotation fails and why.
3. Make `Alloc_cases.sum_rec` allocation-free without changing its type.
4. Fix a file in `rejected/` and keep the original rejected.
