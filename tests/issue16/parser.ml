let make _ = Ast.AProgram
let make_stmt n = Ast.AStmt n
let _ = Ast.dump_program (make 0)
let _ = match make_stmt 7 with Ast.AStmt n -> let _ = print_int n in print_endline " AStmt" | _ -> print_endline "other"
