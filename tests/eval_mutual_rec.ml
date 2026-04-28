let rec count_a xs n = match xs with [] -> n | h :: t -> count_b t (n + h)
and count_b ys n = match ys with [] -> n | h :: t -> count_a t (n + h * 10)
let _ = print_int (count_a [1; 2; 3; 4] 0)
let _ = putc 32
let _ = print_int (count_b [1; 2; 3; 4] 0)
