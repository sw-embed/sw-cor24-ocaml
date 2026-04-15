let f x = x + 1 in f 5
let square x = x * x in square 7
let add x y = x + y in add 20 22
let rec fact n = if n = 0 then 1 else n * fact (n - 1) in fact 5
let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib 7
let compose f g x = f (g x) in compose (fun x -> x + 1) (fun x -> x * 2) 10
let safe_div x y = if y = 0 then None else Some (x / y) in safe_div 42 6
