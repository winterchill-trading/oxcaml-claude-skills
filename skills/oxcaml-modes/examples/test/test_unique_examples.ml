open! Core
open Modes_examples

let%expect_test "a unique counter threaded through updates" =
  let c = Unique_examples.create () in
  let c = Unique_examples.incr c in
  let c = Unique_examples.incr c in
  print_s [%sexp (Unique_examples.get (borrow_ c) : int)];
  [%expect {| 2 |}];
  print_s [%sexp (Unique_examples.finish c : int)];
  [%expect {| 2 |}];
  print_s [%sexp (Unique_examples.count_to 1_000 : int)];
  [%expect {| 1000 |}]
;;

let%expect_test "borrow_ reads without consuming" =
  let c = Unique_examples.create () in
  let seen, c = Borrow_examples.peek_then_incr c in
  let seen', c = Borrow_examples.peek_then_incr c in
  print_s [%message (seen : int) (seen' : int) (Unique_examples.finish c : int)];
  [%expect {| ((seen 0) (seen' 1) ("Unique_examples.finish c" 2)) |}];
  print_s [%sexp (Borrow_examples.history 4 : int list)];
  [%expect {| (0 1 2 3) |}]
;;
