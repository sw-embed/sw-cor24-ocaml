program OCaml;
uses Hardware;
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
  TK_DOT=56; TK_COMMA=57;
  TK_MATCH=21; TK_WITH=22; TK_FUNCTION=23; TK_PIPE=58;
  TK_STRING=59; TK_CARET=60; TK_BANG=61; TK_ASSIGN=62;
  TK_LBRACE=63; TK_RBRACE=64; TK_COLON=65;
  TK_TYPE=24; TK_WHEN=25; TK_AND=26;
  TK_ERROR=99;
  SRC_MAX=4095; ID_MAX=63;
  EK_INT=1; EK_BOOL=2; EK_VAR=3; EK_BINOP=4; EK_UNARY=5;
  EK_IF=6; EK_LET=7; EK_FUN=8; EK_APP=9;
  EK_NIL=10; EK_MATCH=11; EK_MATCH_ARM=12; EK_STRING=13;
  EK_TYPEDECL=14; EK_RECORD=15; EK_FIELD=16;
  PK_WILDCARD=0; PK_INT=1; PK_BOOL=2; PK_VAR=3;
  PK_NIL=4; PK_CONS=5; PK_PAIR=6; PK_NONE=7; PK_SOME=8;
  PK_CTOR=9; PK_STRING=10;
  OP_ADD=30; OP_SUB=31; OP_MUL=32; OP_DIV=33; OP_MOD=20;
  OP_EQ=34; OP_NEQ=35; OP_LT=36; OP_GT=37;
  OP_LE=38; OP_GE=39; OP_AND=40; OP_OR=41; OP_NOT=19;
  OP_CONS=55; OP_PAIR=56; OP_CONCAT=57; OP_DEREF=58; OP_ASSIGN=59;
  NAME_POOL_MAX=16384;
  CTOR_MAX=64;
  VK_INT=1; VK_BOOL=2; VK_CLOSURE=3; VK_UNIT=4;
  VK_NIL=5; VK_CONS=6; VK_PAIR=7;
  VK_NONE=8; VK_SOME=9; VK_STRING=10;
  VK_CTOR=11; VK_REF=12; VK_RECORD=13; VK_FIELD=14;

type
  PPat = ^Pat;
  PExpr = ^Expr;
  Expr = record
    kind: integer; ival: integer; op: integer;
    noff: integer; nlen: integer;
    left: PExpr; right: PExpr; extra: PExpr;
    pat: PPat;
    next_alloc: PExpr;
    mark_bit: integer
  end;
  Pat = record
    pk: integer;
    ival: integer;
    noff: integer; nlen: integer;
    sub1: PPat; sub2: PPat;
    next_alloc: PPat;
    mark_bit: integer
  end;
  PEnv = ^EnvEntry;
  PVal = ^Val;
  Val = record
    vk: integer; ival: integer;
    noff: integer; nlen: integer;
    body: PExpr; cenv: PEnv;
    head: PVal; tail: PVal;
    next_alloc: PVal;
    mark_bit: integer
  end;
  EnvEntry = record
    noff: integer; nlen: integer;
    val: PVal; next: PEnv;
    next_alloc: PEnv;
    mark_bit: integer
  end;

var
  tok: integer; tok_int: integer;
  tok_id: array[0..63] of char; tok_id_len: integer;
  src: array[0..4095] of char; src_len: integer;
  pos: integer; ch: char;
  name_pool: array[0..16383] of char; name_pool_len: integer;
  string_pool: array[0..16383] of char; string_pool_len: integer;
  tok_str_off: integer; tok_str_len: integer;
  parse_error: boolean; eval_error: boolean; exit_requested: boolean;
  top_let_allowed: boolean;
  match_success: boolean;
  print_int_noff: integer; print_int_nlen: integer;
  set_led_noff: integer; set_led_nlen: integer;
  led_on_noff: integer; led_on_nlen: integer;
  led_off_noff: integer; led_off_nlen: integer;
  switch_noff: integer; switch_nlen: integer;
  putc_noff: integer; putc_nlen: integer;
  putc_ch: char;
  getc_noff: integer; getc_nlen: integer;
  getc_ch: char;
  read_line_noff: integer; read_line_nlen: integer;
  ref_noff: integer; ref_nlen: integer;
  exit_noff: integer; exit_nlen: integer;
  read_line_ch: char;
  wildcard_noff: integer; wildcard_nlen: integer;
  nil_noff: integer; nil_nlen: integer;
  hd_noff: integer; hd_nlen: integer;
  tl_noff: integer; tl_nlen: integer;
  isempty_noff: integer; isempty_nlen: integer;
  list_length_noff: integer; list_length_nlen: integer;
  list_rev_noff: integer; list_rev_nlen: integer;
  list_hd_noff: integer; list_hd_nlen: integer;
  list_tl_noff: integer; list_tl_nlen: integer;
  list_isempty_noff: integer; list_isempty_nlen: integer;
  list_map_noff: integer; list_map_nlen: integer;
  list_filter_noff: integer; list_filter_nlen: integer;
  list_fold_noff: integer; list_fold_nlen: integer;
  list_iter_noff: integer; list_iter_nlen: integer;
  list_find_noff: integer; list_find_nlen: integer;
  string_of_int_noff: integer; string_of_int_nlen: integer;
  int_of_string_noff: integer; int_of_string_nlen: integer;
  soi_tmp: array[0..31] of char;
  fst_noff: integer; fst_nlen: integer;
  snd_noff: integer; snd_nlen: integer;
  none_noff: integer; none_nlen: integer;
  some_noff: integer; some_nlen: integer;
  ok_ctor_tag: integer; error_ctor_tag: integer;
  result_bind_noff: integer; result_bind_nlen: integer;
  fn_arg_noff: integer; fn_arg_nlen: integer;
  let_tmp_noff: integer; let_tmp_nlen: integer;
  print_endline_noff: integer; print_endline_nlen: integer;
  string_length_noff: integer; string_length_nlen: integer;
  string_make_noff: integer; string_make_nlen: integer;
  peek_noff: integer; peek_nlen: integer;
  poke_noff: integer; poke_nlen: integer;
  char_code_noff: integer; char_code_nlen: integer;
  char_chr_noff: integer; char_chr_nlen: integer;
  module_directive_noff: integer; module_directive_nlen: integer;
  current_module: array[0..63] of char; current_module_len: integer;
  ctor_names_off: array[0..63] of integer;
  ctor_names_len: array[0..63] of integer;
  ctor_arity: array[0..63] of integer;
  ctor_count: integer;
  ast: PExpr; result: PVal; top_env: PEnv;
  expr_alloc_head: PExpr; pat_alloc_head: PPat;
  val_alloc_head: PVal; env_alloc_head: PEnv;

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
    else if (tok_id[0]='a') and (tok_id[1]='n') and (tok_id[2]='d') then classify_ident := TK_AND
  end else if tok_id_len = 4 then begin
    if (tok_id[0]='t') and (tok_id[1]='h') and (tok_id[2]='e') and (tok_id[3]='n') then classify_ident := TK_THEN
    else if (tok_id[0]='e') and (tok_id[1]='l') and (tok_id[2]='s') and (tok_id[3]='e') then classify_ident := TK_ELSE
    else if (tok_id[0]='t') and (tok_id[1]='r') and (tok_id[2]='u') and (tok_id[3]='e') then classify_ident := TK_TRUE
    else if (tok_id[0]='t') and (tok_id[1]='y') and (tok_id[2]='p') and (tok_id[3]='e') then classify_ident := TK_TYPE
    else if (tok_id[0]='w') and (tok_id[1]='i') and (tok_id[2]='t') and (tok_id[3]='h') then classify_ident := TK_WITH
    else if (tok_id[0]='w') and (tok_id[1]='h') and (tok_id[2]='e') and (tok_id[3]='n') then classify_ident := TK_WHEN
  end else if tok_id_len = 5 then begin
    if (tok_id[0]='f') and (tok_id[1]='a') and (tok_id[2]='l') and (tok_id[3]='s') and (tok_id[4]='e') then classify_ident := TK_FALSE
    else if (tok_id[0]='m') and (tok_id[1]='a') and (tok_id[2]='t') and (tok_id[3]='c') and (tok_id[4]='h') then classify_ident := TK_MATCH
  end else if tok_id_len = 8 then begin
    if (tok_id[0]='f') and (tok_id[1]='u') and (tok_id[2]='n') and (tok_id[3]='c')
      and (tok_id[4]='t') and (tok_id[5]='i') and (tok_id[6]='o') and (tok_id[7]='n') then classify_ident := TK_FUNCTION
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
var c, d: char;
begin skip_ws_and_comments;
  if pos >= src_len then begin tok := TK_EOF; exit end;
  c := src[pos];
  if is_digit(c) then begin tok := TK_INT; tok_int := 0;
    { Hex literal: 0x... — accept after the leading 0. }
    if (c = '0') and (pos+1 < src_len) and (src[pos+1] = 'x') then begin
      pos := pos + 2;
      while pos < src_len do begin
        d := src[pos];
        if (d >= '0') and (d <= '9') then tok_int := tok_int*16 + (ord(d) - ord('0'))
        else if (d >= 'a') and (d <= 'f') then tok_int := tok_int*16 + (ord(d) - ord('a') + 10)
        else if (d >= 'A') and (d <= 'F') then tok_int := tok_int*16 + (ord(d) - ord('A') + 10)
        else exit;
        pos := pos + 1
      end;
      exit
    end;
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
  if c = '{' then begin tok := TK_LBRACE; pos := pos+1; exit end;
  if c = '}' then begin tok := TK_RBRACE; pos := pos+1; exit end;
  if c = '.' then begin tok := TK_DOT; pos := pos+1; exit end;
  if c = ',' then begin tok := TK_COMMA; pos := pos+1; exit end;
  if c = '^' then begin tok := TK_CARET; pos := pos+1; exit end;
  if c = chr(39) then begin
    pos := pos + 1;
    if pos >= src_len then begin tok := TK_ERROR; exit end;
    if src[pos] = '\' then begin
      pos := pos + 1;
      if pos >= src_len then begin tok := TK_ERROR; exit end;
      if src[pos] = 'n' then tok_int := 10
      else if src[pos] = 't' then tok_int := 9
      else if src[pos] = '\' then tok_int := ord('\')
      else if src[pos] = chr(39) then tok_int := ord(chr(39))
      else tok_int := ord(src[pos]);
      pos := pos + 1
    end else begin
      tok_int := ord(src[pos]);
      pos := pos + 1
    end;
    if (pos < src_len) and (src[pos] = chr(39)) then begin
      pos := pos + 1;
      tok := TK_INT;
      exit
    end else begin tok := TK_ERROR; exit end
  end;
  if c = '"' then begin
    { String literal. Read until closing quote, handling escapes. }
    pos := pos + 1;
    tok_str_off := string_pool_len;
    tok_str_len := 0;
    while (pos < src_len) and (src[pos] <> '"') do begin
      if src[pos] = '\' then begin
        pos := pos + 1;
        if pos >= src_len then begin tok := TK_ERROR; exit end;
        if src[pos] = 'n' then begin
          if string_pool_len < 32767 then begin string_pool[string_pool_len] := chr(10); string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end
        end else if src[pos] = 't' then begin
          if string_pool_len < 32767 then begin string_pool[string_pool_len] := chr(9); string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end
        end else if src[pos] = '"' then begin
          if string_pool_len < 32767 then begin string_pool[string_pool_len] := '"'; string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end
        end else if src[pos] = '\' then begin
          if string_pool_len < 32767 then begin string_pool[string_pool_len] := '\'; string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end
        end else begin
          { unknown escape: pass through the char as-is }
          if string_pool_len < 32767 then begin string_pool[string_pool_len] := src[pos]; string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end
        end;
        pos := pos + 1
      end else begin
        if string_pool_len < 32767 then begin string_pool[string_pool_len] := src[pos]; string_pool_len := string_pool_len+1; tok_str_len := tok_str_len+1 end;
        pos := pos + 1
      end
    end;
    if (pos < src_len) and (src[pos] = '"') then pos := pos + 1
    else begin tok := TK_ERROR; exit end;
    tok := TK_STRING;
    exit
  end;
  if c = ']' then begin tok := TK_RBRACKET; pos := pos+1; exit end;
  if c = ':' then begin
    pos := pos+1;
    if (pos < src_len) and (src[pos] = ':') then begin tok := TK_COLONCOLON; pos := pos+1 end
    else if (pos < src_len) and (src[pos] = '=') then begin tok := TK_ASSIGN; pos := pos+1 end
    else tok := TK_COLON;
    exit
  end;
  if c = '!' then begin tok := TK_BANG; pos := pos+1; exit end;
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
    if (pos < src_len) and (src[pos] = '|') then begin tok := TK_OROR; pos := pos+1 end else tok := TK_PIPE; exit end;
  tok := TK_ERROR; pos := pos+1 end;

{ === AST constructors === }
function mk_int(v: integer): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_INT; n^.ival := v; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_int := n end;
function mk_nil_expr: PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_NIL; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_nil_expr := n end;
function mk_string_expr(off, len: integer): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_STRING; n^.ival := 0; n^.op := 0; n^.noff := off; n^.nlen := len;
  n^.left := nil; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_string_expr := n end;
function mk_bool(v: integer): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_BOOL; n^.ival := v; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := nil; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_bool := n end;
function mk_var_node: PExpr;
var n: PExpr; off: integer;
begin off := pool_intern; new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_VAR; n^.ival := 0; n^.op := 0;
  n^.noff := off; n^.nlen := tok_id_len; n^.left := nil; n^.right := nil; n^.extra := nil;
  n^.pat := nil; mk_var_node := n end;
function mk_binop(o: integer; l, r: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_BINOP; n^.ival := 0; n^.op := o; n^.noff := 0; n^.nlen := 0;
  n^.left := l; n^.right := r; n^.extra := nil; n^.pat := nil; mk_binop := n end;
function mk_unary(o: integer; operand: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_UNARY; n^.ival := 0; n^.op := o; n^.noff := 0; n^.nlen := 0;
  n^.left := operand; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_unary := n end;
function mk_if(cond, then_br, else_br: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_IF; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := cond; n^.right := then_br; n^.extra := else_br; n^.pat := nil; mk_if := n end;
function mk_let_node(val_e, body_e: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_LET; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := val_e; n^.right := body_e; n^.extra := nil; n^.pat := nil; mk_let_node := n end;
function mk_fun_node(body_e: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_FUN; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := body_e; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_fun_node := n end;
function mk_app(fn, arg: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_APP; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := fn; n^.right := arg; n^.extra := nil; n^.pat := nil; mk_app := n end;
function mk_match(scrutinee, first_arm: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_MATCH; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := scrutinee; n^.right := first_arm; n^.extra := nil; n^.pat := nil; mk_match := n end;
function mk_arm(p: PPat; body: PExpr): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_MATCH_ARM; n^.ival := 0; n^.op := 0; n^.noff := 0; n^.nlen := 0;
  n^.left := body; n^.right := nil; n^.extra := nil; n^.pat := p; mk_arm := n end;
function mk_var_ref(off, len: integer): PExpr;
var n: PExpr;
begin new(n); n^.next_alloc := expr_alloc_head; expr_alloc_head := n; n^.kind := EK_VAR; n^.ival := 0; n^.op := 0; n^.noff := off; n^.nlen := len;
  n^.left := nil; n^.right := nil; n^.extra := nil; n^.pat := nil; mk_var_ref := n end;

function qualified_name(off, len: integer): integer;
var qoff, i: integer;
begin
  if current_module_len = 0 then begin qualified_name := off; exit end;
  qoff := name_pool_len;
  i := 0;
  while i < current_module_len do begin
    if name_pool_len < NAME_POOL_MAX then begin
      name_pool[name_pool_len] := current_module[i];
      name_pool_len := name_pool_len + 1
    end;
    i := i + 1
  end;
  if name_pool_len < NAME_POOL_MAX then begin
    name_pool[name_pool_len] := '.';
    name_pool_len := name_pool_len + 1
  end;
  i := 0;
  while i < len do begin
    if name_pool_len < NAME_POOL_MAX then begin
      name_pool[name_pool_len] := name_pool[off + i];
      name_pool_len := name_pool_len + 1
    end;
    i := i + 1
  end;
  qualified_name := qoff
end;

function mk_pat_wildcard: PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_WILDCARD; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := nil; p^.sub2 := nil; mk_pat_wildcard := p end;
function mk_pat_int(v: integer): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_INT; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.sub1 := nil; p^.sub2 := nil; mk_pat_int := p end;
function mk_pat_bool(v: integer): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_BOOL; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.sub1 := nil; p^.sub2 := nil; mk_pat_bool := p end;
function mk_pat_var(off, len: integer): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_VAR; p^.ival := 0; p^.noff := off; p^.nlen := len; p^.sub1 := nil; p^.sub2 := nil; mk_pat_var := p end;
function mk_pat_nil: PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_NIL; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := nil; p^.sub2 := nil; mk_pat_nil := p end;
function mk_pat_cons(head_p, tail_p: PPat): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_CONS; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := head_p; p^.sub2 := tail_p; mk_pat_cons := p end;
function mk_pat_pair(a, b: PPat): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_PAIR; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := a; p^.sub2 := b; mk_pat_pair := p end;
function mk_pat_none: PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_NONE; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := nil; p^.sub2 := nil; mk_pat_none := p end;
function mk_pat_some(sub: PPat): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_SOME; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.sub1 := sub; p^.sub2 := nil; mk_pat_some := p end;
function mk_pat_ctor(tag: integer; sub: PPat): PPat;
var p: PPat;
begin new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_CTOR; p^.ival := tag; p^.noff := 0; p^.nlen := 0; p^.sub1 := sub; p^.sub2 := nil; mk_pat_ctor := p end;

function ctor_lookup(noff, nlen: integer): integer;
var i, j: integer; eq: boolean;
begin ctor_lookup := -1; i := 0;
  while i < ctor_count do begin
    if ctor_names_len[i] = nlen then begin
      eq := true; j := 0;
      while (j < nlen) and eq do begin
        if name_pool[ctor_names_off[i]+j] <> name_pool[noff+j] then eq := false;
        j := j+1 end;
      if eq then begin ctor_lookup := i; exit end end;
    i := i+1 end end;
procedure register_ctor(arity: integer);
var off: integer;
begin if ctor_count >= CTOR_MAX then exit;
  off := pool_intern;
  ctor_names_off[ctor_count] := off;
  ctor_names_len[ctor_count] := tok_id_len;
  ctor_arity[ctor_count] := arity;
  ctor_count := ctor_count+1 end;

function tok_is_of: boolean;
begin tok_is_of := (tok = TK_IDENT) and (tok_id_len = 2)
  and (tok_id[0] = 'o') and (tok_id[1] = 'f') end;

function parse_ctor_decl: boolean;
begin
  parse_ctor_decl := false;
  if tok <> TK_IDENT then begin parse_error := true; exit end;
  register_ctor(0);
  lex_next;
  if tok_is_of then begin
    ctor_arity[ctor_count - 1] := 1;
    lex_next;
    while (tok <> TK_PIPE) and (tok <> TK_EOF) and not parse_error do
      lex_next
  end;
  parse_ctor_decl := true
end;

{ === Parser === }
function parse_expr: PExpr; forward;
function parse_seq: PExpr; forward;
function parse_tuple_tail: PExpr; forward;
function parse_list_elements: PExpr; forward;
function parse_pattern: PPat; forward;
function parse_pattern_tuple_tail: PPat; forward;
function parse_pattern_atom: PPat; forward;
function parse_pattern_list: PPat; forward;
function parse_match: PExpr; forward;
function parse_function_expr: PExpr; forward;
function parse_fun_params: PExpr; forward;
function is_atom_start: boolean;
begin is_atom_start := (tok=TK_INT) or (tok=TK_TRUE) or (tok=TK_FALSE) or (tok=TK_IDENT) or (tok=TK_LPAREN) or (tok=TK_LBRACKET) or (tok=TK_LBRACE) or (tok=TK_STRING) end;
function parse_tuple_tail: PExpr;
var e, rest: PExpr;
begin
  e := parse_expr;
  if parse_error then begin parse_tuple_tail := nil; exit end;
  if tok = TK_COMMA then begin
    lex_next;
    rest := parse_tuple_tail;
    parse_tuple_tail := mk_binop(OP_PAIR, e, rest)
  end else
    parse_tuple_tail := e
end;
function parse_atom: PExpr;
var e, f, head, tail, val_e: PExpr; i, field_off, field_len: integer; first_upper: boolean;
begin parse_atom := nil;
  if tok=TK_INT then begin parse_atom := mk_int(tok_int); lex_next; exit end;
  if tok=TK_TRUE then begin parse_atom := mk_bool(1); lex_next; exit end;
  if tok=TK_FALSE then begin parse_atom := mk_bool(0); lex_next; exit end;
  if tok=TK_STRING then begin parse_atom := mk_string_expr(tok_str_off, tok_str_len); lex_next; exit end;
  if tok=TK_IDENT then begin
    { Create EK_VAR for the current ident first (tok_id still has it). }
    first_upper := (tok_id_len > 0) and (tok_id[0] >= 'A') and (tok_id[0] <= 'Z');
    e := mk_var_node;
    lex_next;
    { If followed by '.ident', extend the name in the
      already-created node by appending '.' + ident to the name pool.
      Works because pool_intern writes contiguously and no other
      interns happen between mk_var_node and here. }
    if tok = TK_DOT then begin
      lex_next;
      if tok <> TK_IDENT then begin parse_error := true; exit end;
      if first_upper then begin
        if name_pool_len < NAME_POOL_MAX then begin
          name_pool[name_pool_len] := '.';
          name_pool_len := name_pool_len + 1;
          e^.nlen := e^.nlen + 1
        end;
        i := 0;
        while i < tok_id_len do begin
          if name_pool_len < NAME_POOL_MAX then begin
            name_pool[name_pool_len] := tok_id[i];
            name_pool_len := name_pool_len + 1;
            e^.nlen := e^.nlen + 1
          end;
          i := i + 1
        end
      end else begin
        field_off := pool_intern; field_len := tok_id_len;
        new(f); f^.next_alloc := expr_alloc_head; expr_alloc_head := f; f^.kind := EK_FIELD; f^.ival := 0; f^.op := 0;
        f^.noff := field_off; f^.nlen := field_len;
        f^.left := e; f^.right := nil; f^.extra := nil; f^.pat := nil;
        e := f
      end;
      lex_next
    end;
    if tok = TK_DOT then begin parse_error := true; exit end;
    parse_atom := e;
    exit
  end;
  if tok=TK_LBRACE then begin
    lex_next; head := nil; tail := nil;
    while (tok <> TK_RBRACE) and not parse_error do begin
      if tok <> TK_IDENT then begin parse_error := true; exit end;
      field_off := pool_intern; field_len := tok_id_len;
      lex_next;
      if tok=TK_EQ then lex_next else begin parse_error := true; exit end;
      val_e := parse_expr;
      new(f); f^.next_alloc := expr_alloc_head; expr_alloc_head := f; f^.kind := EK_RECORD; f^.ival := 0; f^.op := 0;
      f^.noff := field_off; f^.nlen := field_len;
      f^.left := val_e; f^.right := nil; f^.extra := nil; f^.pat := nil;
      if head = nil then head := f else tail^.right := f;
      tail := f;
      if tok=TK_SEMI then lex_next
      else if tok <> TK_RBRACE then begin parse_error := true; exit end
    end;
    if tok=TK_RBRACE then lex_next else parse_error := true;
    parse_atom := head;
    exit
  end;
  if tok=TK_LPAREN then begin lex_next;
    if tok=TK_RPAREN then begin parse_atom := mk_int(0); lex_next; exit end;
    e := parse_seq;
    if tok=TK_COMMA then begin
      lex_next;
      e := mk_binop(OP_PAIR, e, parse_tuple_tail);
      if tok=TK_RPAREN then lex_next else parse_error := true
    end
    else if tok=TK_RPAREN then lex_next
    else parse_error := true;
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
  while (is_atom_start or (tok = TK_BANG)) and not parse_error do begin
    if tok = TK_BANG then begin
      lex_next;
      arg := mk_unary(OP_DEREF, parse_atom)
    end else
      arg := parse_atom;
    fn := mk_app(fn, arg)
  end;
  parse_app := fn end;
function parse_unary: PExpr;
var e: PExpr;
begin
  if tok=TK_NOT then begin lex_next; e := parse_unary; parse_unary := mk_unary(OP_NOT, e); exit end;
  if tok=TK_BANG then begin lex_next; e := parse_unary; parse_unary := mk_unary(OP_DEREF, e); exit end;
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
  while ((tok=TK_PLUS) or (tok=TK_MINUS) or (tok=TK_CARET)) and not parse_error do begin
    if tok=TK_PLUS then o := OP_ADD
    else if tok=TK_MINUS then o := OP_SUB
    else o := OP_CONCAT;
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
function parse_assign: PExpr;
var e, r: PExpr;
begin
  e := parse_logic;
  if (tok = TK_ASSIGN) and not parse_error then begin
    lex_next;
    r := parse_expr;
    parse_assign := mk_binop(OP_ASSIGN, e, r)
  end else
    parse_assign := e
end;
function is_pat_start: boolean;
begin is_pat_start := (tok=TK_IDENT) or (tok=TK_INT) or (tok=TK_MINUS)
  or (tok=TK_TRUE) or (tok=TK_FALSE) or (tok=TK_LPAREN) or (tok=TK_LBRACKET) end;
function parse_let_fun_params: PExpr; forward;
function parse_let_fun_params: PExpr;
{ For 'let f P1 P2 .. = body' sugar. End marker is '='. Each parameter
  is a pattern; plain-var patterns use the direct 'fun x -> body' form;
  non-var patterns desugar to 'fun #arg -> match #arg with P -> body'. }
var e, body_e, match_e: PExpr; pat: PPat;
begin
  parse_let_fun_params := nil;
  pat := parse_pattern_atom;
  if parse_error then exit;
  if tok=TK_EQ then begin
    lex_next; body_e := parse_expr
  end else begin
    body_e := parse_let_fun_params
  end;
  if parse_error then exit;
  if pat^.pk = PK_VAR then begin
    e := mk_fun_node(body_e);
    e^.noff := pat^.noff; e^.nlen := pat^.nlen
  end else begin
    match_e := mk_match(mk_var_ref(fn_arg_noff, fn_arg_nlen), mk_arm(pat, body_e));
    e := mk_fun_node(match_e);
    e^.noff := fn_arg_noff; e^.nlen := fn_arg_nlen
  end;
  parse_let_fun_params := e
end;
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
var e, val_e, body_e, match_e, chain_cur, chain_new: PExpr; is_rec, allow_decl: boolean; my_noff, my_nlen: integer;
    let_pat: PPat;
begin parse_expr := nil;
  if tok=TK_TYPE then begin
    lex_next;
    if tok <> TK_IDENT then begin parse_error := true; exit end;
    lex_next;
    if tok <> TK_EQ then begin parse_error := true; exit end;
    lex_next;
    if tok = TK_LBRACE then begin
      while (tok <> TK_RBRACE) and (tok <> TK_EOF) do lex_next;
      if tok = TK_RBRACE then lex_next else begin parse_error := true; exit end
    end else begin
      if tok = TK_PIPE then lex_next;
      if not parse_ctor_decl then exit;
      while tok = TK_PIPE do begin lex_next;
        if not parse_ctor_decl then exit end
    end;
    e := mk_int(0); e^.kind := EK_TYPEDECL; parse_expr := e; exit end;
  if tok=TK_LET then begin
    allow_decl := top_let_allowed;
    top_let_allowed := false;
    lex_next; is_rec := false;
    if tok=TK_REC then begin is_rec := true; lex_next end;
    if is_rec then begin
      { let rec: require plain identifier, no patterns }
      if (tok=TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then begin my_noff := pool_intern; my_nlen := tok_id_len; lex_next end
      else begin parse_error := true; exit end;
      { Parse the first binding's value (function-form sugar or '= expr'). }
      if is_pat_start then begin
        val_e := parse_let_fun_params;
        if parse_error then exit
      end else begin
        if tok=TK_EQ then lex_next else begin parse_error := true; exit end;
        val_e := parse_expr;
        if parse_error then exit
      end;
      e := mk_let_node(val_e, nil);
      e^.noff := my_noff; e^.nlen := my_nlen; e^.ival := 1;
      { 'and NAME ... = body' chain — store each extra binding as another
        EK_LET node linked through the head's extra field. Eval walks the
        chain to install all placeholders before evaluating any body so
        each can reference the others. }
      chain_cur := e;
      while tok = TK_AND do begin
        lex_next;
        if (tok=TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then begin my_noff := pool_intern; my_nlen := tok_id_len; lex_next end
        else begin parse_error := true; exit end;
        if is_pat_start then begin
          val_e := parse_let_fun_params;
          if parse_error then exit
        end else begin
          if tok=TK_EQ then lex_next else begin parse_error := true; exit end;
          val_e := parse_expr;
          if parse_error then exit
        end;
        chain_new := mk_let_node(val_e, nil);
        chain_new^.noff := my_noff; chain_new^.nlen := my_nlen; chain_new^.ival := 1;
        chain_cur^.extra := chain_new;
        chain_cur := chain_new
      end;
      if tok=TK_IN then begin lex_next; body_e := parse_seq; e^.right := body_e end
      else if allow_decl and (tok=TK_EOF) then e^.right := nil
      else begin parse_error := true; exit end;
      parse_expr := e; exit
    end;
    { Non-rec: parse a pattern. If pattern is PK_VAR use fast path;
      else desugar 'let PAT = e in body' to
      'let #let = e in match #let with PAT -> body'.
      Also handle function-form: 'let f x y = body' as sugar for
      'let f = fun x y -> body'. }
    let_pat := parse_pattern;
    if parse_error then exit;
    { Function-form: if pattern was a plain ident and next starts a pattern param }
    if (let_pat^.pk = PK_VAR) and is_pat_start then begin
      val_e := parse_let_fun_params;
      if parse_error then exit;
      if tok=TK_IN then begin lex_next; body_e := parse_seq end
      else if allow_decl and (tok=TK_EOF) then body_e := nil
      else begin parse_error := true; exit end;
      e := mk_let_node(val_e, body_e);
      e^.noff := let_pat^.noff; e^.nlen := let_pat^.nlen;
      if body_e = nil then e^.pat := let_pat;
      parse_expr := e; exit
    end;
    if tok=TK_EQ then lex_next else begin parse_error := true; exit end;
    val_e := parse_expr;
    if tok=TK_IN then begin lex_next; body_e := parse_seq end
    else if allow_decl and (tok=TK_EOF) then body_e := nil
    else begin parse_error := true; exit end;
    if body_e = nil then begin
      e := mk_let_node(val_e, nil);
      e^.pat := let_pat;
      if let_pat^.pk = PK_VAR then begin
        e^.noff := let_pat^.noff; e^.nlen := let_pat^.nlen
      end else begin
        e^.noff := let_tmp_noff; e^.nlen := let_tmp_nlen
      end;
      parse_expr := e; exit
    end;
    if let_pat^.pk = PK_VAR then begin
      e := mk_let_node(val_e, body_e);
      e^.noff := let_pat^.noff; e^.nlen := let_pat^.nlen
    end else begin
      { Desugar: let #let = val_e in match #let with pat -> body_e }
      match_e := mk_match(mk_var_ref(let_tmp_noff, let_tmp_nlen), mk_arm(let_pat, body_e));
      e := mk_let_node(val_e, match_e);
      e^.noff := let_tmp_noff; e^.nlen := let_tmp_nlen
    end;
    parse_expr := e; exit
  end;
  if tok=TK_IF then begin lex_next; val_e := parse_expr;
    if tok=TK_THEN then lex_next else begin parse_error := true; exit end;
    body_e := parse_expr;
    if tok=TK_ELSE then lex_next else begin parse_error := true; exit end;
    e := parse_expr; parse_expr := mk_if(val_e, body_e, e); exit end;
  if tok=TK_FUN then begin lex_next;
    parse_expr := parse_fun_params; exit end;
  if tok=TK_MATCH then begin
    parse_expr := parse_match; exit end;
  if tok=TK_FUNCTION then begin
    parse_expr := parse_function_expr; exit end;
  parse_expr := parse_assign end;

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

{ === Pattern parser === }

function parse_pattern_atom: PPat;
var p, sub: PPat; off, sub_i, j, plen: integer; first_upper: boolean;
begin
  parse_pattern_atom := nil;
  if tok = TK_INT then begin
    parse_pattern_atom := mk_pat_int(tok_int); lex_next; exit end;
  if tok = TK_STRING then begin
    new(p); p^.next_alloc := pat_alloc_head; pat_alloc_head := p; p^.pk := PK_STRING; p^.ival := 0; p^.noff := tok_str_off; p^.nlen := tok_str_len; p^.sub1 := nil; p^.sub2 := nil;
    parse_pattern_atom := p; lex_next; exit end;
  if tok = TK_MINUS then begin
    lex_next;
    if tok <> TK_INT then begin parse_error := true; exit end;
    parse_pattern_atom := mk_pat_int(0 - tok_int); lex_next; exit end;
  if tok = TK_TRUE then begin
    parse_pattern_atom := mk_pat_bool(1); lex_next; exit end;
  if tok = TK_FALSE then begin
    parse_pattern_atom := mk_pat_bool(0); lex_next; exit end;
  if tok = TK_IDENT then begin
    { _ wildcard }
    if (tok_id_len = 1) and (tok_id[0] = '_') then begin
      parse_pattern_atom := mk_pat_wildcard; lex_next; exit end;
    { None }
    if (tok_id_len = 4) and (tok_id[0] = 'N') and (tok_id[1] = 'o')
       and (tok_id[2] = 'n') and (tok_id[3] = 'e') then begin
      parse_pattern_atom := mk_pat_none; lex_next; exit end;
    { Some pat }
    if (tok_id_len = 4) and (tok_id[0] = 'S') and (tok_id[1] = 'o')
       and (tok_id[2] = 'm') and (tok_id[3] = 'e') then begin
      lex_next;
      sub := parse_pattern_atom;
      parse_pattern_atom := mk_pat_some(sub);
      exit
    end;
    first_upper := (tok_id_len > 0) and (tok_id[0] >= 'A') and (tok_id[0] <= 'Z');
    off := pool_intern; plen := tok_id_len;
    lex_next;
    { Qualified ctor: Module.Ctor — extend name_pool with '.next_ident'.
      Mirrors the expression parser's handling at parse_atom (TK_DOT). }
    if first_upper and (tok = TK_DOT) then begin
      lex_next;
      if tok <> TK_IDENT then begin parse_error := true; exit end;
      if name_pool_len < NAME_POOL_MAX then begin
        name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len + 1; plen := plen + 1
      end;
      j := 0;
      while j < tok_id_len do begin
        if name_pool_len < NAME_POOL_MAX then begin
          name_pool[name_pool_len] := tok_id[j]; name_pool_len := name_pool_len + 1; plen := plen + 1
        end;
        j := j + 1
      end;
      lex_next
    end;
    sub_i := ctor_lookup(off, plen);
    if sub_i < 0 then begin
      { Fallback: try the suffix after the last '.'. }
      j := plen - 1;
      while (j >= 0) and (name_pool[off + j] <> '.') do j := j - 1;
      if j >= 0 then sub_i := ctor_lookup(off + j + 1, plen - j - 1)
    end;
    if sub_i >= 0 then begin
      if ctor_arity[sub_i] > 0 then begin
        sub := parse_pattern_atom;
        if parse_error then exit;
        parse_pattern_atom := mk_pat_ctor(sub_i, sub)
      end else
        parse_pattern_atom := mk_pat_ctor(sub_i, nil);
      exit
    end;
    { Deferred qualified-ctor pattern: name has '.' and a sub-pattern
      follows, so the user clearly wants a payload constructor — but no
      matching ctor is registered yet (e.g., the source module hasn't
      been loaded in this REPL session). Build a PK_CTOR with sentinel
      tag -1 carrying the qualified name in noff/nlen; try_match will
      resolve at match time. }
    if (first_upper) and is_pat_start then begin
      sub := parse_pattern_atom;
      if parse_error then exit;
      p := mk_pat_ctor(-1, sub);
      p^.noff := off; p^.nlen := plen;
      parse_pattern_atom := p;
      exit
    end;
    parse_pattern_atom := mk_pat_var(off, plen);
    exit end;
  if tok = TK_LBRACKET then begin
    lex_next;
    if tok = TK_RBRACKET then begin
      parse_pattern_atom := mk_pat_nil; lex_next; exit end;
    p := parse_pattern_list;
    if tok = TK_RBRACKET then lex_next else parse_error := true;
    parse_pattern_atom := p;
    exit
  end;
  if tok = TK_LPAREN then begin
    lex_next;
    if tok = TK_RPAREN then begin
      { unit pattern () -- unit is represented as int 0 }
      parse_pattern_atom := mk_pat_int(0); lex_next; exit end;
    p := parse_pattern;
    if tok = TK_COMMA then begin
      lex_next;
      sub := parse_pattern_tuple_tail;
      p := mk_pat_pair(p, sub)
    end;
    if tok = TK_RPAREN then lex_next else parse_error := true;
    parse_pattern_atom := p;
    exit
  end;
  parse_error := true
end;

function parse_pattern_tuple_tail: PPat;
var p, rest: PPat;
begin
  p := parse_pattern;
  if parse_error then begin parse_pattern_tuple_tail := nil; exit end;
  if tok = TK_COMMA then begin
    lex_next;
    rest := parse_pattern_tuple_tail;
    parse_pattern_tuple_tail := mk_pat_pair(p, rest)
  end else
    parse_pattern_tuple_tail := p
end;

function parse_pattern_list: PPat;
{ Parse p1; p2; ... ; pn (inside [..]) as cons chain ending in nil }
var p, rest: PPat;
begin
  parse_pattern_list := nil;
  p := parse_pattern;
  if parse_error then exit;
  if tok = TK_SEMI then begin
    lex_next;
    rest := parse_pattern_list;
    parse_pattern_list := mk_pat_cons(p, rest)
  end else
    parse_pattern_list := mk_pat_cons(p, mk_pat_nil)
end;

function parse_pattern: PPat;
{ Right-associative :: operator }
var p, rest: PPat;
begin
  p := parse_pattern_atom;
  if (tok = TK_COLONCOLON) and not parse_error then begin
    lex_next;
    rest := parse_pattern;
    parse_pattern := mk_pat_cons(p, rest)
  end else
    parse_pattern := p
end;

function parse_match: PExpr;
{ match expr with [|] pat [when guard] -> body ('|' pat [when guard] -> body)* }
var scrutinee, body, first_arm, arm, prev_arm, guard: PExpr;
    pat: PPat;
begin
  parse_match := nil;
  if tok <> TK_MATCH then begin parse_error := true; exit end;
  lex_next;
  scrutinee := parse_expr;
  if parse_error then exit;
  if tok <> TK_WITH then begin parse_error := true; exit end;
  lex_next;
  if tok = TK_PIPE then lex_next;
  pat := parse_pattern;
  if parse_error then exit;
  guard := nil;
  if tok = TK_WHEN then begin lex_next; guard := parse_expr; if parse_error then exit end;
  if tok <> TK_ARROW then begin parse_error := true; exit end;
  lex_next;
  body := parse_expr;
  if parse_error then exit;
  first_arm := mk_arm(pat, body);
  first_arm^.extra := guard;
  prev_arm := first_arm;
  while (tok = TK_PIPE) and not parse_error do begin
    lex_next;
    pat := parse_pattern;
    if parse_error then exit;
    guard := nil;
    if tok = TK_WHEN then begin lex_next; guard := parse_expr; if parse_error then exit end;
    if tok <> TK_ARROW then begin parse_error := true; exit end;
    lex_next;
    body := parse_expr;
    if parse_error then exit;
    arm := mk_arm(pat, body);
    arm^.extra := guard;
    prev_arm^.right := arm;
    prev_arm := arm
  end;
  parse_match := mk_match(scrutinee, first_arm)
end;

function parse_function_expr: PExpr;
{ 'function' [|]? pat [when guard] -> body ('|' pat [when guard] -> body)*
  Sugar for 'fun #arg -> match #arg with ...' }
var body, first_arm, arm, prev_arm, match_expr, fun_node, guard: PExpr;
    pat: PPat;
begin
  parse_function_expr := nil;
  if tok <> TK_FUNCTION then begin parse_error := true; exit end;
  lex_next;
  if tok = TK_PIPE then lex_next;
  pat := parse_pattern;
  if parse_error then exit;
  guard := nil;
  if tok = TK_WHEN then begin lex_next; guard := parse_expr; if parse_error then exit end;
  if tok <> TK_ARROW then begin parse_error := true; exit end;
  lex_next;
  body := parse_expr;
  if parse_error then exit;
  first_arm := mk_arm(pat, body);
  first_arm^.extra := guard;
  prev_arm := first_arm;
  while (tok = TK_PIPE) and not parse_error do begin
    lex_next;
    pat := parse_pattern;
    if parse_error then exit;
    guard := nil;
    if tok = TK_WHEN then begin lex_next; guard := parse_expr; if parse_error then exit end;
    if tok <> TK_ARROW then begin parse_error := true; exit end;
    lex_next;
    body := parse_expr;
    if parse_error then exit;
    arm := mk_arm(pat, body);
    arm^.extra := guard;
    prev_arm^.right := arm;
    prev_arm := arm
  end;
  { Build: fun #arg -> match #arg with arms }
  match_expr := mk_match(mk_var_ref(fn_arg_noff, fn_arg_nlen), first_arm);
  fun_node := mk_fun_node(match_expr);
  fun_node^.noff := fn_arg_noff;
  fun_node^.nlen := fn_arg_nlen;
  parse_function_expr := fun_node
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
begin new(e);
  e^.next_alloc := env_alloc_head; env_alloc_head := e;
   e^.noff := noff; e^.nlen := nlen; e^.val := v; e^.next := env; env_extend := e end;
function name_has_dot(noff, nlen: integer): boolean;
var i: integer;
begin
  name_has_dot := false;
  i := 0;
  while i < nlen do begin
    if name_pool[noff + i] = '.' then begin name_has_dot := true; exit end;
    i := i + 1
  end
end;
function env_strip_unqualified(env: PEnv): PEnv;
var cur, res: PEnv;
begin
  res := nil;
  cur := env;
  while cur <> nil do begin
    if name_has_dot(cur^.noff, cur^.nlen) then
      res := env_extend(res, cur^.noff, cur^.nlen, cur^.val);
    cur := cur^.next
  end;
  env_strip_unqualified := res
end;
function mk_val_int(v: integer): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_INT; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_int := p end;
function mk_val_bool(v: integer): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_BOOL; p^.ival := v; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_bool := p end;
function mk_val_closure(noff, nlen: integer; body: PExpr; env: PEnv): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_CLOSURE; p^.ival := 0; p^.noff := noff; p^.nlen := nlen; p^.body := body; p^.cenv := env; p^.head := nil; p^.tail := nil; mk_val_closure := p end;
function mk_val_nil: PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_NIL; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_nil := p end;
function mk_val_cons(h, t: PVal): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_CONS; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := h; p^.tail := t; mk_val_cons := p end;
function mk_val_pair(a, b: PVal): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_PAIR; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := a; p^.tail := b; mk_val_pair := p end;
function mk_val_none: PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_NONE; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_none := p end;
function mk_val_some(x: PVal): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_SOME; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := x; p^.tail := nil; mk_val_some := p end;
function mk_val_string(off, len: integer): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_STRING; p^.ival := 0; p^.noff := off; p^.nlen := len; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_string := p end;
function mk_val_unit: PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_UNIT; p^.ival := 0; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_unit := p end;
function mk_val_ctor(tag: integer): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_CTOR; p^.ival := tag; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := nil; p^.tail := nil; mk_val_ctor := p end;
function mk_val_ctor_arg(tag: integer; arg: PVal): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_CTOR; p^.ival := tag; p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.cenv := nil; p^.head := arg; p^.tail := nil; mk_val_ctor_arg := p end;
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
procedure intern_list_module;
begin
  { "List.length" = L i s t . l e n g t h = 11 chars }
  list_length_noff := name_pool_len;
  name_pool[name_pool_len] := 'L'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  list_length_nlen := 11;
  { "List.rev" = 8 chars }
  list_rev_noff := name_pool_len;
  name_pool[name_pool_len] := 'L'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'v'; name_pool_len := name_pool_len+1;
  list_rev_nlen := 8;
  { "List.hd" = 7 chars }
  list_hd_noff := name_pool_len;
  name_pool[name_pool_len] := 'L'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  list_hd_nlen := 7;
  { "List.tl" = 7 chars }
  list_tl_noff := name_pool_len;
  name_pool[name_pool_len] := 'L'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  list_tl_nlen := 7;
  { "List.is_empty" = 13 chars }
  list_isempty_noff := name_pool_len;
  name_pool[name_pool_len] := 'L'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'm'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'y'; name_pool_len := name_pool_len+1;
  list_isempty_nlen := 13
end;
procedure pool_put(c: char);
begin if name_pool_len < NAME_POOL_MAX then begin
  name_pool[name_pool_len] := c; name_pool_len := name_pool_len+1 end end;
procedure intern_list_hof;
begin
  list_map_noff := name_pool_len;
  pool_put('L'); pool_put('i'); pool_put('s'); pool_put('t'); pool_put('.');
  pool_put('m'); pool_put('a'); pool_put('p');
  list_map_nlen := 8;
  list_filter_noff := name_pool_len;
  pool_put('L'); pool_put('i'); pool_put('s'); pool_put('t'); pool_put('.');
  pool_put('f'); pool_put('i'); pool_put('l'); pool_put('t'); pool_put('e'); pool_put('r');
  list_filter_nlen := 11;
  list_fold_noff := name_pool_len;
  pool_put('L'); pool_put('i'); pool_put('s'); pool_put('t'); pool_put('.');
  pool_put('f'); pool_put('o'); pool_put('l'); pool_put('d'); pool_put('_');
  pool_put('l'); pool_put('e'); pool_put('f'); pool_put('t');
  list_fold_nlen := 14;
  list_iter_noff := name_pool_len;
  pool_put('L'); pool_put('i'); pool_put('s'); pool_put('t'); pool_put('.');
  pool_put('i'); pool_put('t'); pool_put('e'); pool_put('r');
  list_iter_nlen := 9;
  list_find_noff := name_pool_len;
  pool_put('L'); pool_put('i'); pool_put('s'); pool_put('t'); pool_put('.');
  pool_put('f'); pool_put('i'); pool_put('n'); pool_put('d'); pool_put('_');
  pool_put('o'); pool_put('p'); pool_put('t');
  list_find_nlen := 13
end;
procedure intern_string_conv;
begin
  string_of_int_noff := name_pool_len;
  pool_put('s'); pool_put('t'); pool_put('r'); pool_put('i'); pool_put('n'); pool_put('g');
  pool_put('_'); pool_put('o'); pool_put('f'); pool_put('_');
  pool_put('i'); pool_put('n'); pool_put('t');
  string_of_int_nlen := 13;
  int_of_string_noff := name_pool_len;
  pool_put('i'); pool_put('n'); pool_put('t');
  pool_put('_'); pool_put('o'); pool_put('f'); pool_put('_');
  pool_put('s'); pool_put('t'); pool_put('r'); pool_put('i'); pool_put('n'); pool_put('g');
  int_of_string_nlen := 13
end;
procedure intern_pair_ops;
begin
  fst_noff := name_pool_len;
  name_pool[name_pool_len] := 'f'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  fst_nlen := 3;
  snd_noff := name_pool_len;
  name_pool[name_pool_len] := 's'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  snd_nlen := 3
end;
procedure intern_option;
begin
  none_noff := name_pool_len;
  name_pool[name_pool_len] := 'N'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  none_nlen := 4;
  some_noff := name_pool_len;
  name_pool[name_pool_len] := 'S'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'm'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  some_nlen := 4;
  ok_ctor_tag := ctor_count;
  ctor_names_off[ctor_count] := name_pool_len;
  pool_put('O'); pool_put('k');
  ctor_names_len[ctor_count] := 2;
  ctor_arity[ctor_count] := 1;
  ctor_count := ctor_count + 1;
  error_ctor_tag := ctor_count;
  ctor_names_off[ctor_count] := name_pool_len;
  pool_put('E'); pool_put('r'); pool_put('r'); pool_put('o'); pool_put('r');
  ctor_names_len[ctor_count] := 5;
  ctor_arity[ctor_count] := 1;
  ctor_count := ctor_count + 1;
  result_bind_noff := name_pool_len;
  pool_put('R'); pool_put('e'); pool_put('s'); pool_put('u'); pool_put('l'); pool_put('t');
  pool_put('.'); pool_put('b'); pool_put('i'); pool_put('n'); pool_put('d');
  result_bind_nlen := 11
end;
procedure intern_fn_arg;
begin
  { Synthetic parameter name for 'function' -- unlikely to collide since
    real user identifiers can't contain '#'. }
  fn_arg_noff := name_pool_len;
  name_pool[name_pool_len] := '#'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'a'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  fn_arg_nlen := 4;
  { Synthetic temp for let-destructuring. }
  let_tmp_noff := name_pool_len;
  name_pool[name_pool_len] := '#'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  let_tmp_nlen := 4
end;
procedure intern_string_ops;
begin
  print_endline_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  print_endline_nlen := 13;
  string_length_noff := name_pool_len;
  name_pool[name_pool_len] := 'S'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  string_length_nlen := 13;
  string_make_noff := name_pool_len;
  name_pool[name_pool_len] := 'S'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'm'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'a'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'k'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  string_make_nlen := 11;
  peek_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'k'; name_pool_len := name_pool_len+1;
  peek_nlen := 4;
  poke_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'k'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  poke_nlen := 4
end;
procedure intern_module_directive;
begin
  module_directive_noff := name_pool_len;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'm'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'u'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  module_directive_nlen := 8
end;
procedure intern_char_ops;
begin
  char_code_noff := name_pool_len;
  name_pool[name_pool_len] := 'C'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'a'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'c'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'o'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  char_code_nlen := 9;
  char_chr_noff := name_pool_len;
  name_pool[name_pool_len] := 'C'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'a'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '.'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'c'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'h'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  char_chr_nlen := 8
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
  putc_nlen := 4;
  getc_noff := name_pool_len;
  name_pool[name_pool_len] := 'g'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'c'; name_pool_len := name_pool_len+1;
  getc_nlen := 4;
  read_line_noff := name_pool_len;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'a'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'd'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'l'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  read_line_nlen := 9;
  ref_noff := name_pool_len;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'f'; name_pool_len := name_pool_len+1;
  ref_nlen := 3;
  exit_noff := name_pool_len;
  name_pool[name_pool_len] := 'e'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'x'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len+1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len+1;
  exit_nlen := 4
end;
function try_match(p: PPat; v: PVal; env: PEnv): PEnv; forward;
function try_match(p: PPat; v: PVal; env: PEnv): PEnv;
{ Attempts to match pattern p against value v, extending env.
  Sets match_success := true on success, false on fail.
  Returns extended env on success (or env unchanged if no bindings). }
var e1: PEnv; e1_i: integer;
begin
  try_match := env;
  match_success := true;
  e1_i := 0;
  if p = nil then begin match_success := false; exit end;
  if v = nil then begin match_success := false; exit end;

  if p^.pk = PK_WILDCARD then exit;

  if p^.pk = PK_VAR then begin
    try_match := env_extend(env, p^.noff, p^.nlen, v);
    exit
  end;

  if p^.pk = PK_INT then begin
    if (v^.vk = VK_INT) and (v^.ival = p^.ival) then exit;
    if (p^.ival = 0) and (v^.vk = VK_UNIT) then exit;
    match_success := false; exit
  end;

  if p^.pk = PK_BOOL then begin
    if (v^.vk = VK_BOOL) and (v^.ival = p^.ival) then exit;
    match_success := false; exit
  end;

  if p^.pk = PK_STRING then begin
    if v^.vk <> VK_STRING then begin match_success := false; exit end;
    if v^.nlen <> p^.nlen then begin match_success := false; exit end;
    e1_i := 0;
    while e1_i < p^.nlen do begin
      if string_pool[v^.noff + e1_i] <> string_pool[p^.noff + e1_i] then begin
        match_success := false; exit
      end;
      e1_i := e1_i + 1
    end;
    exit
  end;

  if p^.pk = PK_NIL then begin
    if v^.vk = VK_NIL then exit;
    match_success := false; exit
  end;

  if p^.pk = PK_CONS then begin
    if v^.vk <> VK_CONS then begin match_success := false; exit end;
    e1 := try_match(p^.sub1, v^.head, env);
    if not match_success then exit;
    try_match := try_match(p^.sub2, v^.tail, e1);
    exit
  end;

  if p^.pk = PK_PAIR then begin
    if v^.vk <> VK_PAIR then begin match_success := false; exit end;
    e1 := try_match(p^.sub1, v^.head, env);
    if not match_success then exit;
    try_match := try_match(p^.sub2, v^.tail, e1);
    exit
  end;

  if p^.pk = PK_NONE then begin
    if v^.vk = VK_NONE then exit;
    match_success := false; exit
  end;

  if p^.pk = PK_SOME then begin
    if v^.vk <> VK_SOME then begin match_success := false; exit end;
    try_match := try_match(p^.sub1, v^.head, env);
    exit
  end;

  if p^.pk = PK_CTOR then begin
    if v^.vk <> VK_CTOR then begin match_success := false; exit end;
    if p^.ival < 0 then begin
      { Deferred qualified-ctor pattern (e.g., Lexer.TIdent bs parsed
        before Lexer was loaded, or with same-basename collision):
        resolve the ctor tag now using the qualified name in noff/nlen.
        Try full name first, then suffix after the last '.'. }
      e1_i := ctor_lookup(p^.noff, p^.nlen);
      if e1_i < 0 then begin
        e1_i := p^.nlen - 1;
        while (e1_i >= 0) and (name_pool[p^.noff + e1_i] <> '.') do e1_i := e1_i - 1;
        if e1_i >= 0 then e1_i := ctor_lookup(p^.noff + e1_i + 1, p^.nlen - e1_i - 1)
        else e1_i := -1
      end;
      if e1_i < 0 then begin match_success := false; exit end;
      if v^.ival <> e1_i then begin match_success := false; exit end;
      if ctor_arity[e1_i] > 0 then begin
        try_match := try_match(p^.sub1, v^.head, env);
        exit
      end;
      exit
    end;
    if v^.ival <> p^.ival then begin match_success := false; exit end;
    if ctor_arity[p^.ival] > 0 then begin
      try_match := try_match(p^.sub1, v^.head, env);
      exit
    end;
    exit end;

  match_success := false end;

function list_length_impl(l: PVal): integer;
var n: integer;
begin
  n := 0;
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    n := n + 1;
    l := l^.tail
  end;
  list_length_impl := n
end;

function list_rev_impl(l: PVal): PVal;
var acc: PVal;
begin
  acc := mk_val_nil;
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    acc := mk_val_cons(l^.head, acc);
    l := l^.tail
  end;
  list_rev_impl := acc
end;

function eval_expr(e: PExpr; env: PEnv): PVal; forward;

{ Apply a user-defined closure value to an argument. Builtin closures
  (body = nil) are not supported as HOF callbacks — wrap in 'fun x -> f x'. }
function apply_val(fv, av: PVal): PVal;
var ne: PEnv;
begin apply_val := nil;
  if fv = nil then begin eval_error := true; exit end;
  if fv^.vk <> VK_CLOSURE then begin eval_error := true; exit end;
  if fv^.body = nil then begin eval_error := true; exit end;
  ne := env_extend(fv^.cenv, fv^.noff, fv^.nlen, av);
  apply_val := eval_expr(fv^.body, ne) end;

function list_map_impl(f, l: PVal): PVal;
var head, tail, cell, v: PVal;
begin head := nil; tail := nil;
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    v := apply_val(f, l^.head);
    if eval_error then begin list_map_impl := nil; exit end;
    cell := mk_val_cons(v, mk_val_nil);
    if head = nil then head := cell else tail^.tail := cell;
    tail := cell;
    l := l^.tail end;
  if head = nil then list_map_impl := mk_val_nil else list_map_impl := head end;

function list_filter_impl(f, l: PVal): PVal;
var head, tail, cell, v: PVal;
begin head := nil; tail := nil;
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    v := apply_val(f, l^.head);
    if eval_error then begin list_filter_impl := nil; exit end;
    if (v^.vk = VK_BOOL) and (v^.ival <> 0) then begin
      cell := mk_val_cons(l^.head, mk_val_nil);
      if head = nil then head := cell else tail^.tail := cell;
      tail := cell end;
    l := l^.tail end;
  if head = nil then list_filter_impl := mk_val_nil else list_filter_impl := head end;

function list_fold_impl(f, acc, l: PVal): PVal;
var partial: PVal;
begin
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    partial := apply_val(f, acc);
    if eval_error then begin list_fold_impl := nil; exit end;
    acc := apply_val(partial, l^.head);
    if eval_error then begin list_fold_impl := nil; exit end;
    l := l^.tail end;
  list_fold_impl := acc end;

function list_find_impl(f, l: PVal): PVal;
var v: PVal;
begin
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    v := apply_val(f, l^.head);
    if eval_error then begin list_find_impl := nil; exit end;
    if (v^.vk = VK_BOOL) and (v^.ival <> 0) then begin
      list_find_impl := mk_val_some(l^.head);
      exit
    end;
    l := l^.tail
  end;
  list_find_impl := mk_val_none
end;

function string_of_int_impl(n: integer): PVal;
var tmp_len, i: integer; is_neg: boolean; off, len: integer;
begin
  is_neg := false;
  if n < 0 then begin is_neg := true; n := -n end;
  tmp_len := 0;
  if n = 0 then begin soi_tmp[0] := '0'; tmp_len := 1 end
  else while n > 0 do begin
    soi_tmp[tmp_len] := chr(ord('0') + (n mod 10));
    tmp_len := tmp_len + 1;
    n := n div 10
  end;
  off := string_pool_len; len := 0;
  if is_neg then begin
    if string_pool_len < 32767 then begin
      string_pool[string_pool_len] := '-'; string_pool_len := string_pool_len + 1; len := 1
    end
  end;
  i := tmp_len - 1;
  while i >= 0 do begin
    if string_pool_len < 32767 then begin
      string_pool[string_pool_len] := soi_tmp[i]; string_pool_len := string_pool_len + 1; len := len + 1
    end;
    i := i - 1
  end;
  string_of_int_impl := mk_val_string(off, len)
end;

function int_of_string_impl(s: PVal): PVal;
var i, j, acc: integer; is_neg: boolean; c: char;
begin
  { Lenient: empty string, missing digits, or non-digit chars return 0.
    Lets interactive demos survive stray input without tripping the REPL's
    eval_error path. }
  if s^.nlen = 0 then begin int_of_string_impl := mk_val_int(0); exit end;
  i := s^.noff; j := s^.noff + s^.nlen;
  is_neg := false;
  if string_pool[i] = '-' then begin is_neg := true; i := i + 1 end;
  if i >= j then begin int_of_string_impl := mk_val_int(0); exit end;
  acc := 0;
  while i < j do begin
    c := string_pool[i];
    if (c < '0') or (c > '9') then begin int_of_string_impl := mk_val_int(0); exit end;
    acc := acc * 10 + (ord(c) - ord('0'));
    i := i + 1
  end;
  if is_neg then acc := -acc;
  int_of_string_impl := mk_val_int(acc)
end;

function list_iter_impl(f, l: PVal): PVal;
var v: PVal;
begin
  while (l <> nil) and (l^.vk = VK_CONS) do begin
    v := apply_val(f, l^.head);
    if eval_error then begin list_iter_impl := nil; exit end;
    l := l^.tail end;
  list_iter_impl := mk_val_unit end;

{ Partial-application builder for list HOFs.
  Stashes (f) or (f, acc) inside a fresh nil-body closure that reuses the
  HOF's name; the ival field is the partial-app stage (0=bare, 1=has fn,
  2=has fn+acc for fold). Stages 1/2 are detected in EK_APP dispatch. }
function mk_partial(noff, nlen, stage: integer; f, acc: PVal): PVal;
var p: PVal;
begin new(p); p^.next_alloc := val_alloc_head; val_alloc_head := p; p^.vk := VK_CLOSURE; p^.ival := stage;
  p^.noff := noff; p^.nlen := nlen;
  p^.body := nil; p^.cenv := nil;
  p^.head := f; p^.tail := acc;
  mk_partial := p end;

function eval_expr(e: PExpr; env: PEnv): PVal;
var lv, rv, fv, av, refv, rec_head, fieldv, cur_field: PVal; l, r, x, bd, arm: PExpr; ne, ce: PEnv; a, b, res: integer;
begin eval_expr := nil;
  { Trampoline for tail-call optimization: tail-position calls (EK_IF/LET/
    MATCH/APP bodies) reassign (e, env) and loop rather than recursing,
    so recursive OCaml programs run in constant Pascal-stack space. }
  while true do begin
  if e = nil then begin eval_error := true; exit end;
  if e^.kind = EK_INT then begin eval_expr := mk_val_int(e^.ival); exit end;
  if e^.kind = EK_BOOL then begin eval_expr := mk_val_bool(e^.ival); exit end;
  if e^.kind = EK_NIL then begin eval_expr := mk_val_nil; exit end;
  if e^.kind = EK_STRING then begin eval_expr := mk_val_string(e^.noff, e^.nlen); exit end;
  if e^.kind = EK_TYPEDECL then begin eval_expr := mk_val_unit; exit end;
  if e^.kind = EK_RECORD then begin
    rec_head := nil;
    while e <> nil do begin
      rv := eval_expr(e^.left, env);
      if eval_error then exit;
      new(fieldv); fieldv^.next_alloc := val_alloc_head; val_alloc_head := fieldv; fieldv^.vk := VK_FIELD; fieldv^.ival := 0;
      fieldv^.noff := e^.noff; fieldv^.nlen := e^.nlen;
      fieldv^.body := nil; fieldv^.cenv := nil; fieldv^.head := rv; fieldv^.tail := rec_head;
      rec_head := fieldv;
      e := e^.right
    end;
    new(refv); refv^.next_alloc := val_alloc_head; val_alloc_head := refv; refv^.vk := VK_RECORD; refv^.ival := 0; refv^.noff := 0; refv^.nlen := 0;
    refv^.body := nil; refv^.cenv := nil; refv^.head := rec_head; refv^.tail := nil;
    eval_expr := refv;
    exit
  end;
  if e^.kind = EK_FIELD then begin
    lv := eval_expr(e^.left, env);
    if eval_error then exit;
    if lv^.vk <> VK_RECORD then begin eval_error := true; exit end;
    cur_field := lv^.head;
    while cur_field <> nil do begin
      if names_equal(cur_field^.noff, cur_field^.nlen, e^.noff, e^.nlen) then begin
        eval_expr := cur_field^.head;
        exit
      end;
      cur_field := cur_field^.tail
    end;
    eval_error := true;
    exit
  end;
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
    if names_equal(e^.noff, e^.nlen, getc_noff, getc_nlen) then begin
      eval_expr := mk_val_closure(getc_noff, getc_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, read_line_noff, read_line_nlen) then begin
      eval_expr := mk_val_closure(read_line_noff, read_line_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, ref_noff, ref_nlen) then begin
      eval_expr := mk_val_closure(ref_noff, ref_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, exit_noff, exit_nlen) then begin
      eval_expr := mk_val_closure(exit_noff, exit_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, nil_noff, nil_nlen) then begin
      eval_expr := mk_val_nil; exit end;
    if names_equal(e^.noff, e^.nlen, hd_noff, hd_nlen) then begin
      eval_expr := mk_val_closure(hd_noff, hd_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, tl_noff, tl_nlen) then begin
      eval_expr := mk_val_closure(tl_noff, tl_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, isempty_noff, isempty_nlen) then begin
      eval_expr := mk_val_closure(isempty_noff, isempty_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_length_noff, list_length_nlen) then begin
      eval_expr := mk_val_closure(list_length_noff, list_length_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_rev_noff, list_rev_nlen) then begin
      eval_expr := mk_val_closure(list_rev_noff, list_rev_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_hd_noff, list_hd_nlen) then begin
      eval_expr := mk_val_closure(hd_noff, hd_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_tl_noff, list_tl_nlen) then begin
      eval_expr := mk_val_closure(tl_noff, tl_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_isempty_noff, list_isempty_nlen) then begin
      eval_expr := mk_val_closure(isempty_noff, isempty_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_map_noff, list_map_nlen) then begin
      eval_expr := mk_val_closure(list_map_noff, list_map_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_filter_noff, list_filter_nlen) then begin
      eval_expr := mk_val_closure(list_filter_noff, list_filter_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_fold_noff, list_fold_nlen) then begin
      eval_expr := mk_val_closure(list_fold_noff, list_fold_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_iter_noff, list_iter_nlen) then begin
      eval_expr := mk_val_closure(list_iter_noff, list_iter_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, list_find_noff, list_find_nlen) then begin
      eval_expr := mk_val_closure(list_find_noff, list_find_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, string_of_int_noff, string_of_int_nlen) then begin
      eval_expr := mk_val_closure(string_of_int_noff, string_of_int_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, int_of_string_noff, int_of_string_nlen) then begin
      eval_expr := mk_val_closure(int_of_string_noff, int_of_string_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, fst_noff, fst_nlen) then begin
      eval_expr := mk_val_closure(fst_noff, fst_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, snd_noff, snd_nlen) then begin
      eval_expr := mk_val_closure(snd_noff, snd_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, none_noff, none_nlen) then begin
      eval_expr := mk_val_none; exit end;
    if names_equal(e^.noff, e^.nlen, some_noff, some_nlen) then begin
      eval_expr := mk_val_closure(some_noff, some_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, result_bind_noff, result_bind_nlen) then begin
      eval_expr := mk_val_closure(result_bind_noff, result_bind_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, print_endline_noff, print_endline_nlen) then begin
      eval_expr := mk_val_closure(print_endline_noff, print_endline_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, string_length_noff, string_length_nlen) then begin
      eval_expr := mk_val_closure(string_length_noff, string_length_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, char_code_noff, char_code_nlen) then begin
      eval_expr := mk_val_closure(char_code_noff, char_code_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, char_chr_noff, char_chr_nlen) then begin
      eval_expr := mk_val_closure(char_chr_noff, char_chr_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, string_make_noff, string_make_nlen) then begin
      eval_expr := mk_val_closure(string_make_noff, string_make_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, peek_noff, peek_nlen) then begin
      eval_expr := mk_val_closure(peek_noff, peek_nlen, nil, nil); exit end;
    if names_equal(e^.noff, e^.nlen, poke_noff, poke_nlen) then begin
      eval_expr := mk_val_closure(poke_noff, poke_nlen, nil, nil); exit end;
    a := ctor_lookup(e^.noff, e^.nlen);
    if a < 0 then begin
      { Qualified-ctor fallback: try the suffix after the last '.'.
        Lets Module.Ctor resolve the same as Ctor when the name is
        defined as a constructor (e.g. cross-module Ast.AProgram). }
      b := e^.nlen - 1;
      while (b >= 0) and (name_pool[e^.noff + b] <> '.') do b := b - 1;
      if b >= 0 then a := ctor_lookup(e^.noff + b + 1, e^.nlen - b - 1)
    end;
    if a >= 0 then begin
      if ctor_arity[a] > 0 then
        eval_expr := mk_val_closure(ctor_names_off[a], ctor_names_len[a], nil, nil)
      else
        eval_expr := mk_val_ctor(a);
      exit
    end;
    eval_expr := env_lookup(env, e^.noff, e^.nlen); exit end;
  if e^.kind = EK_BINOP then begin
    l := e^.left; r := e^.right;
    lv := eval_expr(l, env); rv := eval_expr(r, env);
    if eval_error then exit;
    if e^.op = OP_CONS then begin
      eval_expr := mk_val_cons(lv, rv); exit
    end;
    if e^.op = OP_PAIR then begin
      eval_expr := mk_val_pair(lv, rv); exit
    end;
    if e^.op = OP_ASSIGN then begin
      if lv^.vk <> VK_REF then begin eval_error := true; exit end;
      lv^.head := rv;
      eval_expr := mk_val_unit;
      exit
    end;
    if e^.op = OP_CONCAT then begin
      if (lv^.vk <> VK_STRING) or (rv^.vk <> VK_STRING) then begin eval_error := true; exit end;
      { Copy lv then rv into a new region of string_pool }
      a := string_pool_len;
      res := 0;
      while res < lv^.nlen do begin
        if string_pool_len < 32767 then begin string_pool[string_pool_len] := string_pool[lv^.noff + res]; string_pool_len := string_pool_len + 1 end;
        res := res + 1
      end;
      res := 0;
      while res < rv^.nlen do begin
        if string_pool_len < 32767 then begin string_pool[string_pool_len] := string_pool[rv^.noff + res]; string_pool_len := string_pool_len + 1 end;
        res := res + 1
      end;
      eval_expr := mk_val_string(a, lv^.nlen + rv^.nlen);
      exit
    end;
    if ((e^.op = OP_EQ) or (e^.op = OP_NEQ))
       and (lv^.vk = VK_STRING) and (rv^.vk = VK_STRING) then begin
      if lv^.nlen <> rv^.nlen then res := 0
      else begin
        res := 1; a := 0;
        while a < lv^.nlen do begin
          if string_pool[lv^.noff + a] <> string_pool[rv^.noff + a] then begin
            res := 0; a := lv^.nlen
          end else a := a + 1
        end
      end;
      if e^.op = OP_NEQ then begin
        if res = 1 then res := 0 else res := 1
      end;
      eval_expr := mk_val_bool(res); exit
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
    if e^.op = OP_DEREF then begin
      if lv^.vk <> VK_REF then begin eval_error := true; exit end;
      eval_expr := lv^.head;
      exit
    end;
    if lv^.ival=0 then eval_expr := mk_val_bool(1) else eval_expr := mk_val_bool(0); exit end;
  if e^.kind = EK_IF then begin
    l := e^.left; lv := eval_expr(l, env); if eval_error then exit;
    if lv^.ival <> 0 then e := e^.right
    else e := e^.extra end
  else if e^.kind = EK_LET then begin
    l := e^.left;
    if e^.ival = 1 then begin
      lv := mk_val_closure(0, 0, nil, nil);
      ne := env_extend(env, e^.noff, e^.nlen, lv);
      { let rec ... and ... — walk extra chain to install all placeholder
        bindings before evaluating any body, so each body can resolve the
        others' names. }
      arm := e^.extra;
      while arm <> nil do begin
        cur_field := mk_val_closure(0, 0, nil, nil);
        ne := env_extend(ne, arm^.noff, arm^.nlen, cur_field);
        arm := arm^.extra
      end;
      rv := eval_expr(l, ne); if eval_error then exit;
      lv^.vk := rv^.vk; lv^.ival := rv^.ival; lv^.noff := rv^.noff; lv^.nlen := rv^.nlen;
      lv^.body := rv^.body; lv^.cenv := ne;
      arm := e^.extra;
      while arm <> nil do begin
        cur_field := env_lookup(ne, arm^.noff, arm^.nlen);
        if eval_error then exit;
        rv := eval_expr(arm^.left, ne); if eval_error then exit;
        cur_field^.vk := rv^.vk; cur_field^.ival := rv^.ival; cur_field^.noff := rv^.noff; cur_field^.nlen := rv^.nlen;
        cur_field^.body := rv^.body; cur_field^.cenv := ne;
        arm := arm^.extra
      end
    end else begin
      lv := eval_expr(l, env); if eval_error then exit;
      ne := env_extend(env, e^.noff, e^.nlen, lv) end;
    e := e^.right; env := ne end
  else if e^.kind = EK_FUN then begin
    eval_expr := mk_val_closure(e^.noff, e^.nlen, e^.left, env); exit end
  else if e^.kind = EK_MATCH then begin
    l := e^.left;
    lv := eval_expr(l, env);
    if eval_error then exit;
    arm := e^.right;
    bd := nil;
    while (arm <> nil) and (bd = nil) do begin
      ne := try_match(arm^.pat, lv, env);
      if match_success then begin
        if arm^.extra <> nil then begin
          rv := eval_expr(arm^.extra, ne);
          if eval_error then exit;
          if (rv^.vk = VK_BOOL) and (rv^.ival = 1) then bd := arm^.left
          else arm := arm^.right
        end else bd := arm^.left
      end else arm := arm^.right
    end;
    if bd = nil then begin eval_error := true; exit end;
    e := bd; env := ne end
  else if e^.kind = EK_APP then begin
    l := e^.left; fv := eval_expr(l, env); if eval_error then exit;
    r := e^.right; av := eval_expr(r, env); if eval_error then exit;
    if fv^.vk <> VK_CLOSURE then begin eval_error := true; exit end;
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
        if names_equal(fv^.noff, fv^.nlen, getc_noff, getc_nlen) then begin
          read(getc_ch);
          { Pascal runtime's eof() pre-reads one byte into its lookahead buffer.
            When the lexer exits on the source's 0x04 EOT terminator, that EOT
            is often already cached in the lookahead — so the first runtime
            read(ch) returns 0x04 instead of the user's input byte. Skip it.
            This only fires for the first getc after source ingestion; later
            getc calls bypass lookahead and go straight to sys_getc. }
          if getc_ch = chr(4) then read(getc_ch);
          eval_expr := mk_val_int(ord(getc_ch)); exit end;
        if names_equal(fv^.noff, fv^.nlen, read_line_noff, read_line_nlen) then begin
          { Accumulate bytes into string_pool until LF or CR (neither included).
            Echoes each typed char and handles backspace (8/127) so a live
            terminal user sees their input, mirroring lex_init. Skips the
            same leading 0x04 EOT quirk as getc on the very first read.
            Note: a bare CR terminates; a following LF will show up on the
            next read_line call as an empty string. See docs/stdin-and-getc.md. }
          a := string_pool_len;
          read(read_line_ch);
          if read_line_ch = chr(4) then read(read_line_ch);
          while (read_line_ch <> chr(10)) and (read_line_ch <> chr(13)) do begin
            if (read_line_ch = chr(8)) or (read_line_ch = chr(127)) then begin
              if string_pool_len > a then begin
                string_pool_len := string_pool_len - 1;
                write(chr(8)); write(' '); write(chr(8))
              end
            end else begin
              write(read_line_ch);
              if string_pool_len < 32767 then begin
                string_pool[string_pool_len] := read_line_ch;
                string_pool_len := string_pool_len + 1
              end
            end;
            read(read_line_ch)
          end;
          crlf;
          eval_expr := mk_val_string(a, string_pool_len - a); exit end;
        if names_equal(fv^.noff, fv^.nlen, ref_noff, ref_nlen) then begin
          new(refv); refv^.next_alloc := val_alloc_head; val_alloc_head := refv; refv^.vk := VK_REF; refv^.ival := 0; refv^.noff := 0; refv^.nlen := 0;
          refv^.body := nil; refv^.cenv := nil; refv^.head := av; refv^.tail := nil;
          eval_expr := refv; exit end;
        if names_equal(fv^.noff, fv^.nlen, exit_noff, exit_nlen) then begin
          exit_requested := true; eval_expr := mk_val_unit; exit end;
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
        if names_equal(fv^.noff, fv^.nlen, list_length_noff, list_length_nlen) then begin
          if (av^.vk <> VK_NIL) and (av^.vk <> VK_CONS) then begin eval_error := true; exit end;
          eval_expr := mk_val_int(list_length_impl(av)); exit end;
        if names_equal(fv^.noff, fv^.nlen, list_rev_noff, list_rev_nlen) then begin
          if (av^.vk <> VK_NIL) and (av^.vk <> VK_CONS) then begin eval_error := true; exit end;
          eval_expr := list_rev_impl(av); exit end;
        if names_equal(fv^.noff, fv^.nlen, fst_noff, fst_nlen) then begin
          if av^.vk <> VK_PAIR then begin eval_error := true; exit end;
          eval_expr := av^.head; exit end;
        if names_equal(fv^.noff, fv^.nlen, snd_noff, snd_nlen) then begin
          if av^.vk <> VK_PAIR then begin eval_error := true; exit end;
          eval_expr := av^.tail; exit end;
        if names_equal(fv^.noff, fv^.nlen, some_noff, some_nlen) then begin
          eval_expr := mk_val_some(av); exit end;
        if names_equal(fv^.noff, fv^.nlen, result_bind_noff, result_bind_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(result_bind_noff, result_bind_nlen, 1, av, nil); exit end;
          cur_field := fv^.head;
          if cur_field^.vk <> VK_CTOR then begin eval_error := true; exit end;
          if cur_field^.ival = ok_ctor_tag then begin
            eval_expr := apply_val(av, cur_field^.head); exit end;
          if cur_field^.ival = error_ctor_tag then begin
            eval_expr := cur_field; exit end;
          eval_error := true; exit end;
        if names_equal(fv^.noff, fv^.nlen, print_endline_noff, print_endline_nlen) then begin
          if av^.vk <> VK_STRING then begin eval_error := true; exit end;
          a := 0;
          while a < av^.nlen do begin write(string_pool[av^.noff + a]); a := a + 1 end;
          crlf;
          eval_expr := mk_val_unit;
          exit
        end;
        if names_equal(fv^.noff, fv^.nlen, string_length_noff, string_length_nlen) then begin
          if av^.vk <> VK_STRING then begin eval_error := true; exit end;
          eval_expr := mk_val_int(av^.nlen); exit end;
        if names_equal(fv^.noff, fv^.nlen, char_code_noff, char_code_nlen) then begin
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          eval_expr := mk_val_int(av^.ival); exit end;
        if names_equal(fv^.noff, fv^.nlen, char_chr_noff, char_chr_nlen) then begin
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          if (av^.ival < 0) or (av^.ival > 255) then begin eval_error := true; exit end;
          eval_expr := mk_val_int(av^.ival); exit end;
        if names_equal(fv^.noff, fv^.nlen, string_of_int_noff, string_of_int_nlen) then begin
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          eval_expr := string_of_int_impl(av^.ival); exit end;
        if names_equal(fv^.noff, fv^.nlen, int_of_string_noff, int_of_string_nlen) then begin
          if av^.vk <> VK_STRING then begin eval_error := true; exit end;
          eval_expr := int_of_string_impl(av); exit end;
        if names_equal(fv^.noff, fv^.nlen, peek_noff, peek_nlen) then begin
          { peek addr — read one byte from absolute SRAM address.
            Returns int 0..255. Used for memory-loaded source fixtures
            (e.g. cor24-run --load-binary src@0x080000 + a patched
            pointer cell). }
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          eval_expr := mk_val_int(peek(av^.ival)); exit
        end;
        if names_equal(fv^.noff, fv^.nlen, poke_noff, poke_nlen) then begin
          { poke addr byte — write one byte to absolute SRAM address.
            Two-stage curry: first call carries addr, second writes byte
            and returns unit. }
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(poke_noff, poke_nlen, 1, av, nil); exit
          end;
          rec_head := fv^.head;
          poke(rec_head^.ival, av^.ival);
          eval_expr := mk_val_unit; exit
        end;
        if names_equal(fv^.noff, fv^.nlen, string_make_noff, string_make_nlen) then begin
          { String.make n c — n copies of byte c (chars are ints in this
            subset). Two-stage curry: first call carries n, second
            constructs the string in string_pool. }
          if av^.vk <> VK_INT then begin eval_error := true; exit end;
          if fv^.ival = 0 then begin
            if av^.ival < 0 then begin eval_error := true; exit end;
            eval_expr := mk_partial(string_make_noff, string_make_nlen, 1, av, nil); exit
          end;
          if (av^.ival < 0) or (av^.ival > 255) then begin eval_error := true; exit end;
          rec_head := fv^.head;
          a := rec_head^.ival; b := av^.ival;
          if string_pool_len + a > 16383 then begin eval_error := true; exit end;
          res := string_pool_len;
          while string_pool_len - res < a do begin
            string_pool[string_pool_len] := chr(b);
            string_pool_len := string_pool_len + 1
          end;
          eval_expr := mk_val_string(res, a); exit
        end;
        if names_equal(fv^.noff, fv^.nlen, list_map_noff, list_map_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(list_map_noff, list_map_nlen, 1, av, nil); exit end;
          eval_expr := list_map_impl(fv^.head, av); exit end;
        if names_equal(fv^.noff, fv^.nlen, list_filter_noff, list_filter_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(list_filter_noff, list_filter_nlen, 1, av, nil); exit end;
          eval_expr := list_filter_impl(fv^.head, av); exit end;
        if names_equal(fv^.noff, fv^.nlen, list_iter_noff, list_iter_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(list_iter_noff, list_iter_nlen, 1, av, nil); exit end;
          eval_expr := list_iter_impl(fv^.head, av); exit end;
        if names_equal(fv^.noff, fv^.nlen, list_find_noff, list_find_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(list_find_noff, list_find_nlen, 1, av, nil); exit end;
          eval_expr := list_find_impl(fv^.head, av); exit end;
        if names_equal(fv^.noff, fv^.nlen, list_fold_noff, list_fold_nlen) then begin
          if fv^.ival = 0 then begin
            eval_expr := mk_partial(list_fold_noff, list_fold_nlen, 1, av, nil); exit end;
          if fv^.ival = 1 then begin
            eval_expr := mk_partial(list_fold_noff, list_fold_nlen, 2, fv^.head, av); exit end;
          eval_expr := list_fold_impl(fv^.head, fv^.tail, av); exit end;
        a := ctor_lookup(fv^.noff, fv^.nlen);
        if a >= 0 then begin
          if ctor_arity[a] = 1 then begin eval_expr := mk_val_ctor_arg(a, av); exit end;
          eval_error := true; exit
        end;
        eval_error := true; exit end;
    bd := fv^.body; ce := fv^.cenv;
    ne := env_extend(ce, fv^.noff, fv^.nlen, av);
    e := bd; env := ne end
  else begin eval_error := true; exit end
  end  { while true }
end;

function eval_toplevel_decl(e: PExpr; env: PEnv): PEnv;
var lv, rv: PVal; ne: PEnv; dir_expr: PExpr; top_pat: PPat; qoff, qlen, i: integer;
begin
  eval_toplevel_decl := env;
  if e = nil then begin eval_error := true; exit end;
  if e^.kind = EK_TYPEDECL then exit;
  if (e^.kind <> EK_LET) or (e^.right <> nil) then begin eval_error := true; exit end;

  if names_equal(e^.noff, e^.nlen, module_directive_noff, module_directive_nlen) then begin
    dir_expr := e^.left;
    if dir_expr = nil then begin eval_error := true; exit end;
    if dir_expr^.kind <> EK_STRING then begin eval_error := true; exit end;
    current_module_len := 0;
    i := 0;
    while (i < dir_expr^.nlen) and (current_module_len < 64) do begin
      current_module[current_module_len] := string_pool[dir_expr^.noff + i];
      current_module_len := current_module_len + 1;
      i := i + 1
    end;
    eval_toplevel_decl := env_strip_unqualified(env);
    exit
  end;

  if e^.ival = 1 then begin
    lv := mk_val_closure(0, 0, nil, nil);
    if current_module_len > 0 then begin
      qoff := qualified_name(e^.noff, e^.nlen);
      qlen := current_module_len + 1 + e^.nlen;
      ne := env_extend(env, qoff, qlen, lv);
      ne := env_extend(ne, e^.noff, e^.nlen, lv)
    end else
      ne := env_extend(env, e^.noff, e^.nlen, lv);
    { let rec ... and ... at top-level — install every placeholder before
      any body runs, so cross-references resolve. Each binding gets both
      qualified and unqualified names when in a module. }
    dir_expr := e^.extra;
    while dir_expr <> nil do begin
      rv := mk_val_closure(0, 0, nil, nil);
      if current_module_len > 0 then begin
        qoff := qualified_name(dir_expr^.noff, dir_expr^.nlen);
        qlen := current_module_len + 1 + dir_expr^.nlen;
        ne := env_extend(ne, qoff, qlen, rv);
        ne := env_extend(ne, dir_expr^.noff, dir_expr^.nlen, rv)
      end else
        ne := env_extend(ne, dir_expr^.noff, dir_expr^.nlen, rv);
      dir_expr := dir_expr^.extra
    end;
    rv := eval_expr(e^.left, ne);
    if eval_error then exit;
    lv^.vk := rv^.vk; lv^.ival := rv^.ival; lv^.noff := rv^.noff; lv^.nlen := rv^.nlen;
    lv^.body := rv^.body; lv^.cenv := ne;
    dir_expr := e^.extra;
    while dir_expr <> nil do begin
      lv := env_lookup(ne, dir_expr^.noff, dir_expr^.nlen);
      if eval_error then exit;
      rv := eval_expr(dir_expr^.left, ne);
      if eval_error then exit;
      lv^.vk := rv^.vk; lv^.ival := rv^.ival; lv^.noff := rv^.noff; lv^.nlen := rv^.nlen;
      lv^.body := rv^.body; lv^.cenv := ne;
      dir_expr := dir_expr^.extra
    end;
    eval_toplevel_decl := ne;
    exit
  end;

  lv := eval_expr(e^.left, env);
  if eval_error then exit;
  if e^.pat <> nil then begin
    top_pat := e^.pat;
    if top_pat^.pk <> PK_VAR then begin
      ne := try_match(top_pat, lv, env);
      if not match_success then begin eval_error := true; exit end;
      eval_toplevel_decl := ne;
      exit
    end
  end;
  if current_module_len > 0 then begin
    qoff := qualified_name(e^.noff, e^.nlen);
    qlen := current_module_len + 1 + e^.nlen;
    ne := env_extend(env, qoff, qlen, lv);
    eval_toplevel_decl := env_extend(ne, e^.noff, e^.nlen, lv)
  end else
    eval_toplevel_decl := env_extend(env, e^.noff, e^.nlen, lv)
end;

{ === Value pretty-printer === }

procedure print_value(v: PVal); forward;

procedure print_value(v: PVal);
var cur: PVal; i: integer;
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
  if v^.vk = VK_PAIR then begin
    write('(');
    print_value(v^.head);
    write(', ');
    print_value(v^.tail);
    write(')');
    exit
  end;
  if v^.vk = VK_STRING then begin
    write('"');
    i := 0;
    while i < v^.nlen do begin
      write(string_pool[v^.noff + i]);
      i := i + 1
    end;
    write('"');
    exit
  end;
  if v^.vk = VK_NONE then begin write('None'); exit end;
  if v^.vk = VK_SOME then begin
    write('Some ');
    print_value(v^.head);
    exit
  end;
  if v^.vk = VK_CTOR then begin
    i := 0;
    while i < ctor_names_len[v^.ival] do begin
      write(name_pool[ctor_names_off[v^.ival]+i]); i := i+1 end;
    if v^.head <> nil then begin
      write(' ');
      print_value(v^.head)
    end;
    exit end;
  if v^.vk = VK_REF then begin write('<ref>'); exit end;
  if v^.vk = VK_RECORD then begin write('<record>'); exit end;
  if v^.vk = VK_CLOSURE then begin write('<fun>'); exit end;
  write('<?>')
end;

{ === Main: REPL loop === }
begin
  name_pool_len := 0;
  string_pool_len := 0;
  ctor_count := 0;
  expr_alloc_head := nil; pat_alloc_head := nil;
  val_alloc_head := nil; env_alloc_head := nil;
  intern_print_int;
  intern_board;
  intern_wildcard;
  intern_nil;
  intern_list_ops;
  intern_list_module;
  intern_list_hof;
  intern_string_conv;
  intern_pair_ops;
  intern_option;
  intern_fn_arg;
  intern_string_ops;
  intern_module_directive;
  intern_char_ops;
  exit_requested := false;
  current_module_len := 0;
  top_env := nil;
  while (not eof) and (not exit_requested) do begin
    { Print prompt: "> " }
    putc_ch := '>'; write(putc_ch);
    putc_ch := ' '; write(putc_ch);
    lex_init;
    if src_len > 0 then begin
      parse_error := false;
      eval_error := false;
      top_let_allowed := true;
      lex_next;
      ast := parse_seq;
      if parse_error then begin write('PARSE ERROR'); crlf end
      else begin
        if ((ast^.kind = EK_LET) and (ast^.right = nil)) or (ast^.kind = EK_TYPEDECL) then begin
          top_env := eval_toplevel_decl(ast, top_env);
          result := mk_val_unit
        end else
          result := eval_expr(ast, top_env);
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
