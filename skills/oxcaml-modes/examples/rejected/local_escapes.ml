(* Rejected: a local parameter is stored in a heap-allocated ref. *)
let keep (s @ local) = ref s
