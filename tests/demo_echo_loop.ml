let rec loop = fun u -> let s = read_line () in if s = "quit" then (print_endline "bye"; exit 0) else (print_endline s; loop ()) in loop ()
