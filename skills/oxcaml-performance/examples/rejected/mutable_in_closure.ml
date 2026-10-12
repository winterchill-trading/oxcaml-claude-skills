(* let mutable cannot be captured by a closure; use a for or while loop. *)
let total l =
  let mutable s = 0 in
  List.iter (fun x -> s <- s + x) l;
  s
;;
