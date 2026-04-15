Add string_of_int and int_of_string builtins.

Semantics:
- string_of_int : int -> string   — e.g. string_of_int 42 returns "42"
- int_of_string : string -> int   — e.g. int_of_string "42" returns 42; failure should raise eval_error

Implementation:
- Intern both names following the pool_put helper pattern introduced in step 001 (see intern_list_hof).
- EK_VAR: return nil-body builtin-marker closures.
- EK_APP dispatch: on string_of_int, allocate into string_pool writing digits of av^.ival; handle negative numbers with a leading '-'; return mk_val_string(off, len).
- On int_of_string: walk av's bytes in string_pool; accumulate; handle optional leading '-'; reject non-digit chars with eval_error.

Test: tests/eval_string_conversion.ml with cases:
  string_of_int 42                        => "42"
  string_of_int 0                         => "0"
  string_of_int (-7)                      => "-7"
  int_of_string "100"                     => 100
  int_of_string "-42"                     => -42
  print_endline (string_of_int (List.length [1;2;3]))  => prints "3"  (the canonical chained demo)
  string_of_int (List.fold_left (fun a x -> a + x) 0 [1;2;3;4;5])  => "15"

Register with reg-rs. Check wc -c src/ocaml.pas stays well under 131,072.