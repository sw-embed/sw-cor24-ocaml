let rec sum = fun l -> if is_empty l then 0 else hd l + sum (tl l) in sum [1;2;3;4;5]
let rec length = fun l -> if is_empty l then 0 else 1 + length (tl l) in length [10;20;30]
let rec map = fun f l -> if is_empty l then [] else (f (hd l)) :: (map f (tl l)) in map (fun x -> x * 2) [1;2;3]
let p = (3, 4) in fst p * fst p + snd p * snd p
List.length [1;2;3;4;5]
List.rev [1;2;3;4;5]
let swap = fun p -> (snd p, fst p) in swap (1, 2)
let rec countdown = fun n -> if n = 0 then [] else n :: countdown (n - 1) in countdown 5
