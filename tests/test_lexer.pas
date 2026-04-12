program TestLexer;
{ Test harness for the OCaml lexer.
  Reads OCaml source from stdin, tokenizes it, prints each token.
  Format: token_kind_number value
  Token kinds printed as integers to avoid string literal limit. }

const
  TK_EOF    = 0;
  TK_INT    = 1;
  TK_IDENT  = 2;
  TK_LET    = 10;
  TK_REC    = 11;
  TK_IN     = 12;
  TK_IF     = 13;
  TK_THEN   = 14;
  TK_ELSE   = 15;
  TK_FUN    = 16;
  TK_TRUE   = 17;
  TK_FALSE  = 18;
  TK_NOT    = 19;
  TK_MOD    = 20;
  TK_PLUS   = 30;
  TK_MINUS  = 31;
  TK_STAR   = 32;
  TK_SLASH  = 33;
  TK_EQ     = 34;
  TK_NEQ    = 35;
  TK_LT     = 36;
  TK_GT     = 37;
  TK_LE     = 38;
  TK_GE     = 39;
  TK_ANDAND = 40;
  TK_OROR   = 41;
  TK_ARROW  = 42;
  TK_LPAREN = 50;
  TK_RPAREN = 51;
  TK_SEMI   = 52;
  TK_ERROR  = 99;
  SRC_MAX   = 4095;
  ID_MAX    = 63;

var
  tok: integer;
  tok_int: integer;
  tok_id: array[0..63] of char;
  tok_id_len: integer;
  src: array[0..4095] of char;
  src_len: integer;
  pos: integer;
  i: integer;
  ch: char;

function is_digit(c: char): boolean;
begin
  is_digit := (c >= '0') and (c <= '9')
end;

function is_alpha(c: char): boolean;
begin
  is_alpha := ((c >= 'a') and (c <= 'z'))
           or ((c >= 'A') and (c <= 'Z'))
           or (c = '_')
end;

function is_alnum(c: char): boolean;
begin
  is_alnum := is_digit(c) or is_alpha(c) or (c = chr(39))
end;

function is_space(c: char): boolean;
begin
  is_space := (c = ' ') or (c = chr(9))
           or (c = chr(10)) or (c = chr(13))
end;

procedure skip_whitespace;
begin
  while (pos < src_len) and is_space(src[pos]) do
    pos := pos + 1
end;

function skip_comment: boolean;
var
  depth: integer;
begin
  skip_comment := false;
  if (pos + 1 < src_len) and (src[pos] = '(') and (src[pos + 1] = '*') then
  begin
    pos := pos + 2;
    depth := 1;
    while (pos + 1 < src_len) and (depth > 0) do
    begin
      if (src[pos] = '(') and (src[pos + 1] = '*') then
      begin
        depth := depth + 1;
        pos := pos + 2
      end
      else if (src[pos] = '*') and (src[pos + 1] = ')') then
      begin
        depth := depth - 1;
        pos := pos + 2
      end
      else
        pos := pos + 1
    end;
    skip_comment := true
  end
end;

procedure skip_ws_and_comments;
var
  moved: boolean;
begin
  repeat
    moved := false;
    skip_whitespace;
    if skip_comment then
      moved := true
  until not moved
end;

function classify_ident: integer;
begin
  classify_ident := TK_IDENT;
  if tok_id_len = 2 then
  begin
    if (tok_id[0] = 'i') and (tok_id[1] = 'f') then
      classify_ident := TK_IF
    else if (tok_id[0] = 'i') and (tok_id[1] = 'n') then
      classify_ident := TK_IN
  end
  else if tok_id_len = 3 then
  begin
    if (tok_id[0] = 'l') and (tok_id[1] = 'e') and (tok_id[2] = 't') then
      classify_ident := TK_LET
    else if (tok_id[0] = 'r') and (tok_id[1] = 'e') and (tok_id[2] = 'c') then
      classify_ident := TK_REC
    else if (tok_id[0] = 'f') and (tok_id[1] = 'u') and (tok_id[2] = 'n') then
      classify_ident := TK_FUN
    else if (tok_id[0] = 'n') and (tok_id[1] = 'o') and (tok_id[2] = 't') then
      classify_ident := TK_NOT
    else if (tok_id[0] = 'm') and (tok_id[1] = 'o') and (tok_id[2] = 'd') then
      classify_ident := TK_MOD
  end
  else if tok_id_len = 4 then
  begin
    if (tok_id[0] = 't') and (tok_id[1] = 'h') and (tok_id[2] = 'e')
       and (tok_id[3] = 'n') then
      classify_ident := TK_THEN
    else if (tok_id[0] = 'e') and (tok_id[1] = 'l') and (tok_id[2] = 's')
       and (tok_id[3] = 'e') then
      classify_ident := TK_ELSE
    else if (tok_id[0] = 't') and (tok_id[1] = 'r') and (tok_id[2] = 'u')
       and (tok_id[3] = 'e') then
      classify_ident := TK_TRUE
  end
  else if tok_id_len = 5 then
  begin
    if (tok_id[0] = 'f') and (tok_id[1] = 'a') and (tok_id[2] = 'l')
       and (tok_id[3] = 's') and (tok_id[4] = 'e') then
      classify_ident := TK_FALSE
  end
end;

procedure lex_init;
begin
  src_len := 0;
  pos := 0;
  tok := TK_EOF;
  tok_int := 0;
  tok_id_len := 0;
  while not eof do
  begin
    read(ch);
    if ch <> chr(4) then
    begin
      if src_len < SRC_MAX then
      begin
        src[src_len] := ch;
        src_len := src_len + 1
      end
    end
  end
end;

procedure lex_next;
var
  c: char;
  done: boolean;
begin
  skip_ws_and_comments;

  if pos >= src_len then
  begin
    tok := TK_EOF;
    done := true
  end
  else
    done := false;

  if not done then
  begin
    c := src[pos];
    if is_digit(c) then
    begin
      tok := TK_INT;
      tok_int := 0;
      while (pos < src_len) and is_digit(src[pos]) do
      begin
        tok_int := tok_int * 10 + (ord(src[pos]) - ord('0'));
        pos := pos + 1
      end;
      done := true
    end
  end;

  if not done then
  begin
    c := src[pos];
    if is_alpha(c) then
    begin
      tok_id_len := 0;
      while (pos < src_len) and is_alnum(src[pos]) do
      begin
        if tok_id_len < ID_MAX then
        begin
          tok_id[tok_id_len] := src[pos];
          tok_id_len := tok_id_len + 1
        end;
        pos := pos + 1
      end;
      tok := classify_ident;
      done := true
    end
  end;

  if not done then
  begin
    c := src[pos];
    if c = '+' then
    begin tok := TK_PLUS; pos := pos + 1; done := true end
    else if c = '*' then
    begin tok := TK_STAR; pos := pos + 1; done := true end
    else if c = '/' then
    begin tok := TK_SLASH; pos := pos + 1; done := true end
    else if c = '(' then
    begin tok := TK_LPAREN; pos := pos + 1; done := true end
    else if c = ')' then
    begin tok := TK_RPAREN; pos := pos + 1; done := true end
    else if c = ';' then
    begin tok := TK_SEMI; pos := pos + 1; done := true end
    else if c = '-' then
    begin
      pos := pos + 1;
      if (pos < src_len) and (src[pos] = '>') then
      begin tok := TK_ARROW; pos := pos + 1 end
      else
        tok := TK_MINUS;
      done := true
    end
    else if c = '=' then
    begin tok := TK_EQ; pos := pos + 1; done := true end
    else if c = '<' then
    begin
      pos := pos + 1;
      if (pos < src_len) and (src[pos] = '>') then
      begin tok := TK_NEQ; pos := pos + 1 end
      else if (pos < src_len) and (src[pos] = '=') then
      begin tok := TK_LE; pos := pos + 1 end
      else
        tok := TK_LT;
      done := true
    end
    else if c = '>' then
    begin
      pos := pos + 1;
      if (pos < src_len) and (src[pos] = '=') then
      begin tok := TK_GE; pos := pos + 1 end
      else
        tok := TK_GT;
      done := true
    end
    else if c = '&' then
    begin
      pos := pos + 1;
      if (pos < src_len) and (src[pos] = '&') then
      begin tok := TK_ANDAND; pos := pos + 1 end
      else
        tok := TK_ERROR;
      done := true
    end
    else if c = '|' then
    begin
      pos := pos + 1;
      if (pos < src_len) and (src[pos] = '|') then
      begin tok := TK_OROR; pos := pos + 1 end
      else
        tok := TK_ERROR;
      done := true
    end
    else
    begin
      tok := TK_ERROR;
      pos := pos + 1;
      done := true
    end
  end
end;

procedure print_tok_id;
begin
  i := 0;
  while i < tok_id_len do
  begin
    write(tok_id[i]);
    i := i + 1
  end
end;

begin
  lex_init;
  lex_next;
  while tok <> TK_EOF do
  begin
    write(tok);
    if tok = TK_INT then
    begin
      write(' ');
      writeln(tok_int)
    end
    else if (tok = TK_IDENT) or ((tok >= TK_LET) and (tok <= TK_MOD)) then
    begin
      write(' ');
      print_tok_id;
      writeln
    end
    else
      writeln;
    lex_next
  end;
  writeln(0)
end.
