{ oc_lex.pas -- OCaml subset lexer for COR24

  This file is designed to be included in a main program.
  It provides a tokenizer for the Phase 0 OCaml subset.

  Interface:
    procedure lex_init;       -- call before first use
    procedure lex_next;       -- advance to next token
    Variables:
      tok: integer            -- current token kind (TK_xxx)
      tok_int: integer        -- value if tok = TK_INT
      tok_id: array of char   -- name if tok = TK_IDENT or keyword
      tok_id_len: integer     -- length of tok_id

  Input is read from stdin (UART) into src buffer by lex_init.
  Source terminated by chr(4) (EOT) or physical EOF.
}

const
  { Token kinds }
  TK_EOF    = 0;
  TK_INT    = 1;
  TK_IDENT  = 2;

  { Keywords }
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

  { Operators }
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

  { Delimiters }
  TK_LPAREN = 50;
  TK_RPAREN = 51;
  TK_SEMI   = 52;

  { Error }
  TK_ERROR  = 99;

  { Lexer limits }
  SRC_MAX   = 4095;
  ID_MAX    = 63;

var
  { Current token }
  tok: integer;
  tok_int: integer;
  tok_id: array[0..63] of char;
  tok_id_len: integer;

  { Source buffer }
  src: array[0..4095] of char;
  src_len: integer;
  pos: integer;

{ --- Internal helpers --- }

function src_ch: char;
begin
  if pos < src_len then
    src_ch := src[pos]
  else
    src_ch := chr(0)
end;

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

{ Check if tok_id matches a keyword and return its token kind,
  or TK_IDENT if not a keyword. }
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

{ --- Public interface --- }

procedure lex_init;
var
  ch: char;
begin
  src_len := 0;
  pos := 0;
  tok := TK_EOF;
  tok_int := 0;
  tok_id_len := 0;

  { Read entire input into src buffer }
  while not eof do
  begin
    read(ch);
    if ch = chr(4) then
    begin
      { EOT marker -- stop reading }
    end
    else if src_len < SRC_MAX then
    begin
      src[src_len] := ch;
      src_len := src_len + 1
    end
  end
end;

procedure lex_next;
var
  c: char;
begin
  skip_ws_and_comments;

  if pos >= src_len then
  begin
    tok := TK_EOF;
    exit
  end;

  c := src[pos];

  { Integer literal }
  if is_digit(c) then
  begin
    tok := TK_INT;
    tok_int := 0;
    while (pos < src_len) and is_digit(src[pos]) do
    begin
      tok_int := tok_int * 10 + (ord(src[pos]) - ord('0'));
      pos := pos + 1
    end;
    exit
  end;

  { Identifier or keyword }
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
    exit
  end;

  { Operators and delimiters }
  case c of
    '+': begin tok := TK_PLUS;  pos := pos + 1 end;
    '*': begin tok := TK_STAR;  pos := pos + 1 end;
    '/': begin tok := TK_SLASH; pos := pos + 1 end;
    '(': begin tok := TK_LPAREN; pos := pos + 1 end;
    ')': begin tok := TK_RPAREN; pos := pos + 1 end;
    ';': begin tok := TK_SEMI;  pos := pos + 1 end;
    '-':
      begin
        pos := pos + 1;
        if (pos < src_len) and (src[pos] = '>') then
        begin
          tok := TK_ARROW;
          pos := pos + 1
        end
        else
          tok := TK_MINUS
      end;
    '=':
      begin
        tok := TK_EQ;
        pos := pos + 1
      end;
    '<':
      begin
        pos := pos + 1;
        if (pos < src_len) and (src[pos] = '>') then
        begin
          tok := TK_NEQ;
          pos := pos + 1
        end
        else if (pos < src_len) and (src[pos] = '=') then
        begin
          tok := TK_LE;
          pos := pos + 1
        end
        else
          tok := TK_LT
      end;
    '>':
      begin
        pos := pos + 1;
        if (pos < src_len) and (src[pos] = '=') then
        begin
          tok := TK_GE;
          pos := pos + 1
        end
        else
          tok := TK_GT
      end;
    '&':
      begin
        pos := pos + 1;
        if (pos < src_len) and (src[pos] = '&') then
        begin
          tok := TK_ANDAND;
          pos := pos + 1
        end
        else
        begin
          tok := TK_ERROR;
          pos := pos + 1
        end
      end;
    '|':
      begin
        pos := pos + 1;
        if (pos < src_len) and (src[pos] = '|') then
        begin
          tok := TK_OROR;
          pos := pos + 1
        end
        else
        begin
          tok := TK_ERROR;
          pos := pos + 1
        end
      end
  else
    begin
      tok := TK_ERROR;
      pos := pos + 1
    end
  end
end;
