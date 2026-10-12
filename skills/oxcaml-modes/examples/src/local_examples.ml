open! Core

type point =
  { x : int
  ; y : int
  }

let manhattan (p @ local) = abs p.x + abs p.y

let midpoint (a @ local) (b @ local) = exclave_
  { x = (a.x + b.x) / 2; y = (a.y + b.y) / 2 }
;;

let path_length steps =
  List.fold steps ~init:0 ~f:(fun acc (dx, dy) ->
    let local_ step = { x = dx; y = dy } in
    acc + manhattan step)
;;

let sum_by xs ~(f @ local) = List.fold xs ~init:0 ~f:(fun acc x -> acc + f x) [@nontail]

let weighted_sum xs ~weight =
  let local_ w = { x = weight.x; y = weight.y } in
  sum_by xs ~f:(fun v -> v * manhattan w) [@nontail]
;;

type labelled =
  { qty : int
  ; global_ owner : string
  }

let owner_of_local ~qty ~owner =
  let local_ r = { qty; owner } in
  ignore (r.qty : int);
  r.owner
;;
