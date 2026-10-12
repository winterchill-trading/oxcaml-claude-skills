open! Core

type trade =
  { mutable px : int
  ; mutable qty : int
  ; mutable ts : int
  ; mutable buyer_maker : bool
  }

let create () = { px = 0; qty = 0; ts = 0; buyer_maker = false }
let scale = 8

let[@zero_alloc] find_key s ~from key =
  let n = String.length s
  and k = String.length key in
  let first = String.unsafe_get key 0 in
  let mutable i = from in
  let mutable found = -1 in
  while found < 0 && i + k <= n do
    if not (Char.equal (String.unsafe_get s i) first)
    then i <- i + 1
    else (
      let mutable j = 1 in
      while j < k && Char.equal (String.unsafe_get s (i + j)) (String.unsafe_get key j) do
        j <- j + 1
      done;
      if j = k then found <- i + k else i <- i + 1)
  done;
  found
;;

let[@zero_alloc] decimal s pos =
  let n = String.length s in
  let mutable i = if Char.equal (String.unsafe_get s pos) '"' then pos + 1 else pos in
  let mutable v = 0 in
  let mutable frac = -1 in
  let mutable stop = false in
  while (not stop) && i < n do
    let c = String.unsafe_get s i in
    if Char.is_digit c
    then (
      if frac < scale
      then (
        v <- (v * 10) + (Char.to_int c - 48);
        if frac >= 0 then frac <- frac + 1);
      i <- i + 1)
    else if Char.equal c '.'
    then (
      frac <- 0;
      i <- i + 1)
    else stop <- true
  done;
  let mutable f = if frac < 0 then 0 else frac in
  while f < scale do
    v <- v * 10;
    f <- f + 1
  done;
  v
;;

let[@zero_alloc] int_at s pos =
  let n = String.length s in
  let mutable i = pos in
  let mutable v = 0 in
  while i < n && Char.is_digit (String.unsafe_get s i) do
    v <- (v * 10) + (Char.to_int (String.unsafe_get s i) - 48);
    i <- i + 1
  done;
  v
;;

(* Search forward from the previous key (the venue's field order), falling back to the
   start of "data" if the order ever changes. *)
let[@zero_alloc] next s ~data ~prev key =
  let at = find_key s ~from:(if prev < 0 then data else prev) key in
  if at < 0 then find_key s ~from:data key else at
;;

let[@zero_alloc] scan_trade s (t : trade) =
  let data = find_key s ~from:0 {|"data":|} in
  if data < 0
  then false
  else (
    let p = next s ~data ~prev:data {|"p":|} in
    let q = next s ~data ~prev:p {|"q":|} in
    let ts = next s ~data ~prev:q {|"T":|} in
    let m = next s ~data ~prev:ts {|"m":|} in
    if p < 0 || q < 0 || ts < 0 || m < 0
    then false
    else (
      t.px <- decimal s p;
      t.qty <- decimal s q;
      t.ts <- int_at s ts;
      t.buyer_maker <- Char.equal (String.unsafe_get s m) 't';
      true))
;;
