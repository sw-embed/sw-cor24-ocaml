program OCaml;
uses Hardware, units;
{ OCaml subset interpreter for COR24.
  Reads source from stdin, lexes, parses, and evaluates.
  Prints result or side-effect output from print_int.
  Board I/O: set_led, led_on, led_off, switch. }

const
  TK_EOF=0; TK_INT=1; TK_IDENT=2;
  TK_LET=10; TK_REC=11; TK_IN=12; TK_IF=13; TK_THEN=14; TK_ELSE=15;
  TK_FUN=16; TK_TRUE=17; TK_FALSE=18; TK_NOT=19; TK_MOD=20;
  TK_PLUS=30; TK_MINUS=31; TK_STAR=32; TK_SLASH=33;
  TK_EQ=34; TK_NEQ=35; TK_LT=36; TK_GT=37; TK_LE=38; TK_GE=39;
  TK_ANDAND=40; TK_OROR=41; TK_ARROW=42;
  TK_LPAREN=50; TK_RPAREN=51; TK_SEMI=52;
  TK_LBRACKET=53; TK_RBRACKET=54; TK_COLONCOLON=55;
  TK_ERROR=99;
  SRC_MAX=4095; ID_MAX=63;
  EK_INT=1; EK_BOOL=2; EK_VAR=3; EK_BINOP=4; EK_UNARY=5;
  EK_IF=6; EK_LET=7; EK_FUN=8; EK_APP=9;
  EK_NIL=10;
  OP_ADD=30; OP_SUB=31; OP_MUL=32; OP_DIV=33; OP_MOD=20;
  OP_EQ=34; OP_NEQ=35; OP_LT=36; OP_GT=37;
  OP_LE=38; OP_GE=39; OP_AND=40; OP_OR=41; OP_NOT=19;
  OP_CONS=55;
  NAME_POOL_MAX=2048;
  VK_INT=1; VK_BOOL=2; VK_CLOSURE=3; VK_UNIT=4;
  VK_NIL=5; VK_CONS=6;

type
  PExpr = ^Expr;
  Expr = record
    kind: integer; ival: integer; op: integer;
    noff: integer; nlen: integer;
    left: PExpr; right: PExpr; extra: PExpr
  end;
  PEnv = ^EnvEntry;
  PVal = ^Val;
  Val = record
    vk: integer; ival: integer;
    noff: integer; nlen: integer;
    body: PExpr; cenv: PEnv;
    head: PVal; tail: PVal
  end;
  EnvEntry = record
    noff: integer; nlen: integer;
    val: PVal; next: PEnv
  end;

var
  tok: integer; tok_int: integer;
  tok_id: array[0..63] of char; tok_id_len: integer;
  src: array[0..4095] of char; src_len: integer;
  pos: integer; ch: char;
  name_pool: array[0..2047] of char; name_pool_len: integer;
  parse_error: boolean; eval_error: boolean;
  print_int_noff: integer; print_int_nlen: integer;
  set_led_noff: integer; set_led_nlen: integer;
  led_on_noff: integer; led_on_nlen: integer;
  led_off_noff: integer; led_off_nlen: integer;
  switch_noff: integer; switch_nlen: integer;
  putc_noff: integer; putc_nlen: integer;
  putc_ch: char;
  wildcard_noff: integer; wildcard_nlen: integer;
  nil_noff: integer; nil_nlen: integer;
  hd_noff: integer; hd_nlen: integer;
  tl_noff: integer; tl_nlen: integer;
  isempty_noff: integer; isempty_nlen: integer;
  ast: PExpr; result: PVal;

function pool_intern: integer;
var start, j: integer;
begin start := name_pool_len; j := 0;
  while j < tok_id_len do begin
    if name_pool_len < NAME_POOL_MAX then begin name_pool[name_pool_len] := tok_id[j]; name_pool_len := name_pool_len + 1 end;
    j := j + 1 end;
  pool_intern := start end;

{ === Lexer === }
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
begin skip_comment := false;
  if (pos+1 < src_len) and (src[pos] = '(') and (src[pos+1] = '*') then begin
    pos := pos+2; depth := 1;
    while (pos+1 < src_len) and (depth > 0) do begin
      if (src[pos] = '(') and (src[pos+1] = '*') then begin depth := depth+1; pos := pos+2 end
      else if (src[pos] = '*') and (src[pos+1] = ')') then begin depth := depth-1; pos := pos+2 end
      else pos := pos+1 end;
    skip_comment := true end end;
procedure skip_ws_and_comments;
var moved: boolean;
begin repeat moved := false; skip_whitespace; if skip_comment then moved := true until not moved end;
function classify_ident: integer;
begin classify_ident := TK_IDENT;
  if tok_id_len = 2 then begin
    if (tok_id[0]='i') and (tok_id[1]='f') then classify_ident := TK_IF
    else if (tok_id[0]='i') and (tok_id[1]='n') then classify_ident := TK_IN
  end else if tok_id_len = 3 then begin
    if (tok_id[0]='l') and (tok_id[1]='e') and (tok_id[2]='t') then classify_ident := TK_LET
    else if (tok_id[0]='r') and (tok_id[1]='e') and (tok_id[2]='c') then classify_ident := TK_REC
    else if (tok_id[0]='f') and (tok_id[1]='u') and (tok_id[2]='n') then classify_ident := TK_FUN
    else if (tok_id[0]='n') and (tok_id[1]='o') and (tok_id[2]='t') then classify_ident := TK_NOT
    else if (tok_id[0]='m') and (tok_id[1]='o') and (tok_id[2]='d') then classify_ident := TK_MOD
  end else if tok_id_len = 4 then begin
    if (tok_id[0]='t') and (tok_id[1]='h') and (tok_id[2]='e') and (tok_id[3]='n') then classify_ident := TK_THEN
    else if (tok_id[0]='e') and (tok_id[1]='l') and (tok_id[2]='s') and (tok_id[3]='e') then classify_ident := TK_ELSE
    else if (tok_id[0]='t') and (tok_id[1]='r') and (tok_id[2]='u') and (tok_id[3]='e') then classify_ident := TK_TRUE
  end else if tok_id_len = 5 then begin
    if (tok_id[0]='f') and (tok_id[1]='a') and (tok_id[2]='l') and (tok_id[3]='s') and (tok_id[4]='e') then classify_ident := TK_FALSE
  end end;
procedure crlf;
begin write(chr(13)); write(chr(10)) end;

procedure lex_init;
{ Read one line from UART (until newline or EOT). Echoes each char
  for interactive terminal use. Resets lexer state.

  Handles backspace (chr(8) or chr(127)) by removing the last char
  and visually backing up the cursor. }
begin src_len := 0; pos := 0; tok := TK_EOF; tok_int := 0; tok_id_len := 0;
  while not eof do begin
    read(ch);
    if ch = chr(4) then exit;
    if (ch = chr(8)) or (ch = chr(127)) then begin
      if src_len > 0 then begin
        src_len := src_len - 1;
        write(chr(8)); write(' '); write(chr(8))
      end
    end
    else begin
      write(ch);  { echo the character }
      if (ch = chr(13)) or (ch = chr(10)) then begin crlf; exit end;
      if src_len < SRC_MAX then begin src[src_len] := ch; src_len := src_len + 1 end
    end
  end
end;
procedure lex_next;
var c: char;
begin skip_ws_and_comments;
  if pos >= src_len then begin tok := TK_EOF; exit end;
  c := src[pos];
  if is_digit(c) then begin tok := TK_INT; tok_int := 0;
    while (pos < src_len) and is_digit(src[pos]) do begin tok_int := tok_int*10 + (ord(src[pos])-ord('0')); pos := pos+1 end; exit end;
  if is_alpha(c) then begin tok_id_len := 0;
    while (pos < src_len) and is_alnum(src[pos]) do begin
      if tok_id_len < ID_MAX then begin tok_id[tok_id_len] := src[pos]; tok_id_len := tok_id_len+1 end; pos := pos+1 end;
    tok := classify_ident; exit end;
  if c = '+' then begin tok := TK_PLUS; pos := pos+1; exit end;
  if c = '*' then begin tok := TK_STAR; pos := pos+1; exit end;
  if c = '/' then begin tok := TK_SLASH; pos := pos+1; exit end;
  if c = '(' then begin tok := TK_LPAREN; pos := pos+1; exit end;
  if c = ')' then begin tok := TK_RPAREN; pos := pos+1; exit end;
  if c = ';' then begin tok := TK_SEMI; pos := pos+1; exit end;
  if c = '[' then begin tok := TK_LBRACKET; pos := pos+1; exit end;
  if c = ']' then begin tok := TK_RBRACKET; pos := pos+1; exit end;
  if c = ':' then begin
    pos := pos+1;
    if (pos < src_len) and (src[pos] = ':') then begin tok := TK_COLONCOLON; pos := pos+1 end
    else tok := TK_ERROR;
    exit
  end;
  if c = '=' then begin tok := TK_EQ; pos := pos+1; exit end;
  if c = '-' then begin pos := pos+1;
    if (pos < src_len) and (src[pos] = '>') then begin tok := TK_ARROW; pos := pos+1 end else tok := TK_MINUS; exit end;
  if c = '<' then begin pos := pos+1;
    if (pos < src_len) and (src[pos] = '>') then begin tok := TK_NEQ; pos := pos+1 end
    else if (pos < src_len) and (src[pos] = '=') then begin tok := TK_LE; pos := pos+1 end
    else tok := TK_LT; exit end;
  if c = '>' then begin pos := pos+1;
    if (pos < src_len) and (src[pos] = '=') then begin tok := TK_GE; pos := pos+1 end else tok := TK_GT; exit end;
  if c = '&' then begin pos := pos+1;
    if (pos < src_len) and (src[pos] = '&') then begin tok := TK_ANDAND; pos := pos+1 end else tok := TK_ERROR; exit end;
  if c = '|' then begin pos := pos+1;
    if (pos < src_len) and (src[pos] = '|') then begin tok := TK_OROR; pos := pos+1 end else tok := TK_ERROR; exit end;
  tok := TK_ERROR; pos := pos+1 end;

{ === AST constructors === }
function mk_int(v: integer): PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_INT; n^.ival := v; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; mk_int := n end;
function mk_nil_expr: PExpr;
var n: PExpr;
begin new(n); n^.kind := EK_NIL; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; mk_nil_expr := n end;
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

{ === Parser === }
function parse_expr: PExpr; forward;
function parse_seq: PExpr; forward;
function parse_list_elements: PExpr; forward;
function parse_fun_params: PExpr; forward;
function is_atom_start: boolean;
begin is_atom_start := (tok=TK_INT) or (tok=TK_TRUE) or (tok=TK_FALSE) or (tok=TK_IDENT) or (tok=TK_LPAREN) or (tok=TK_LBRACKET) end;
function parse_atom: PExpr;
var e: PExpr;
begin parse_atom := nil;
  if tok=TK_INT then begin parse_atom := mk_int(tok_int); lex_next; exit end;
  if tok=TK_TRUE then begin parse_atom := mk_bool(1); lex_next; exit end;
  if tok=TK_FALSE then begin parse_atom := mk_bool(0); lex_next; exit end;
  if tok=TK_IDENT then begin parse_atom := mk_var_node; lex_next; exit end;
  if tok=TK_LPAREN then begin lex_next;
    if tok=TK_RPAREN then begin parse_atom := mk_int(0); lex_next; exit end;
    e := parse_seq; if tok=TK_RPAREN then lex_next else parse_error := true;
    parse_atom := e; exit end;
  if tok=TK_LBRACKET then begin
    lex_next;
    if tok=TK_RBRACKET then begin parse_atom := mk_nil_expr; lex_next; exit end;
    { parse [e1; e2; ...; en] as cons(e1, cons(e2, ..., cons(en, nil))) }
    e := parse_list_elements;
    if tok=TK_RBRACKET then lex_next else parse_error := true;
    parse_atom := e;
    exit
  end;
  parse_error := true end;
function parse_app: PExpr;
var fn, arg: PExpr;
begin fn := parse_atom;
  while is_atom_start and not parse_error do begin arg := parse_atom; fn := mk_app(fn, arg) end;
  parse_app := fn end;
function parse_unary: PExpr;
var e: PExpr;
begin
  if tok=TK_NOT then begin lex_next; e := parse_unary; parse_unary := mk_unary(OP_NOT, e); exit end;
  if tok=TK_MINUS then begin lex_next; e := parse_unary; parse_unary := mk_binop(OP_SUB, mk_int(0), e); exit end;
  parse_unary := parse_app end;
function parse_term: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_unary;
  while ((tok=TK_STAR) or (tok=TK_SLASH) or (tok=TK_MOD)) and not parse_error do begin
    if tok=TK_STAR then o := OP_MUL else if tok=TK_SLASH then o := OP_DIV else o := OP_MOD;
    lex_next; r := parse_unary; e := mk_binop(o, e, r) end;
  parse_term := e end;
function parse_arith: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_term;
  while ((tok=TK_PLUS) or (tok=TK_MINUS)) and not parse_error do begin
    if tok=TK_PLUS then o := OP_ADD else o := OP_SUB;
    lex_next; r := parse_term; e := mk_binop(o, e, r) end;
  parse_arith := e end;
function parse_cons: PExpr; forward;
function parse_cons: PExpr;
{ Right-associative :: operator }
var e, r: PExpr;
begin
  e := parse_arith;
  if (tok = TK_COLONCOLON) and not parse_error then begin
    lex_next;
    r := parse_cons;
    parse_cons := mk_binop(OP_CONS, e, r)
  end else
    parse_cons := e
end;
function parse_compare: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_cons;
  while ((tok=TK_EQ) or (tok=TK_NEQ) or (tok=TK_LT) or (tok=TK_GT) or (tok=TK_LE) or (tok=TK_GE))
    and not parse_error do begin o := tok; lex_next; r := parse_cons; e := mk_binop(o, e, r) end;
  parse_compare := e end;
function parse_logic: PExpr;
var e, r: PExpr; o: integer;
begin e := parse_compare;
  while ((tok=TK_ANDAND) or (tok=TK_OROR)) and not parse_error do
  begin o := tok; lex_next; r := parse_compare; e := mk_binop(o, e, r) end;
  parse_logic := e end;
function parse_fun_params: PExpr;
{ Read one param, then either ARROW + body or more params.
  fun x y z -> body becomes fun x -> fun y -> fun z -> body }
var e, body_e: PExpr; my_noff, my_nlen: integer;
begin
  parse_fun_params := nil;
  if tok=TK_IDENT then begin
    my_noff := pool_intern; my_nlen := tok_id_len; lex_next
  end else begin parse_error := true; exit end;
  if tok=TK_ARROW then begin
    lex_next; body_e := parse_seq
  end else begin
    body_e := parse_fun_params
  end;
  if parse_error then exit;
  e := mk_fun_node(body_e);
  e^.noff := my_noff; e^.nlen := my_nlen;
  parse_fun_params := e
end;

function parse_expr: PExpr;
var e, val_e, body_e: PExpr; is_rec: boolean; my_noff, my_nlen: integer;
begin parse_expr := nil;
  if tok=TK_LET then begin lex_next; is_rec := false;
    if tok=TK_REC then begin is_rec := true; lex_next end;
    if (tok=TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then begin my_noff := pool_intern; my_nlen := tok_id_len; lex_next end
    else begin parse_error := true; exit end;
    if tok=TK_EQ then lex_next else begin parse_error := true; exit end;
    val_e := parse_expr;
    if tok=TK_IN then lex_next else begin parse_error := true; exit end;
    body_e := parse_seq; e := mk_let_node(val_e, body_e);
    e^.noff := my_noff; e^.nlen := my_nlen;
    if is_rec then e^.ival := 1; parse_expr := e; exit end;
  if tok=TK_IF then begin lex_next; val_e := parse_expr;
    if tok=TK_THEN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    if tok=TK_ELSE then lex_next else begin parse_error := true; exit end;
    e := parse_expr; parse_expr := mk_if(val_e, body_e, e); exit end;
  if tok=TK_FUN then begin lex_next;
    parse_expr := parse_fun_params; exit end;
  parse_expr := parse_logic end;

function parse_seq: PExpr;
var e, r, seq: PExpr;
begin
  e := parse_expr;
  while (tok = TK_SEMI) and not parse_error do
  begin
    lex_next;
    r := parse_expr;
    seq := mk_let_node(e, r);
    seq^.noff := wildcard_noff;
    seq^.nlen := wildcard_nlen;
    e := seq
  end;
  parse_seq := e
end;

function parse_list_elements: PExpr;
{ Parse e1 ; e2 ; ... ; en and build cons(e1, cons(e2, ..., cons(en, nil))) }
var e, rest: PExpr;
begin
  parse_list_elements := nil;
  e := parse_expr;
  if parse_error then exit;
  if tok = TK_SEMI then begin
    lex_next;
    rest := parse_list_elements;
    parse_list_elements := mk_binop(OP_CONS, e, rest)
  end else
    parse_list_elements := mk_binop(OP_CONS, e, mk_nil_expr)
end;

{ === Evaluator === }
function names_equal(o1, l1, o2, l2: integer): boolean;
var j: integer; eq: boolean;
begin names_equal := false; if l1 <> l2 then exit;
  eq := true; j := 0;
  while (j < l1) and eq do begin if name_pool[o1+j] <> name_pool[o2+j] then eq := false; j := j+1 end;
  names_equal := eq end;
function env_lookup(env: PEnv; noff, nlen: integer): PVal;
var cur: PEnv;
begin env_lookup := nil; cur := env;
  while cur <> nil do begin
    if names_equal(cur^.noff, cur^.nlen, noff, nlen) then begin env_lookup := cur^.val; exit end;
    cur := cur^.next end;
  eval_error := true end;
function env_extend(env: PEnv; noff, nlen: integer; v: PVal): PEnv;
var e: PEnv;
begin new(e); e^.noff := noff; e^.nlen := nlen; e^.val := v; e^.next := env; env_extend := e end;
function mk_val_int(v: integer): PVal;
var p: PVal;
begin new(p); p^.vk := VK_INT; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_int := p end;
function mk_val_bool(v: integer): PVal;
var p: PVal;
begin new(p); p^.vk := VK_BOOL; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_bool := p end;
function mk_val_closure(noff, nlen: integer; body: PExpr; env: PEnv): PVal;
var p: PVal;
begin new(p); p^.vk := VK_CLOSURE; p^.ival := 0; p^.noff := noff; p^.nlen := nlen; p^.body := body; p^.cenv := env; p^.head := nil; p^.tail := nil; mk_val_closure := p end;
function mk_val_nil: PVal;
var p: PVal;
begin new(p); p^.vk := VK_NIL; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_nil := p end;
function mk_val_cons(h, t: PVal): PVal;
var p: PVal;
begin new(p); p^.vk := VK_CONS; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := h; p^.tail := t; mk_val_cons := p end;
function mk_val_unit: PVal;
var p: PVal;
begin new(p); p^.vk := VK_UNIT; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_unit := p end;
procedure intern_print_int;
begin print_int_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  print_int_nlen := 9 end;
procedure intern_wildcard;
begin wildcard_noff := name_pool_len;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  wildcard_nlen := 1 end;
procedure intern_nil;
begin nil_noff := name_pool_len;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  nil_nlen := 3 end;
procedure intern_list_ops;
begin
  hd_noff := name_pool_len;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  hd_nlen := 2;
  tl_noff := name_pool_len;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  tl_nlen := 2;
  isempty_noff := name_pool_len;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'm'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'y'; name_pool_len := name_pool_len+1;
  isempty_nlen := 8
end;
procedure intern_board;
begin
  set_led_noff := name_pool_len;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  set_led_nlen := 7;
  led_on_noff := name_pool_len;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  led_on_nlen := 6;
  led_off_noff := name_pool_len;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'f'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'f'; name_pool_len := name_pool_len+1;
  led_off_nlen := 7;
  switch_noff := name_pool_len;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'w'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'c'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  switch_nlen := 6;
  putc_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'u'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'c'; name_pool_len := name_pool_len+1;
  putc_nlen := 4
end;
function eval_expr(e: PExpr; env: PEnv): PVal; forward;
function eval_expr(e: PExpr; env: PEnv): PVal;
var lv, rv, fv, av: PVal; l, r, x, bd: PExpr; ne, ce: PEnv; a, b, res: integer;
begin eval_expr := nil;
  if e = nil then begin eval_error := true; exit end;
  if e^.kind = EK_INT then begin eval_expr := mk_val_int(e^.ival); exit end;
  if e^.kind = EK_BOOL then begin eval_expr := mk_val_bool(e^.ival); exit end;
  if e^.kind = EK_NIL then begin eval_expr := mk_val_nil; exit end;
  if e^.kind = EK_VAR then begin
    if names_equal(e^.noff, e^.nlen, print_int_noff, print_int_nlen) then begin
      eval_expr := mk_val_closure(print_int_noff, print_int_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, set_led_noff, set_led_nlen) then begin
      eval_expr := mk_val_closure(set_led_noff, set_led_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, led_on_noff, led_on_nlen) then begin
      eval_expr := mk_val_closure(led_on_noff, led_on_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, led_off_noff, led_off_nlen) then begin
      eval_expr := mk_val_closure(led_off_noff, led_off_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, switch_noff, switch_nlen) then begin
      eval_expr := mk_val_closure(switch_noff, switch_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, putc_noff, putc_nlen) then begin
      eval_expr := mk_val_closure(putc_noff, putc_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, nil_noff, nil_nlen) then begin
      eval_expr := mk_val_nil; exit end;
    if names_equal(e^.noff, e^.nlen, hd_noff, hd_nlen) then begin
      eval_expr := mk_val_closure(hd_noff, hd_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, tl_noff, tl_nlen) then begin
      eval_expr := mk_val_closure(tl_noff, tl_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, isempty_noff, isempty_nlen) then begin
      eval_expr := mk_val_closure(isempty_noff, isempty_nlen, nil, nil); exit end;
    eval_expr := env_lookup(env, e^.noff, e^.nlen); exit end;
  if e^.kind = EK_BINOP then begin
    l := e^.left; r := e^.right;
    lv := eval_expr(l, env); rv := eval_expr(r, env);
    if eval_error then exit;
    if e^.op = OP_CONS then begin
      eval_expr := mk_val_cons(lv, rv); exit
    end;
    a := lv^.ival; b := rv^.ival; res := 0;
    if e^.op=OP_ADD then res := a+b
    else if e^.op=OP_SUB then res := a-b
    else if e^.op=OP_MUL then res := a*b
    else if e^.op=OP_DIV then begin if b=0 then begin eval_error := true; exit end; res := a div b end
    else if e^.op=OP_MOD then begin if b=0 then begin eval_error := true; exit end; res := a mod b end
    else if e^.op=OP_EQ then begin if a=b then res := 1 end
    else if e^.op=OP_NEQ then begin if a<>b then res := 1 end
    else if e^.op=OP_LT then begin if a<b then res := 1 end
    else if e^.op=OP_GT then begin if a>b then res := 1 end
    else if e^.op=OP_LE then begin if a<=b then res := 1 end
    else if e^.op=OP_GE then begin if a>=b then res := 1 end
    else if e^.op=OP_AND then begin if (a<>0) and (b<>0) then res := 1 end
    else if e^.op=OP_OR then begin if (a<>0) or (b<>0) then res := 1 end;
    if (e^.op >= OP_EQ) and (e^.op <= OP_OR) then eval_expr := mk_val_bool(res)
    else eval_expr := mk_val_int(res); exit end;
  if e^.kind = EK_UNARY then begin
    l := e^.left; lv := eval_expr(l, env); if eval_error then exit;
    if lv^.ival=0 then eval_expr := mk_val_bool(1) else eval_expr := mk_val_bool(0); exit end;
  if e^.kind = EK_IF then begin
    l := e^.left; lv := eval_expr(l, env); if eval_error then exit;
    if lv^.ival <> 0 then begin r := e^.right; eval_expr := eval_expr(r, env) end
    else begin x := e^.extra; eval_expr := eval_expr(x, env) end; exit end;
  if e^.kind = EK_LET then begin
    l := e^.left;
    if e^.ival = 1 then begin
      lv := mk_val_closure(0, 0, nil, nil);
      ne := env_extend(env, e^.noff, e^.nlen, lv);
      rv := eval_expr(l, ne); if eval_error then exit;
      lv^.vk := rv^.vk; lv^.ival := rv^.ival; lv^.noff := rv^.noff; lv^.nlen := rv^.nlen;
      lv^.body := rv^.body; lv^.cenv := ne
    end else begin
      lv := eval_expr(l, env); if eval_error then exit;
      ne := env_extend(env, e^.noff, e^.nlen, lv) end;
    r := e^.right; eval_expr := eval_expr(r, ne); exit end;
  if e^.kind = EK_FUN then begin
    eval_expr := mk_val_closure(e^.noff, e^.nlen, e^.left, env); exit end;
  if e^.kind = EK_APP then begin
    l := e^.left; fv := eval_expr(l, env); if eval_error then exit;
    r := e^.right; av := eval_expr(r, env); if eval_error then exit;
    if fv^.vk = VK_CLOSURE then begin
      if fv^.body = nil then begin
        if names_equal(fv^.noff, fv^.nlen, print_int_noff, print_int_nlen) then begin
          write(av^.ival); crlf; eval_expr := mk_val_unit; exit end;
        if names_equal(fv^.noff, fv^.nlen, set_led_noff, set_led_nlen) then begin
          if av^.ival <> 0 then LedOn else LedOff;
          eval_expr := mk_val_unit; exit end;
        if names_equal(fv^.noff, fv^.nlen, led_on_noff, led_on_nlen) then begin
          LedOn; eval_expr := mk_val_unit; exit end;
        if names_equal(fv^.noff, fv^.nlen, led_off_noff, led_off_nlen) then begin
          LedOff; eval_expr := mk_val_unit; exit end;
        if names_equal(fv^.noff, fv^.nlen, switch_noff, switch_nlen) then begin
          eval_expr := mk_val_bool(ReadSwitch); exit end;
        if names_equal(fv^.noff, fv^.nlen, putc_noff, putc_nlen) then begin
          if av^.ival = 10 then crlf
          else write(chr(av^.ival));
          eval_expr := mk_val_unit; exit end;
        if names_equal(fv^.noff, fv^.nlen, hd_noff, hd_nlen) then begin
          if av^.vk <> VK_CONS then begin eval_error := true; exit end;
          eval_expr := av^.head; exit end;
        if names_equal(fv^.noff, fv^.nlen, tl_noff, tl_nlen) then begin
          if av^.vk <> VK_CONS then begin eval_error := true; exit end;
          eval_expr := av^.tail; exit end;
        if names_equal(fv^.noff, fv^.nlen, isempty_noff, isempty_nlen) then begin
          if av^.vk = VK_NIL then eval_expr := mk_val_bool(1)
          else eval_expr := mk_val_bool(0);
          exit end;
        eval_error := true; exit end;
      bd := fv^.body; ce := fv^.cenv;
      ne := env_extend(ce, fv^.noff, fv^.nlen, av);
      eval_expr := eval_expr(bd, ne); exit end;
    eval_error := true; exit end;
  eval_error := true end;

{ === Value pretty-printer === }

procedure print_value(v: PVal); forward;

procedure print_value(v: PVal);
var cur: PVal;
begin
  if v = nil then begin write('<nil>'); exit end;
  if v^.vk = VK_INT then begin write(v^.ival); exit end;
  if v^.vk = VK_BOOL then begin
    if v^.ival = 1 then write('true') else write('false');
    exit
  end;
  if v^.vk = VK_UNIT then begin write('()'); exit end;
  if v^.vk = VK_NIL then begin write('[]'); exit end;
  if v^.vk = VK_CONS then begin
    write('[');
    print_value(v^.head);
    cur := v^.tail;
    while (cur <> nil) and (cur^.vk = VK_CONS) do begin
      write('; ');
      print_value(cur^.head);
      cur := cur^.tail
    end;
    write(']');
    exit
  end;
  if v^.vk = VK_CLOSURE then begin write('<fun>'); exit end;
  write('<?>')
end;

{ === Main: REPL loop === }
begin
  name_pool_len := 0;
  intern_print_int;
  intern_board;
  intern_wildcard;
  intern_nil;
  intern_list_ops;
  while not eof do begin
    { Print prompt: "> " }
    putc_ch := '>'; write(putc_ch);
    putc_ch := ' '; write(putc_ch);
    lex_init;
    if src_len > 0 then begin
      parse_error := false;
      eval_error := false;
      lex_next;
      ast := parse_seq;
      if parse_error then begin write('PARSE ERROR'); crlf end
      else begin
        result := eval_expr(ast, nil);
        if eval_error then begin write('EVAL ERROR'); crlf end
        else if result^.vk = VK_INT then begin write(result^.ival); crlf end
        else if result^.vk = VK_BOOL then begin
          if result^.ival = 1 then write('true') else write('false');
          crlf
        end
        else if result^.vk = VK_UNIT then crlf
        else begin print_value(result); crlf end
      end
    end
  end
end.
