(* Rejected: a top-level value is aliased, so it cannot be consumed. *)
type t = { mutable x : int }

let consume (t @ unique) =
  t.x <- 1;
  t
;;

let shared = { x = 0 }
let bump () = consume shared
