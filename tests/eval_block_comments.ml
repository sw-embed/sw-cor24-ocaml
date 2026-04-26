(* leading file comment *)
let x = 40 (* inline comment *) + 2
(* nested comment
   (* inner comment *)
   still comment
*)
let y = "not (* a comment *)"
x
String.length y
let z = match Some 3 with
  (* comment before first arm *)
  | None -> 0
  (* comment between arms *)
  | Some n -> n + x
z
