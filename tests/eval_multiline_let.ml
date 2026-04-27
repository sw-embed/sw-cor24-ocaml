let counter = ref 0
let bump_and_get x =
  let prev = !counter in
  let _ = counter := prev + x in
  !counter
let _ = print_int (bump_and_get 5)
let _ = putc 32
let _ = print_int (bump_and_get 7)
let _ = putc 32
let _ = print_int !counter
