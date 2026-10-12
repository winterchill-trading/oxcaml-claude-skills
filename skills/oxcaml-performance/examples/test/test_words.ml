open! Core
open Perf_examples

(* Exact minor-heap words per call. These are the numbers to pin when optimising: a change
   that brings an allocation back shows up as a diff. *)
let words_per_call f =
  let n = 1_000 in
  let before = Gc.minor_words () in
  for _ = 1 to n do
    f ()
  done;
  (Gc.minor_words () - before) / n
;;

let print name f = printf "%-40s %d\n" name (words_per_call f)
let sink = ref 0
let book = { Alloc_cases.bids = Array.init 64 ~f:Fn.id; n = 64 }
let floats = Array.init 1000 ~f:Float.of_int

let%expect_test "option-like results" =
  print "best_bid: option" (fun () -> sink := Alloc_cases.use_opt book);
  print "best_bid: local option" (fun () -> sink := Alloc_cases.use_local book);
  print "best_bid: or_null" (fun () -> sink := Alloc_cases.use_or_null book);
  print "two results: tuple" (fun () -> sink := Alloc_cases.use_tuple ());
  print "two results: unboxed tuple" (fun () -> sink := Alloc_cases.use_unboxed ());
  [%expect
    {|
    best_bid: option                         2
    best_bid: local option                   0
    best_bid: or_null                        0
    two results: tuple                       3
    two results: unboxed tuple               0
    |}]
;;

let%expect_test "float state" =
  let sb = ref { Alloc_cases.var = 1.; alpha = 0.; count = 0 } in
  print "boxed float fields, copy" (fun () -> sb := Alloc_cases.step_boxed !sb 0.5);
  let sm = ref { Alloc_cases.var_u = #1.; alpha_u = #0.; count_u = 0 } in
  print "float# fields, copy" (fun () -> sm := Alloc_cases.step_mixed !sm #0.5);
  let st = { Alloc_cases.mvar = #1.; malpha = #0.; mcount = 0 } in
  print "float# fields, mutable" (fun () -> Alloc_cases.step_mut st #0.5);
  [%expect
    {|
    boxed float fields, copy                 8
    float# fields, copy                      4
    float# fields, mutable                   0
    |}]
;;

let%expect_test "float loops (1000 elements)" =
  print "recursion, float accumulator" (fun () ->
    sink := Float.to_int (Alloc_cases.sum_rec floats));
  print "let mutable" (fun () -> sink := Float.to_int (Alloc_cases.sum_mutable floats));
  print "recursion, float# accumulator" (fun () ->
    sink := Float.to_int (Alloc_cases.sum_rec_unboxed floats));
  [%expect
    {|
    recursion, float accumulator             2005
    let mutable                              2
    recursion, float# accumulator            2
    |}]
;;

let frame =
  {|{"stream":"btcusdt@aggTrade","data":{"e":"aggTrade","E":1791817544988,"a":3482328964,"s":"BTCUSDT","p":"82613.60","q":"0.005","nq":"0.005","f":8165283112,"l":8165283113,"T":1791817544843,"m":false,"st":1}}|}
;;

let%expect_test "trade scanner" =
  let t = Json_scan.create () in
  print "scan_trade" (fun () -> ignore (Json_scan.scan_trade frame t : bool));
  print_s [%message (t.px : int) (t.qty : int) (t.ts : int) (t.buyer_maker : bool)];
  let missing_keys = Json_scan.scan_trade {|{"data":{"p":"1"}}|} t in
  print_s [%message (missing_keys : bool)];
  [%expect
    {|
    scan_trade                               0
    ((t.px 8261360000000) (t.qty 500000) (t.ts 1791817544843)
     (t.buyer_maker false))
    (missing_keys false)
    |}]
;;
