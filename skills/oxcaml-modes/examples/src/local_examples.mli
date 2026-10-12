(** Locality: [@ local] values live in the caller's region (on the stack) and must not
    escape it. *)

open! Core

type point =
  { x : int
  ; y : int
  }

(** The parameter is [@ local]: a promise that [manhattan] does not keep it. *)
val manhattan : point @ local -> int

(** Builds the result in the caller's region with [exclave_]. *)
val midpoint : point @ local -> point @ local -> point @ local

(** Stack-allocates one point per step and returns only an [int]. *)
val path_length : (int * int) list -> int

(** A callback taken [@ local] may close over local values of the caller. *)
val sum_by : int list -> f:(int -> int) @ local -> int

(** Uses [sum_by] with a closure capturing a local point. *)
val weighted_sum : int list -> weight:point -> int

type labelled =
  { qty : int
  ; global_ owner : string
  }

(** A local record whose [global_] field can still be stored on the heap. *)
val owner_of_local : qty:int -> owner:string -> string
