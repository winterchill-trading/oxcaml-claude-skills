(** A [@zero_alloc] scanner for Binance aggTrade frames: reads price, quantity, trade time
    and the maker flag straight from the frame into a reused record. A real normalizer
    keeps a Yojson fallback for frames where [scan_trade] returns [false]. *)

type trade =
  { mutable px : int (** units of 1e-8 *)
  ; mutable qty : int (** units of 1e-8 *)
  ; mutable ts : int (** milliseconds *)
  ; mutable buyer_maker : bool
  }

val create : unit -> trade

(** Position just after [key] at or after [from], or [-1]. *)
val find_key : string -> from:int -> string -> int
[@@zero_alloc]

(** Decimal at [pos], quoted or bare, as an int scaled by 10^8. *)
val decimal : string -> int -> int
[@@zero_alloc]

val scan_trade : string -> trade -> bool [@@zero_alloc]
