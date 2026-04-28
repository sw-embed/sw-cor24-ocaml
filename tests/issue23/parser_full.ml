type token = TIdent of string | TInt of int | TEOF
let one t = match t with Lexer.TIdent bs -> Parser_full.TIdent "x" | Lexer.TInt n -> Parser_full.TInt n | _ -> Parser_full.TEOF
