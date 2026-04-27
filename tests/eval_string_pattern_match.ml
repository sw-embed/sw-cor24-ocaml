let classify s = match s with "syntax-expand" -> 1 | "syntax-verb" -> 2 | _ -> 0
let _ = print_int (classify "syntax-expand")
let _ = putc 32
let _ = print_int (classify "syntax-verb")
let _ = putc 32
let _ = print_int (classify "other")
