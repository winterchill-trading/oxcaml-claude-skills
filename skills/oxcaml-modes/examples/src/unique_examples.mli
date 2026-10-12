(** Uniqueness: a [@ unique] value has no other live reference, so a function that
    consumes it may update it in place and hand it back. Using it again after it was
    consumed is a compile error. *)

open! Core

type counter

(** A fresh value is unique. *)
val create : unit -> counter @ unique

(** Consumes [counter] and returns it, updated in place. *)
val incr : counter @ unique -> counter @ unique

(** Reads without consuming; any mode can be passed to a [@ local] parameter. *)
val get : counter @ local -> int

(** Consumes the counter for good and returns its value. *)
val finish : counter @ unique -> int

(** Threads one unique counter through [n] increments. *)
val count_to : int -> int
