type pair = { x : int; y : int }
let p = { x = 1; y = 2 }
p.x
p.y
let q = { name = "add"; arity = 2; result = Some 42 }
print_endline q.name
q.arity + (match q.result with Some n -> n | None -> 0)
let nested = { outer = p; label = "point" }
let outer = nested.outer in outer.x + outer.y
