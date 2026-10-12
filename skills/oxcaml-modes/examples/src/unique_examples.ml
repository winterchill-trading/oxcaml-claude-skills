open! Core

type counter = { mutable n : int }

let create () = { n = 0 }

let incr (c @ unique) =
  c.n <- c.n + 1;
  c
;;

let get (c @ local) = c.n
let finish (c @ unique) = c.n

let count_to n =
  let rec go (c @ unique) i = if i = 0 then finish c else go (incr c) (i - 1) in
  go (create ()) n
;;
