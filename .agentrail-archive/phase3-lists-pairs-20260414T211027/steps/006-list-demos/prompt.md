Write demo programs using lists and pairs.

Examples:
  let rec sum = fun l -> if is_empty l then 0 else hd l + sum (tl l) in sum [1;2;3;4;5]
  let rec length = fun l -> if is_empty l then 0 else 1 + length (tl l) in length [10;20;30]
  let rec map = fun f l -> if is_empty l then [] else (f (hd l)) :: (map f (tl l)) in map (fun x -> x * 2) [1;2;3]
  let p = (3, 4) in fst p * fst p + snd p * snd p

Add reg-rs baselines for each.
Add to demo-repl session showcase.
This is the final step of the phase3-lists-pairs saga.