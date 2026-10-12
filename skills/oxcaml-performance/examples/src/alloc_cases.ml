open! Core

type book =
  { bids : int array
  ; mutable n : int
  }

let[@inline never] best_opt b = if b.n = 0 then None else Some b.bids.(b.n - 1)

let[@inline never] best_local b : int option @ local =
  if b.n = 0 then exclave_ None else exclave_ Some b.bids.(b.n - 1)
;;

let[@inline never] best_or_null b : int or_null =
  if b.n = 0 then Null else This b.bids.(b.n - 1)
;;

let use_opt b =
  match best_opt b with
  | None -> 0
  | Some x -> x
;;

let use_local b =
  match best_local b with
  | None -> 0
  | Some x -> x
;;

let use_or_null b =
  match best_or_null b with
  | Null -> 0
  | This x -> x
;;

let[@inline never] mid_micro_tuple bid ask bq aq =
  let mid = (bid + ask) / 2 in
  let micro = ((bid * aq) + (ask * bq)) / (aq + bq) in
  mid, micro
;;

let[@inline never] mid_micro_unboxed bid ask bq aq =
  let mid = (bid + ask) / 2 in
  let micro = ((bid * aq) + (ask * bq)) / (aq + bq) in
  #(mid, micro)
;;

let use_tuple () =
  let a, b = mid_micro_tuple 100 102 5 7 in
  a + b
;;

let use_unboxed () =
  let #(a, b) = mid_micro_unboxed 100 102 5 7 in
  a + b
;;

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

let[@inline never] step_boxed (s : st_boxed) x =
  { var = (0.9 *. s.var) +. (0.1 *. x *. x)
  ; alpha = (0.5 *. s.alpha) +. x
  ; count = s.count + 1
  }
;;

let[@inline never] step_mixed (s : st_mixed) x =
  { var_u = Float_u.O.((#0.9 * s.var_u) + (#0.1 * x * x))
  ; alpha_u = Float_u.O.((#0.5 * s.alpha_u) + x)
  ; count_u = s.count_u + 1
  }
;;

let[@inline never] step_mut (s : st_mut) x =
  s.mvar <- Float_u.O.((#0.9 * s.mvar) + (#0.1 * x * x));
  s.malpha <- Float_u.O.((#0.5 * s.malpha) + x);
  s.mcount <- s.mcount + 1
;;

let[@inline never] sum_rec (a : float array) =
  let rec go i acc = if i = Array.length a then acc else go (i + 1) (acc +. a.(i)) in
  go 0 0.
;;

let[@inline never] sum_mutable (a : float array) =
  let mutable acc = 0. in
  for i = 0 to Array.length a - 1 do
    acc <- acc +. a.(i)
  done;
  acc
;;

let[@inline never] sum_rec_unboxed (a : float array) =
  let rec go i acc =
    if i = Array.length a
    then acc
    else go (i + 1) (Float_u.add acc (Float_u.of_float a.(i)))
  in
  Float_u.to_float (go 0 #0.)
;;
