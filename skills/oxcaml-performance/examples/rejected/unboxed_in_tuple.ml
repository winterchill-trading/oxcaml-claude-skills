(* A boxed tuple cannot hold float#; return #(x, x) instead. *)
let pair (x : float#) = x, x
