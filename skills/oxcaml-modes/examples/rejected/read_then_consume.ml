(* Rejected: passing a unique value to a [@ local] parameter without [borrow_] is a use,
   so consuming it afterwards fails. Write [get (borrow_ t)] instead. *)
type t = { mutable x : int }

let get (t @ local) = t.x

let consume (t @ unique) =
  t.x <- 1;
  t
;;

let read_then_consume (t @ unique) =
  let n = get t in
  n, consume t
;;
