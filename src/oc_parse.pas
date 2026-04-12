{ oc_parse.pas -- Recursive descent parser for OCaml subset

  Grammar (Phase 0):
    expr    ::= let_expr | if_expr | fun_expr | logic_expr
    let_expr ::= 'let' ['rec'] IDENT '=' expr 'in' expr
    if_expr  ::= 'if' expr 'then' expr 'else' expr
    fun_expr ::= 'fun' IDENT '->' expr
    logic    ::= compare (('&&' | '||') compare)*
    compare  ::= arith (('=' | '<>' | '<' | '>' | '<=' | '>=') arith)*
    arith    ::= term (('+' | '-') term)*
    term     ::= unary (('*' | '/' | 'mod') unary)*
    unary    ::= 'not' unary | app
    app      ::= atom+
    atom     ::= INT | 'true' | 'false' | '(' expr ')' | '(' ')' | IDENT

  Requires: oc_lex.pas (lexer), oc_ast.pas (AST types)
  Uses globals: tok, tok_int, tok_id, tok_id_len, lex_next, pool_intern
}

var
  parse_error: boolean;

function parse_expr: PExpr; forward;

function is_atom_start: boolean;
begin
  is_atom_start := (tok = TK_INT) or (tok = TK_TRUE)
                or (tok = TK_FALSE) or (tok = TK_IDENT)
                or (tok = TK_LPAREN)
end;

function parse_atom: PExpr;
var e: PExpr;
begin
  parse_atom := nil;
  if tok = TK_INT then begin parse_atom := mk_int(tok_int); lex_next; exit end;
  if tok = TK_TRUE then begin parse_atom := mk_bool(1); lex_next; exit end;
  if tok = TK_FALSE then begin parse_atom := mk_bool(0); lex_next; exit end;
  if tok = TK_IDENT then begin parse_atom := mk_var_node; lex_next; exit end;
  if tok = TK_LPAREN then
  begin
    lex_next;
    if tok = TK_RPAREN then begin parse_atom := mk_int(0); lex_next; exit end;
    e := parse_expr;
    if tok = TK_RPAREN then lex_next else parse_error := true;
    parse_atom := e;
    exit
  end;
  parse_error := true
end;

function parse_app: PExpr;
var fn, arg: PExpr;
begin
  fn := parse_atom;
  while is_atom_start and not parse_error do
  begin arg := parse_atom; fn := mk_app(fn, arg) end;
  parse_app := fn
end;

function parse_unary: PExpr;
var e: PExpr;
begin
  if tok = TK_NOT then begin lex_next; e := parse_unary; parse_unary := mk_unary(OP_NOT, e); exit end;
  if tok = TK_MINUS then begin lex_next; e := parse_unary; parse_unary := mk_binop(OP_SUB, mk_int(0), e); exit end;
  parse_unary := parse_app
end;

function parse_term: PExpr;
var e, r: PExpr; o: integer;
begin
  e := parse_unary;
  while ((tok = TK_STAR) or (tok = TK_SLASH) or (tok = TK_MOD)) and not parse_error do
  begin
    if tok = TK_STAR then o := OP_MUL
    else if tok = TK_SLASH then o := OP_DIV
    else o := OP_MOD;
    lex_next; r := parse_unary; e := mk_binop(o, e, r)
  end;
  parse_term := e
end;

function parse_arith: PExpr;
var e, r: PExpr; o: integer;
begin
  e := parse_term;
  while ((tok = TK_PLUS) or (tok = TK_MINUS)) and not parse_error do
  begin
    if tok = TK_PLUS then o := OP_ADD else o := OP_SUB;
    lex_next; r := parse_term; e := mk_binop(o, e, r)
  end;
  parse_arith := e
end;

function parse_compare: PExpr;
var e, r: PExpr; o: integer;
begin
  e := parse_arith;
  while ((tok = TK_EQ) or (tok = TK_NEQ) or (tok = TK_LT)
      or (tok = TK_GT) or (tok = TK_LE)  or (tok = TK_GE))
        and not parse_error do
  begin o := tok; lex_next; r := parse_arith; e := mk_binop(o, e, r) end;
  parse_compare := e
end;

function parse_logic: PExpr;
var e, r: PExpr; o: integer;
begin
  e := parse_compare;
  while ((tok = TK_ANDAND) or (tok = TK_OROR)) and not parse_error do
  begin o := tok; lex_next; r := parse_compare; e := mk_binop(o, e, r) end;
  parse_logic := e
end;

function parse_expr: PExpr;
var e, val_e, body_e: PExpr; is_rec: boolean;
    my_noff, my_nlen: integer;
begin
  parse_expr := nil;

  if tok = TK_LET then
  begin
    lex_next; is_rec := false;
    if tok = TK_REC then begin is_rec := true; lex_next end;
    if (tok = TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then
    begin my_noff := pool_intern; my_nlen := tok_id_len; lex_next end
    else begin parse_error := true; exit end;
    if tok = TK_EQ then lex_next else begin parse_error := true; exit end;
    val_e := parse_expr;
    if tok = TK_IN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    e := mk_let_node(val_e, body_e);
    e^.noff := my_noff; e^.nlen := my_nlen;
    if is_rec then e^.ival := 1;
    parse_expr := e; exit
  end;

  if tok = TK_IF then
  begin
    lex_next; val_e := parse_expr;
    if tok = TK_THEN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    if tok = TK_ELSE then lex_next else begin parse_error := true; exit end;
    e := parse_expr;
    parse_expr := mk_if(val_e, body_e, e); exit
  end;

  if tok = TK_FUN then
  begin
    lex_next;
    if tok = TK_IDENT then
    begin my_noff := pool_intern; my_nlen := tok_id_len; lex_next end
    else begin parse_error := true; exit end;
    if tok = TK_ARROW then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    e := mk_fun_node(body_e);
    e^.noff := my_noff; e^.nlen := my_nlen;
    parse_expr := e; exit
  end;

  parse_expr := parse_logic
end;
