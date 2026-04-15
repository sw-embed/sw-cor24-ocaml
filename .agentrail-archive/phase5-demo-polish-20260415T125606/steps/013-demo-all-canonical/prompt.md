Final showcase demo running ALL canonical demos from docs/possible-demos.txt.

Create tests/demo_all.ml with every unique demo that now works:

  (* Basics -- already working *)
  42
  1 + 2 * 3

  (* Function-form let *)
  let f x = x + 1 in f 5
  let square x = x * x in square 7
  let add x y = x + y in add 20 22

  (* Recursion *)
  let rec fact n = if n = 0 then 1 else n * fact (n - 1) in fact 5
  let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib 10

  (* Pattern matching *)
  match 3 with 1 -> "one" | 2 -> "two" | _ -> "many"
  let f = function 0 -> "zero" | _ -> "nonzero" in f 5
  let abs x = match x with n when n < 0 -> 0 - n | n -> n in abs (-7)

  (* Lists with higher-order *)
  List.map (fun x -> x * 2) [1;2;3]
  List.filter (fun x -> x mod 2 = 0) [1;2;3;4]
  List.fold_left (+) 0 [1;2;3;4]
  List.init 5 (fun i -> i * i)

  (* Tuples *)
  let (a, b) = (1, 2) in a + b
  let swap (x, y) = (y, x) in swap (10, 20)

  (* ADTs *)
  type color = Red | Green | Blue
  let to_tag = function Red -> 1 | Green -> 2 | Blue -> 3 in to_tag Green

  (* Option *)
  Some 42
  let safe_div x y = if y = 0 then None else Some (x / y) in safe_div 10 3
  match Some 3 with Some x -> x | None -> 0

  (* Strings *)
  print_endline "Hello, World!"
  "OCaml" ^ " rocks"
  print_endline (string_of_int (List.length [1;2;3]))

Add reg-rs baseline, justfile demo-all target, update README.
This is the final step of phase5-demo-polish.

Note: deferred items (won't run):
- let pi = 3.14159  (no floats)
- top-level 'let x = 10' without 'in' (no persistent env)
- let (|>) x f = f x with infix x |> f usage (parser ambiguity)
- string_of_int as first-class function passed to List.map (works if defined)