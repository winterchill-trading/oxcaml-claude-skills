(** Pairs of functions doing the same work with and without heap allocation. Every
    function is [@inline never] so a caller measures the call, not an inlined copy. *)

type book =
  { bids : int array
  ; mutable n : int
  }

val best_opt : book -> int option
val best_local : book -> int option @ local
val best_or_null : book -> int or_null
val use_opt : book -> int
val use_local : book -> int
val use_or_null : book -> int
val mid_micro_tuple : int -> int -> int -> int -> int * int
val mid_micro_unboxed : int -> int -> int -> int -> #(int * int)
val use_tuple : unit -> int
val use_unboxed : unit -> int

type st_boxed =
  { var : float
  ; alpha : float
  ; count : int
  }

type st_mixed =
  { var_u : Float_u.t
  ; alpha_u : Float_u.t
  ; count_u : int
  }

type st_mut =
  { mutable mvar : Float_u.t
  ; mutable malpha : Float_u.t
  ; mutable mcount : int
  }

val step_boxed : st_boxed -> float -> st_boxed
val step_mixed : st_mixed -> Float_u.t -> st_mixed
val step_mut : st_mut -> Float_u.t -> unit

(** Summing a float array three ways: self-tail recursion with a [float] accumulator
    (boxes every iteration, even at -O3), [let mutable], and a [float#] accumulator. *)
val sum_rec : float array -> float

val sum_mutable : float array -> float
val sum_rec_unboxed : float array -> float
