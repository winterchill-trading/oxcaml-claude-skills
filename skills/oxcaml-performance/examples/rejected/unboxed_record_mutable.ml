(* Unboxed record fields cannot be mutable; use a boxed record with float# fields. *)
type t = #{ mutable qty : int }
