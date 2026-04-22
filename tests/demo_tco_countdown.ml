let rec count = fun n -> if n = 0 then print_endline "done" else (print_int n; count (n - 1)) in count 100
