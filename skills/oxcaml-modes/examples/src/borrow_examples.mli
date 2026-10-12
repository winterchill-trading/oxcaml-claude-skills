(** Borrowing: [borrow_ x] lends a unique [x] as a [@ local] value for the duration of a
    call, without consuming it. The borrowed value cannot escape, and [x] cannot be
    consumed while a borrow of it is still live. *)

open! Core

(** Reads the counter through a borrow, then consumes it. The result tuple is [@ unique],
    so the caller can destructure it and keep using the counter. *)
val peek_then_incr
  :  Unique_examples.counter @ unique
  -> int * Unique_examples.counter @ unique

(** Increments [n] times and records the value seen before each step. *)
val history : int -> int list
