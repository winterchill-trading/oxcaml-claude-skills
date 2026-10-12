(* A float result crossing a function boundary is boxed: 16 bytes. *)
let[@zero_alloc] spread_ratio (bid : float) (ask : float) = (ask -. bid) /. bid
