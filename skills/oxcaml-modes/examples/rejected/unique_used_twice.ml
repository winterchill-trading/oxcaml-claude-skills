(* Rejected: a unique value is consumed twice. *)
type t = { mutable x : int }

let consume (t @ unique) =
  t.x <- 1;
  t
;;

let twice () =
  let t = { x = 0 } in
  let _ = consume t in
  consume t
;;
