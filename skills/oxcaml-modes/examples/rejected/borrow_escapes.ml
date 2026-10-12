(* Rejected: a borrowed value is local and cannot be stored on the heap. *)
type t = { mutable x : int }

let stash = ref None

let keep (t @ unique) =
  let read u =
    stash := Some u;
    u.x
  in
  read (borrow_ t)
;;
