Add string values (immutable char arrays) to the interpreter.

Values:
- VK_STRING=10 value kind.
- Reuse existing head/tail pointers? No; add a string_buf byte index/length.
  Simpler: use a global string_pool like name_pool. VK_STRING stores
  an offset + length into a shared string_pool.
  
  Global string_pool: array[0..4095] of char;
  Global string_pool_len: integer;
  
  Val record: repurpose noff/nlen for VK_STRING (offset/length in pool).

Lexer:
- Recognize '"..."' string literals. Support common escapes: \n (10), \t (9), \" (34), \\ (92).
- New TK_STRING token; tok_str_off/tok_str_len point into src (or into a fresh interning buffer).
  Simplest: intern string literals into string_pool during lex_next.
  tok_int will hold the offset, tok_id_len will hold the length... no,
  let's just use tok_int=offset and a new global tok_str_len=length.

Parser:
- parse_atom recognizes TK_STRING and creates EK_STRING (new kind)
  with noff/nlen into the pool.
- EK_STRING evaluates to mk_val_string(noff, nlen).

Built-ins:
- print_endline : string -> unit  (writes chars then CR+LF)
- String.length : string -> int
- ^ operator (OP_CONCAT): concat two strings into the pool

Pretty-printer:
- VK_STRING prints '"..."' (the literal content with escapes re-applied? Just raw for now.)

Tests:
  > "Hello"                            "Hello"
  > "OCaml" ^ " rocks"               "OCaml rocks"
  > print_endline "Hello, World!"      Hello, World!  (printed, unit result)
  > String.length "abcde"              5