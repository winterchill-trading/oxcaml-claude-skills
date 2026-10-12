open! Core

(** One compiling example per technique in the oxcaml-performance skill. *)

(** {1 zero_alloc} *)

val add_mul : int -> int -> int -> int [@@zero_alloc]
val sum : int array -> int [@@zero_alloc]
val spread_ratio_u : Float_u.t -> Float_u.t -> Float_u.t [@@zero_alloc]
val check_qty : int -> int [@@zero_alloc]
val check_qty_strict : int -> int [@@zero_alloc strict]

(** {1 Unboxed numbers and products} *)

val notional : Float_u.t -> Float_u.t -> Float_u.t
val next_ts : int64# -> int64#
val div_mod : int -> int -> #(int * int) [@@zero_alloc]
val bid_ask : int -> #(bid:int * ask:int) [@@zero_alloc]
val width : int -> int

type level =
  #{ price : int
   ; qty : int
   }

val add_level : level -> level -> level [@@zero_alloc]

type fill =
  { symbol : string
  ; price : Float_u.t
  ; qty : Float_u.t
  ; exch_ts : int64#
  ; mutable seq : int
  }

val make_fill : string -> float -> float -> fill
val fill_notional : fill -> float

(** {1 Immediate types} *)

module Px : sig
  type t : immediate

  val of_int : int -> t
  val to_int : t -> int
end

(** {1 Labeled tuples, small numbers, iarray} *)

val min_max : int array -> min:int * max:int
val levels : int iarray
val small : int8 * float32
val i16_to_int : int16# -> int

(** {1 Templates} *)

type pair =
  { a : int
  ; b : int
  }

val use_local_swap : int -> int
val use_global_swap : int -> int

(** {1 Intrinsics and buffers} *)

val clz : int -> int
val popcount : int -> int
val read_header : Bigstring.t -> pos:int -> int [@@zero_alloc]
val iobuf_sum : (read, Iobuf.seek, Iobuf.global) Iobuf.t -> int

(** {1 Portability} *)

val double : int -> int @@ portable

module Counter : sig
  type t

  val create : unit -> t
  val incr : t @ contended -> unit @@ portable
  val get : t @ contended -> int @@ portable
end
