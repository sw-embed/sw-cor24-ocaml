Create a showcase demo session exercising lists, pairs, higher-order functions, and recursion. Write sum, length, map using only hd/tl/is_empty (no pattern matching needed).

Target: tests/demo_lists_pairs.ml with these examples:
  let rec sum = fun l -> if is_empty l then 0 else hd l + sum (tl l) in sum [1;2;3;4;5]
  let rec length = fun l -> if is_empty l then 0 else 1 + length (tl l) in length [10;20;30]
  let rec map = fun f l -> if is_empty l then [] else (f (hd l)) :: (map f (tl l)) in map (fun x -> x * 2) [1;2;3]
  let p = (3, 4) in fst p * fst p + snd p * snd p
  List.length [1;2;3;4;5]
  List.rev [1;2;3;4;5]

Add reg-rs baseline. Add just demo-lists target. This is the last step of phase3-lists-pairs.