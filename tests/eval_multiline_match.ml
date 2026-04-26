type tok = TIdent of string | TInt of int | TPct of int | TLArrow
let dump_tok t = match t with
  | TIdent s -> print_endline ("IDENT " ^ s)
  | TInt n -> print_endline ("INT " ^ string_of_int n)
  | TPct p -> print_endline ("PCT " ^ string_of_int p)
  | TLArrow -> print_endline "LARROW"
dump_tok (TIdent "name")
dump_tok (TInt 42)
dump_tok TLArrow
match TPct 37 with
  | TIdent _ -> 0
  | TInt _ -> 1
  | TPct p -> p
  | TLArrow -> 2
