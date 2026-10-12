(* Rejected: a value allocated in this region is passed to a tail call, which would
   outlive the region. Use [@nontail], or fold instead of recursing. *)
type point =
  { x : int
  ; y : int
  }

let rec walk (p @ local) n =
  if n = 0
  then p.x + p.y
  else (
    let local_ next = { x = p.x + 1; y = p.y } in
    walk next (n - 1))
;;
