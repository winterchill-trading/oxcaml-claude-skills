(* Rejected: a value is consumed in the same expression that borrows it. *)
type t = { mutable x : int }

let consume (t @ unique) =
  t.x <- 1;
  t
;;

let both (t @ unique) = (fun (u @ local) -> u.x) (borrow_ t) + (consume t).x
