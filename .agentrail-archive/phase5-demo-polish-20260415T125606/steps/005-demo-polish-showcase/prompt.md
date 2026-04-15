Create the final showcase demo combining all features from the saga.

Create tests/demo_polish.ml:
  (* function keyword *)
  let classify = function 0 -> 100 | 1 -> 101 | _ -> 999 in classify 1

  (* let-destructuring *)
  let (a, b) = (10, 20) in a * b

  (* Strings *)
  print_endline "Hello from COR24 OCaml!"
  String.length "OCaml"
  "Hello, " ^ "World!"

  (* Named ADTs *)
  type traffic = Red | Yellow | Green
  let action = function Red -> 0 | Yellow -> 1 | Green -> 2 in action Yellow

  (* All combined *)
  let rec map = function [] -> [] | h :: t -> h * 2 :: map t in map [1; 2; 3]

Add reg-rs baseline.
Add justfile 'demo-polish' target.
Update README with all remaining canonical demos working.

This is the final step of phase5-demo-polish.