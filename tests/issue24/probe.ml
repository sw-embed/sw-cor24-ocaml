let one = match Lexer.TLArrow with Lexer.TLArrow -> Parser.TLArrow | _ -> Parser.TEOF
let _ = print_endline (Parser.token_name one)
let two = match Lexer.TIdent [102;111;111] with Lexer.TIdent bs -> Parser.TIdent "x" | _ -> Parser.TEOF
let _ = print_endline (Parser.token_name two)
