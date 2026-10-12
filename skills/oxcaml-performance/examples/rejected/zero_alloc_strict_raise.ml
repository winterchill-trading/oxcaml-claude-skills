(* Strict also checks the raising path; the formatted message allocates. *)
let[@zero_alloc strict] check q = if q <= 0 then failwith (string_of_int q) else q
