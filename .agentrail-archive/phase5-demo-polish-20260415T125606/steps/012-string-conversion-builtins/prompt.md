Add string_of_int and int_of_string built-ins. Depends on the string-values step (003).

- string_of_int : int -> string
  Convert int to decimal string representation. Handle negative numbers.
  Allocate into string_pool.

- int_of_string : string -> int
  Parse decimal digits. Return 0 on parse failure (or set eval_error).

Tests:
  > string_of_int 42                   "42"
  > string_of_int (-99)                "-99"
  > string_of_int 0                    "0"
  > int_of_string "123"                123
  > "value is " ^ string_of_int 42    "value is 42"
  > print_endline (string_of_int (1 + 2))   3  (printed)