open! Core
module U = Unique_examples

let peek_then_incr (c @ unique) =
  let seen = U.get (borrow_ c) in
  seen, U.incr c
;;

let history n =
  let rec go (c @ unique) i acc =
    if i = 0
    then (
      ignore (U.finish c : int);
      List.rev acc)
    else (
      let seen = U.get (borrow_ c) in
      go (U.incr c) (i - 1) (seen :: acc))
  in
  go (U.create ()) n []
;;
