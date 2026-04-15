Write the canonical pattern-matching demo programs as OCaml source files.

Create tests/demo_patterns.ml with:
  let rec sum = fun l -> match l with [] -> 0 | h :: t -> h + sum t in sum [1;2;3;4;5]
  let rec length = fun l -> match l with [] -> 0 | _ :: t -> 1 + length t in length [10;20;30]
  let rec map = fun f l -> match l with [] -> [] | h :: t -> f h :: map f t in map (fun x -> x * 2) [1;2;3]
  let rec filter = fun f l -> match l with [] -> [] | h :: t -> if f h then h :: filter f t else filter f t in filter (fun x -> x mod 2 = 0) [1;2;3;4;5;6]
  let safe_div = fun x y -> if y = 0 then None else Some (x / y) in safe_div 10 3
  match Some 7 with None -> 0 | Some n -> n + 1
  let classify = fun n -> match n with 0 -> 100 | 1 -> 101 | _ -> 999 in classify 0
  let swap = fun p -> match p with (a, b) -> (b, a) in swap (1, 2)

Add reg-rs baseline.
Add justfile 'demo-match' target.
Update README with pattern matching examples.

This is the final step of phase4-pattern-matching.