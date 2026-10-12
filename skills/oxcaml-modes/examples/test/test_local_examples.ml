open! Core
open Modes_examples.Local_examples

let%expect_test "local arguments and exclave_ results" =
  let local_ a = { x = 2; y = -4 } in
  let local_ b = { x = 6; y = 8 } in
  let m = midpoint a b in
  print_s [%message (manhattan a : int) (m.x : int) (m.y : int)];
  [%expect {| (("manhattan a" 6) (m.x 4) (m.y 2)) |}]
;;

let%expect_test "stack-allocated temporaries" =
  print_s [%sexp (path_length [ 1, 2; -3, 0; 0, -5 ] : int)];
  [%expect {| 11 |}];
  print_s [%sexp (weighted_sum [ 1; 2; 3 ] ~weight:{ x = 1; y = -1 } : int)];
  [%expect {| 12 |}];
  print_endline (owner_of_local ~qty:3 ~owner:"0xabc");
  [%expect {| 0xabc |}]
;;

let%expect_test "local values allocate nothing on the heap" =
  let measure f =
    let before = Gc.minor_words () in
    let total = f () in
    Gc.minor_words () - before, total
  in
  let local_words, local_total =
    measure (fun () ->
      let total = ref 0 in
      for i = 1 to 1_000 do
        let local_ p = { x = i; y = -i } in
        total := !total + manhattan p
      done;
      !total)
  in
  let heap_words, heap_total =
    measure (fun () ->
      let points = ref [] in
      for i = 1 to 1_000 do
        points := { x = i; y = -i } :: !points
      done;
      List.sum (module Int) !points ~f:manhattan)
  in
  print_s
    [%message
      (local_total : int) (heap_total : int) (local_words : int) (heap_words : int)];
  [%expect
    {|
    ((local_total 1001000) (heap_total 1001000) (local_words 0)
     (heap_words 6000))
    |}]
;;
