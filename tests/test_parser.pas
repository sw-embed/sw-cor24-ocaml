program TestParser;
{ Test harness: lex + parse OCaml source, print AST as S-expression.
  All modules inlined since p24p has no user-unit imports.

  Names are stored in a global name pool. AST nodes reference names
  by (offset, length) into the pool, since p24p records cannot
  contain arrays. }

{ ============================================================
  Constants
  ============================================================ }

const
  TK_EOF    = 0;  TK_INT    = 1;  TK_IDENT  = 2;
  TK_LET    = 10; TK_REC    = 11; TK_IN     = 12;
  TK_IF     = 13; TK_THEN   = 14; TK_ELSE   = 15;
  TK_FUN    = 16; TK_TRUE   = 17; TK_FALSE  = 18;
  TK_NOT    = 19; TK_MOD    = 20;
  TK_PLUS   = 30; TK_MINUS  = 31; TK_STAR   = 32;
  TK_SLASH  = 33; TK_EQ     = 34; TK_NEQ    = 35;
  TK_LT     = 36; TK_GT     = 37; TK_LE     = 38;
  TK_GE     = 39; TK_ANDAND = 40; TK_OROR   = 41;
  TK_ARROW  = 42;
  TK_LPAREN = 50; TK_RPAREN = 51; TK_SEMI   = 52;
  TK_ERROR  = 99;
  SRC_MAX   = 4095; ID_MAX = 63;

  EK_INT = 1; EK_BOOL = 2; EK_VAR = 3; EK_BINOP = 4;
  EK_UNARY = 5; EK_IF = 6; EK_LET = 7; EK_FUN = 8; EK_APP = 9;

  OP_ADD = 30; OP_SUB = 31; OP_MUL = 32; OP_DIV = 33; OP_MOD = 20;
  OP_EQ = 34; OP_NEQ = 35; OP_LT = 36; OP_GT = 37;
  OP_LE = 38; OP_GE = 39; OP_AND = 40; OP_OR = 41; OP_NOT = 19;

  NAME_POOL_MAX = 2048;

{ ============================================================
  AST type -- no arrays in records, names via pool indices
  ============================================================ }

type
  PExpr = ^Expr;
  Expr = record
    kind: integer;
    ival: integer;
    op: integer;
    noff: integer;
    nlen: integer;
    left: PExpr;
    right: PExpr;
    extra: PExpr
  end;

{ ============================================================
  Lexer variables (declared first so name pool can reference them)
  ============================================================ }

var
  tok: integer;
  tok_int: integer;
  tok_id: array[0..63] of char;
  tok_id_len: integer;
  src: array[0..4095] of char;
  src_len: integer;
  pos: integer;
  ch: char;

{ ============================================================
  Global name pool
  ============================================================ }

var
  name_pool: array[0..2047] of char;
  name_pool_len: integer;

function pool_intern: integer;
var start, j: integer;
begin
  start := name_pool_len;
  j := 0;
  while j < tok_id_len do
  begin
    if name_pool_len < NAME_POOL_MAX then
    begin
      name_pool[name_pool_len] := tok_id[j];
      name_pool_len := name_pool_len + 1
    end;
    j := j + 1
  end;
  pool_intern := start
end;

procedure print_pool_name(off, len: integer);
var j: integer;
begin
  j := 0;
  while j < len do begin write(name_pool[off + j]); j := j + 1 end
end;

{ ============================================================
  Lexer implementation
  ============================================================ }

function is_digit(c: char): boolean;
begin is_digit := (c >= '0') and (c <= '9') end;

function is_alpha(c: char): boolean;
begin is_alpha := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or (c = '_') end;

function is_alnum(c: char): boolean;
begin is_alnum := is_digit(c) or is_alpha(c) or (c = chr(39)) end;

function is_space(c: char): boolean;
begin is_space := (c = ' ') or (c = chr(9)) or (c = chr(10)) or (c = chr(13)) end;

procedure skip_whitespace;
begin while (pos < src_len) and is_space(src[pos]) do pos := pos + 1 end;

function skip_comment: boolean;
var depth: integer;
begin
  skip_comment := false;
  if (pos + 1 < src_len) and (src[pos] = '(') and (src[pos + 1] = '*') then
  begin
    pos := pos + 2; depth := 1;
    while (pos + 1 < src_len) and (depth > 0) do
    begin
      if (src[pos] = '(') and (src[pos + 1] = '*') then begin depth := depth + 1; pos := pos + 2 end
      else if (src[pos] = '*') and (src[pos + 1] = ')') then begin depth := depth - 1; pos := pos + 2 end
      else pos := pos + 1
    end;
    skip_comment := true
  end
end;

procedure skip_ws_and_comments;
var moved: boolean;
begin
  repeat moved := false; skip_whitespace; if skip_comment then moved := true until not moved
end;

function classify_ident: integer;
begin
  classify_ident := TK_IDENT;
  if tok_id_len = 2 then begin
    if (tok_id[0] = 'i') and (tok_id[1] = 'f') then classify_ident := TK_IF
    else if (tok_id[0] = 'i') and (tok_id[1] = 'n') then classify_ident := TK_IN
  end else if tok_id_len = 3 then begin
    if (tok_id[0] = 'l') and (tok_id[1] = 'e') and (tok_id[2] = 't') then classify_ident := TK_LET
    else if (tok_id[0] = 'r') and (tok_id[1] = 'e') and (tok_id[2] = 'c') then classify_ident := TK_REC
    else if (tok_id[0] = 'f') and (tok_id[1] = 'u') and (tok_id[2] = 'n') then classify_ident := TK_FUN
    else if (tok_id[0] = 'n') and (tok_id[1] = 'o') and (tok_id[2] = 't') then classify_ident := TK_NOT
    else if (tok_id[0] = 'm') and (tok_id[1] = 'o') and (tok_id[2] = 'd') then classify_ident := TK_MOD
  end else if tok_id_len = 4 then begin
    if (tok_id[0] = 't') and (tok_id[1] = 'h') and (tok_id[2] = 'e') and (tok_id[3] = 'n') then classify_ident := TK_THEN
    else if (tok_id[0] = 'e') and (tok_id[1] = 'l') and (tok_id[2] = 's') and (tok_id[3] = 'e') then classify_ident := TK_ELSE
    else if (tok_id[0] = 't') and (tok_id[1] = 'r') and (tok_id[2] = 'u') and (tok_id[3] = 'e') then classify_ident := TK_TRUE
  end else if tok_id_len = 5 then begin
    if (tok_id[0] = 'f') and (tok_id[1] = 'a') and (tok_id[2] = 'l') and (tok_id[3] = 's') and (tok_id[4] = 'e') then classify_ident := TK_FALSE
  end
end;

procedure lex_init;
begin
  src_len := 0; pos := 0; tok := TK_EOF; tok_int := 0; tok_id_len := 0;
  while not eof do begin
    read(ch);
    if ch <> chr(4) then if src_len < SRC_MAX then begin src[src_len] := ch; src_len := src_len + 1 end
  end
end;

procedure lex_next;
var c: char;
begin
  skip_ws_and_comments;
  if pos >= src_len then begin tok := TK_EOF; exit end;
  c := src[pos];
  if is_digit(c) then begin
    tok := TK_INT; tok_int := 0;
    while (pos < src_len) and is_digit(src[pos]) do begin tok_int := tok_int * 10 + (ord(src[pos]) - ord('0')); pos := pos + 1 end; exit
  end;
  if is_alpha(c) then begin
    tok_id_len := 0;
    while (pos < src_len) and is_alnum(src[pos]) do begin
      if tok_id_len < ID_MAX then begin tok_id[tok_id_len] := src[pos]; tok_id_len := tok_id_len + 1 end; pos := pos + 1
    end; tok := classify_ident; exit
  end;
  if c = '+' then begin tok := TK_PLUS; pos := pos + 1; exit end;
  if c = '*' then begin tok := TK_STAR; pos := pos + 1; exit end;
  if c = '/' then begin tok := TK_SLASH; pos := pos + 1; exit end;
  if c = '(' then begin tok := TK_LPAREN; pos := pos + 1; exit end;
  if c = ')' then begin tok := TK_RPAREN; pos := pos + 1; exit end;
  if c = ';' then begin tok := TK_SEMI; pos := pos + 1; exit end;
  if c = '=' then begin tok := TK_EQ; pos := pos + 1; exit end;
  if c = '-' then begin pos := pos + 1;
    if (pos < src_len) and (src[pos] = '>') then begin tok := TK_ARROW; pos := pos + 1 end else tok := TK_MINUS; exit end;
  if c = '<' then begin pos := pos + 1;
    if (pos < src_len) and (src[pos] = '>') then begin tok := TK_NEQ; pos := pos + 1 end
    else if (pos < src_len) and (src[pos] = '=') then begin tok := TK_LE; pos := pos + 1 end
    else tok := TK_LT; exit end;
  if c = '>' then begin pos := pos + 1;
    if (pos < src_len) and (src[pos] = '=') then begin tok := TK_GE; pos := pos + 1 end else tok := TK_GT; exit end;
  if c = '&' then begin pos := pos + 1;
    if (pos < src_len) and (src[pos] = '&') then begin tok := TK_ANDAND; pos := pos + 1 end else tok := TK_ERROR; exit end;
  if c = '|' then begin pos := pos + 1;
    if (pos < src_len) and (src[pos] = '|') then begin tok := TK_OROR; pos := pos + 1 end else tok := TK_ERROR; exit end;
  tok := TK_ERROR; pos := pos + 1
end;

{ ============================================================
  AST constructors
  ============================================================ }

function mk_int(v: integer): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_INT; n^.ival := v; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; mk_int := n end;

function mk_bool(v: integer): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_BOOL; n^.ival := v; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; mk_bool := n end;

function mk_var_node: PExpr;
var n: PExpr; off: integer;
begin off := pool_intern; new(n); n^.kind := EK_VAR; n^.ival := 0; n^.op := 0;
  n^.noff := off; n^.nlen := tok_id_len; n^.left := nil; n^.right := nil; n^.extra := nil;
  mk_var_node := n end;

function mk_binop(o: integer; l, r: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_BINOP; n^.ival := 0; n^.op := o; n^.noff := 0; n^.nlen := 0;
  n^.left := l; n^.right := r; n^.extra := nil; mk_binop := n end;

function mk_unary(o: integer; operand: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_UNARY; n^.ival := 0; n^.op := o; n^.noff := 0; n^.nlen := 0;
  n^.left := operand; n^.right := nil; n^.extra := nil; mk_unary := n end;

function mk_if(cond, then_br, else_br: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_IF; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := cond; n^.right := then_br; n^.extra := else_br; mk_if := n end;

function mk_let_node(val_e, body_e: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_LET; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := val_e; n^.right := body_e; n^.extra := nil; mk_let_node := n end;

function mk_fun_node(body_e: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_FUN; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := body_e; n^.right := nil; n^.extra := nil; mk_fun_node := n end;

function mk_app(fn, arg: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_APP; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := fn; n^.right := arg; n^.extra := nil; mk_app := n end;

{ ============================================================
  Parser
  ============================================================ }

var
  parse_error: boolean;
  save_noff: integer;
  save_nlen: integer;

procedure save_ident;
begin save_noff := pool_intern; save_nlen := tok_id_len end;

procedure restore_name_to(n: PExpr);
begin n^.noff := save_noff; n^.nlen := save_nlen end;

function parse_expr: PExpr; forward;

function is_atom_start: boolean;
begin is_atom_start := (tok = TK_INT) or (tok = TK_TRUE) or (tok = TK_FALSE) or (tok = TK_IDENT) or (tok = TK_LPAREN) end;

function parse_atom: PExpr;
var e: PExpr;
begin
  parse_atom := nil;
  if tok = TK_INT then begin parse_atom := mk_int(tok_int); lex_next; exit end;
  if tok = TK_TRUE then begin parse_atom := mk_bool(1); lex_next; exit end;
  if tok = TK_FALSE then begin parse_atom := mk_bool(0); lex_next; exit end;
  if tok = TK_IDENT then begin parse_atom := mk_var_node; lex_next; exit end;
  if tok = TK_LPAREN then begin
    lex_next;
    if tok = TK_RPAREN then begin parse_atom := mk_int(0); lex_next; exit end;
    e := parse_expr;
    if tok = TK_RPAREN then lex_next else parse_error := true;
    parse_atom := e; exit
  end;
  parse_error := true
end;

function parse_app: PExpr;
var fn, arg: PExpr;
begin fn := parse_atom;
  while is_atom_start and not parse_error do begin arg := parse_atom; fn := mk_app(fn, arg) end;
  parse_app := fn end;

function parse_unary: PExpr;
var e: PExpr;
begin
  if tok = TK_NOT then begin lex_next; e := parse_unary; parse_unary := mk_unary(OP_NOT, e); exit end;
  if tok = TK_MINUS then begin lex_next; e := parse_unary; parse_unary := mk_binop(OP_SUB, mk_int(0), e); exit end;
  parse_unary := parse_app
end;

function parse_term: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_unary;
  while ((tok = TK_STAR) or (tok = TK_SLASH) or (tok = TK_MOD)) and not parse_error do begin
    if tok = TK_STAR then o := OP_MUL else if tok = TK_SLASH then o := OP_DIV else o := OP_MOD;
    lex_next; r := parse_unary; e := mk_binop(o, e, r) end;
  parse_term := e end;

function parse_arith: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_term;
  while ((tok = TK_PLUS) or (tok = TK_MINUS)) and not parse_error do begin
    if tok = TK_PLUS then o := OP_ADD else o := OP_SUB;
    lex_next; r := parse_term; e := mk_binop(o, e, r) end;
  parse_arith := e end;

function parse_compare: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_arith;
  while ((tok = TK_EQ) or (tok = TK_NEQ) or (tok = TK_LT) or (tok = TK_GT) or (tok = TK_LE) or (tok = TK_GE))
    and not parse_error do begin o := tok; lex_next; r := parse_arith; e := mk_binop(o, e, r) end;
  parse_compare := e end;

function parse_logic: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_compare;
  while ((tok = TK_ANDAND) or (tok = TK_OROR)) and not parse_error do
  begin o := tok; lex_next; r := parse_compare; e := mk_binop(o, e, r) end;
  parse_logic := e end;

function parse_expr: PExpr;
var e, val_e, body_e: PExpr; is_rec: boolean;
begin
  parse_expr := nil;
  if tok = TK_LET then begin
    lex_next; is_rec := false;
    if tok = TK_REC then begin is_rec := true; lex_next end;
    if (tok = TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then begin save_ident; lex_next end
    else begin parse_error := true; exit end;
    if tok = TK_EQ then lex_next else begin parse_error := true; exit end;
    val_e := parse_expr;
    if tok = TK_IN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    e := mk_let_node(val_e, body_e); restore_name_to(e);
    if is_rec then e^.ival := 1;
    parse_expr := e; exit
  end;
  if tok = TK_IF then begin
    lex_next; val_e := parse_expr;
    if tok = TK_THEN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    if tok = TK_ELSE then lex_next else begin parse_error := true; exit end;
    e := parse_expr;
    parse_expr := mk_if(val_e, body_e, e); exit
  end;
  if tok = TK_FUN then begin
    lex_next;
    if tok = TK_IDENT then begin save_ident; lex_next end else begin parse_error := true; exit end;
    if tok = TK_ARROW then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    e := mk_fun_node(body_e); restore_name_to(e);
    parse_expr := e; exit
  end;
  parse_expr := parse_logic
end;

{ ============================================================
  AST printer (S-expression)
  ============================================================ }

procedure print_ast(n: PExpr); forward;

procedure print_ast(n: PExpr);
var l, r, x: PExpr;
begin
  if n = nil then begin write('nil'); exit end;
  if n^.kind = EK_INT then begin write(n^.ival); exit end;
  if n^.kind = EK_BOOL then begin if n^.ival = 1 then write('true') else write('false'); exit end;
  if n^.kind = EK_VAR then begin print_pool_name(n^.noff, n^.nlen); exit end;
  if n^.kind = EK_BINOP then begin
    write('('); if n^.op = OP_ADD then write('+') else if n^.op = OP_SUB then write('-')
    else if n^.op = OP_MUL then write('*') else if n^.op = OP_DIV then write('/')
    else if n^.op = OP_MOD then write('%') else if n^.op = OP_EQ then write('=')
    else if n^.op = OP_NEQ then write('!') else if n^.op = OP_LT then write('<')
    else if n^.op = OP_GT then write('>') else if n^.op = OP_LE then write('L')
    else if n^.op = OP_GE then write('G') else if n^.op = OP_AND then write('&')
    else if n^.op = OP_OR then write('|');
    write(' '); l := n^.left; print_ast(l);
    write(' '); r := n^.right; print_ast(r);
    write(')'); exit end;
  if n^.kind = EK_UNARY then begin
    write('(~ '); l := n^.left; print_ast(l); write(')'); exit end;
  if n^.kind = EK_IF then begin
    write('(if '); l := n^.left; print_ast(l);
    write(' '); r := n^.right; print_ast(r);
    write(' '); x := n^.extra; print_ast(x);
    write(')'); exit end;
  if n^.kind = EK_LET then begin
    if n^.ival = 1 then write('(letrec ') else write('(let ');
    print_pool_name(n^.noff, n^.nlen); write(' ');
    l := n^.left; print_ast(l); write(' ');
    r := n^.right; print_ast(r); write(')'); exit end;
  if n^.kind = EK_FUN then begin
    write('(fn '); print_pool_name(n^.noff, n^.nlen); write(' ');
    l := n^.left; print_ast(l); write(')'); exit end;
  if n^.kind = EK_APP then begin
    write('(@ '); l := n^.left; print_ast(l);
    write(' '); r := n^.right; print_ast(r);
    write(')'); exit end;
  write('?')
end;

{ ============================================================
  Main
  ============================================================ }

var ast: PExpr;

begin
  name_pool_len := 0;
  lex_init;
  parse_error := false;
  lex_next;
  ast := parse_expr;
  if parse_error then
    writeln('PARSE ERROR')
  else begin
    print_ast(ast);
    writeln
  end
end.
