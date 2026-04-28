let _ = let r = Parser_full.one (Lexer.TIdent [97; 98; 99]) in (match r with Parser_full.TIdent s -> print_endline s | _ -> print_endline "fail")
let _ = let r = Parser_full.one (Lexer.TInt 7) in (match r with Parser_full.TInt n -> print_int n | _ -> print_endline "fail")
let _ = let r = Parser_full.one Lexer.TEOF in (match r with Parser_full.TEOF -> print_endline " eof" | _ -> print_endline "fail")
