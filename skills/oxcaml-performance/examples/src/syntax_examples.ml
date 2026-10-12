open! Core

let[@zero_alloc] add_mul a b c = (a + b) * c

let[@zero_alloc] sum (a : int array) =
  let mutable acc = 0 in
  for i = 0 to Array.length a - 1 do
    acc <- acc + Array.unsafe_get a i
  done;
  acc
;;

let[@zero_alloc] spread_ratio_u bid ask = Float_u.O.((ask - bid) / bid)

(* Relaxed: the allocation on the raising path is ignored. *)
let[@zero_alloc] check_qty q = if q <= 0 then failwithf "bad qty %d" q () else q

(* Strict: a literal message is static, so this passes. *)
let[@zero_alloc strict] check_qty_strict q = if q <= 0 then failwith "bad qty" else q
let notional px qty = Float_u.O.(px * qty)
let next_ts (t : int64#) = Stdlib_upstream_compatible.Int64_u.add t #1L
let[@zero_alloc] div_mod a b = #(a / b, a mod b)
let[@zero_alloc] bid_ask px = #(~bid:(px - 1), ~ask:(px + 1))

let width px =
  let #(~bid, ~ask) = bid_ask px in
  ask - bid
;;

type level =
  #{ price : int
   ; qty : int
   }

let[@zero_alloc] add_level (a : level) (b : level) =
  #{ price = a.#price; qty = a.#qty + b.#qty }
;;

type fill =
  { symbol : string
  ; price : Float_u.t
  ; qty : Float_u.t
  ; exch_ts : int64#
  ; mutable seq : int
  }

let make_fill symbol p q =
  { symbol; price = Float_u.of_float p; qty = Float_u.of_float q; exch_ts = #0L; seq = 0 }
;;

let fill_notional f = Float_u.to_float Float_u.O.(f.price * f.qty)

module Px = struct
  type t = int

  let of_int = Fn.id
  let to_int = Fn.id
end

let min_max (a : int array) : min:int * max:int =
  Array.fold a ~init:(~min:Int.max_value, ~max:Int.min_value) ~f:(fun (~min, ~max) x ->
    ~min:(Int.min min x), ~max:(Int.max max x))
;;

let levels : int iarray = [: 1; 2; 3 :]
let small : int8 * float32 = 42s, 1.5s
let i16_to_int x = Stdlib_stable.Int16_u.to_int x

type pair =
  { a : int
  ; b : int
  }

let%template[@mode m = (global, local)] swap (p : pair @ m) : pair @ m =
  { a = p.b; b = p.a } [@exclave_if_local m]
;;

let use_local_swap x =
  let p = stack_ { a = x; b = 1 } in
  let q = (swap [@mode local]) p in
  q.a
;;

let use_global_swap x = (swap { a = x; b = 2 }).a
let clz x = Ocaml_intrinsics.Int.count_leading_zeros x
let popcount x = Ocaml_intrinsics.Int.count_set_bits x

let[@zero_alloc] read_header (b : Bigstring.t) ~pos =
  Bigstring.get_int32_le b ~pos + Bigstring.get_int64_le_trunc b ~pos:(pos + 4)
;;

let iobuf_sum buf =
  let mutable acc = 0 in
  while Iobuf.length buf >= 8 do
    acc <- acc + Iobuf.Consume.int64_le_trunc buf
  done;
  acc
;;

let double x = x * 2

module Counter = struct
  type t = int Atomic.t

  let create () = Atomic.make 0
  let incr t = Atomic.incr t
  let get t = Atomic.get t
end
