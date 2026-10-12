(* A closure run on another domain must be portable; mutating a captured ref is a race. *)
let racy () =
  let r = ref 0 in
  let d = (Domain.Safe.spawn [@alert "-do_not_spawn_domains"]) (fun () -> incr r) in
  Domain.join d;
  !r
;;
