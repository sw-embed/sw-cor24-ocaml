let r = ref 0
!r
r := 41
!r + 1
let xs = ref [] in xs := 1 :: !xs; xs := 2 :: !xs; !xs
let make_counter start = let r = ref start in fun _ -> r := !r + 1; !r
let c = make_counter 10
c ()
c ()
let registry = ref [] in registry := ("syntax", 1) :: !registry; List.length !registry
