Wire everything together into a standalone OCaml interpreter.

Create src/ocaml.pas -- the main interpreter program that:
1. Reads OCaml source from stdin (UART input)
2. Lexes, parses, and evaluates it
3. Prints the result (or side-effect output from print_int)
4. Reports errors clearly

This is test_eval.pas promoted to the real interpreter.
Create a build script that compiles it through the full pipeline.
Run the target demo: let x = 41 + 1 in print_int x -> outputs 42.
Also run factorial: let rec fact = fun n -> ... in print_int (fact 5) -> 120.
Update justfile with an 'ocaml' target.
This is the final step of the initial-spike saga. Use --done flag.