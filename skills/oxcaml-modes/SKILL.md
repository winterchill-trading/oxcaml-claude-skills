---
name: oxcaml-modes
description: Use OxCaml's local_/exclave_/global_ stack-allocation modes, @ local callbacks, @ unique values and borrow_ correctly, with the exact compiler errors and fixes. Use when writing or debugging OxCaml code that mentions local_, exclave_, global_, @ local, @ unique, borrow_, [@nontail], or "This value is local" / "used as unique" errors.
---

# OxCaml modes in practice

Verified on `5.2.0+ox` with Core/Base from the ox opam repository.

## Outcomes

1. Stack-allocate a record in a hot loop and prove it allocates nothing on the
   heap (`Gc.minor_words` delta of 0 in an expect test).
2. Return a local record from a (recursive) function with `exclave_`.
3. Take and pass `@ local` callbacks, with `[@nontail]` where needed.
4. Thread a `@ unique` value through in-place updates, reading it with
   `borrow_` between steps.
5. Read a mode error and name the fix from this page.

## Reference modules (org repos)

| File | Shows |
|------|-------|
| `order-book/lib/order_book.ml` | `local_` taker record, recursive `exclave_ sweep`, `global_` fields, `[@nontail]` |
| `order-book/lib/order_book.mli` | `val iter : t -> f:(Resting_order.t -> unit) @ local -> unit` |
| `examples/src/local_examples.ml` | Local arguments, `exclave_` results, local closures |
| `examples/src/unique_examples.ml`, `examples/src/borrow_examples.ml` | `@ unique` threading and `borrow_` |
| `examples/rejected/` | One file per compiler error, with the pinned error text |

## Exercises

1. Make `Local_examples.manhattan` remember its last argument in a global
   `ref`; predict the error (expected: `This value is "local" but is expected
   to be "global"`, at a caller passing a `local_` point). Note that dropping
   `@ local` from the `.ml` alone still compiles: modes are inferred, and the
   annotation only matters once the body lets the value escape.
2. Write `Unique_examples.reset : counter @ unique -> counter @ unique` and a
   test that reads it through `borrow_` before and after.
3. Remove `[@nontail]` from `Local_examples.sum_by` and explain the error.
4. Copy a file from `rejected/` and fix it; the fix must compile and the
   original must still be rejected.


## Stack-allocating a record

```ocaml
type ctx = { qty : int; global_ owner : Address.t }   (* heap values escaping must be global_ *)
let local_ taker = { qty; owner } in
sweep (local_ (taker : ctx))
```

Any field whose value is later stored into a heap structure (a fill list,
a Map) must be marked `global_`.

## Returning a local value

A function returning a local record must build it with `exclave_`, and a
recursive call in return position must also be `exclave_ f ...`, else:

```
This value is "local" but is expected to be "local" to the parent region or
"global" because it is a function return value. Hint: Use exclave_
```

Do not return a local *tuple* when you need its elements on the heap:

```
This value is "local" because it is an element of the tuple ... However,
the highlighted expression is expected to be "global".
```

Return a record with `global_` fields instead.

## Local callbacks

```ocaml
val iter : t -> f:(elt -> unit) @ local -> unit
let iter t ~(f @ local) = ...
```

A plain `~f` in the implementation fails the `.mli` check with
`Values do not match ... is not included in ... @ local`. Base's `Map.iter`
and `Queue.iter` already take `@ local` callbacks in the ox build. A closure
capturing `f` passed in tail position fails with
`... expected to be "local" to the parent region or "global" because it is an
argument in a tail call`; add `[@nontail]` to the call.

## Tail calls with local arguments

A value allocated in the current region cannot be passed to a call in tail
position, because the tail call would outlive the region:

```
This value is "local"
but is expected to be "local" to the parent region or "global"
  because it is an argument in a tail call.
```

Add `[@nontail]` to the call (the recursion then uses stack), fold instead of
recursing, or allocate with `exclave_` into the caller's region.

## Uniqueness: `@ unique`

A unique value has no other live reference; a function taking it `@ unique`
consumes it and may update it in place, returning it `@ unique` again.

```ocaml
val create : unit -> counter @ unique
val incr : counter @ unique -> counter @ unique
val get : counter @ local -> int            (* reads, does not consume *)

let rec go (c @ unique) i = if i = 0 then finish c else go (incr c) (i - 1)
```

No extension flag is needed on `5.2.0+ox`. Errors:

- Consumed twice: `This value is used here, but it has already been used as
  unique at: ...`
- A top-level or captured value is aliased: `This value is aliased but used as
  unique. Hint: This value comes from outside the current module or class.`
- Passing a unique value to an `@ local` parameter is still a use; consuming it
  afterwards fails with `This value is used here as unique, but it has already
  been used at: ...`. Borrow instead (below).
- A tuple returned without `@ unique` makes its elements aliased:
  `This value is "aliased" because it is an element of the tuple ...`. Write
  `-> int * counter @ unique` in the `.mli` so callers can destructure it.

## Borrowing: `borrow_`

`borrow_ x` lends a unique `x` as a local value for one call without consuming
it, so `x` can be consumed afterwards:

```ocaml
let peek_then_incr (c @ unique) =
  let seen = get (borrow_ c) in
  seen, incr c
```

- The borrow is local: storing it on the heap fails with `This value is "local"
  because it is borrowed. However, the highlighted expression is expected to be
  "global".`
- Borrowing and consuming in one expression fails with `This value is used here
  as unique, but it is also being borrowed at: ...`; finish the borrow in a
  `let` first.

## Compiling examples

`examples/` is a dune project (built in CI) with every pattern above:
`src/local_examples.ml`, `src/unique_examples.ml`, `src/borrow_examples.ml`,
expect tests in `test/` (one shows a loop of local records allocating 0 minor
heap words against 6000 for the heap version), and `rejected/`, where each file
must fail to compile with the error pinned in its `.expected` file. When the
compiler changes an error text, `dune runtest` shows the diff; update the text
here when promoting it.

## Tooling

- `ocamlformat` with `profile = janestreet` preserves all mode syntax.
- `OCAMLRUNPARAM=l=...` does not prove tail-call-ness of `exclave_` recursion;
  inspect `-dcmm` output if it matters.
- Budget mode experiments: if a construct fails twice, drop it and keep the
  plain version. Modes pay off in hot loops (matching engine), not in codecs.
