Add List.map, List.filter, List.fold_left, List.init, List.iter as builtins.

All can now be written in OCaml using function-form let + match (once those land), but native implementations are faster. Provide both; the native ones satisfy existing demos.

Built-ins to add (pattern like List.length):
- List.map : (a -> b) -> a list -> b list
- List.filter : (a -> bool) -> a list -> a list
- List.fold_left : (b -> a -> b) -> b -> a list -> b
- List.init : int -> (int -> a) -> a list
- List.iter : (a -> unit) -> a list -> unit

These require callback invocation (calling an OCaml closure from Pascal).
Look at how EK_APP dispatches closures and factor out a
invoke_closure helper that applies a closure value to an argument.

Tests:
  > List.map (fun x -> x * 2) [1;2;3]                 [2; 4; 6]
  > List.filter (fun x -> x mod 2 = 0) [1;2;3;4]      [2; 4]
  > List.fold_left (fun a b -> a + b) 0 [1;2;3;4]     10
  > List.init 5 (fun i -> i * i)                      [0; 1; 4; 9; 16]
  > List.iter print_int [1;2;3]                       (prints 1 2 3)