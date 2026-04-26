let greet = fun name -> print_endline ("hello, " ^ name)
let _ = greet "world"
let _ = greet "tuplet"
let add x y = x + y
let _ = print_int (add 20 22)
let rec fact n = if n = 0 then 1 else n * fact (n - 1)
let _ = print_int (fact 5)
let (a, b) = (3, 4)
let _ = print_int (a + b)
let () = print_endline "done"
