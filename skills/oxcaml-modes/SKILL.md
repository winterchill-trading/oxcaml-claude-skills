---
name: oxcaml-modes
description: Use OxCaml's local_/exclave_/global_ stack-allocation modes and @ local callbacks correctly, with the exact compiler errors and fixes. Use when writing or debugging OxCaml code that mentions local_, exclave_, global_, @ local, [@nontail], or "This value is local" errors.
---

# OxCaml modes in practice

Verified on `5.2.0+ox` with Core/Base from the ox opam repository.

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

## Tooling

- `ocamlformat` with `profile = janestreet` preserves all mode syntax.
- `OCAMLRUNPARAM=l=...` does not prove tail-call-ness of `exclave_` recursion;
  inspect `-dcmm` output if it matters.
- Budget mode experiments: if a construct fails twice, drop it and keep the
  plain version. Modes pay off in hot loops (matching engine), not in codecs.
