{ oc_ast.pas -- AST node types for OCaml subset

  Since p24p lacks variant records, we use a tagged record where
  the 'kind' field determines which other fields are meaningful.

  All nodes are heap-allocated via new(). Unused pointer fields
  are nil. Unused integer/char fields are 0.

  Node kinds:
    EK_INT    - integer literal: ival
    EK_BOOL   - boolean literal: ival (0=false, 1=true)
    EK_VAR    - variable: name, name_len
    EK_BINOP  - binary op: op, left, right
    EK_UNARY  - unary op: op, left
    EK_IF     - conditional: left=cond, right=then, extra=else
    EK_LET    - let binding: name, name_len, left=value, right=body
    EK_FUN    - function: name=param, name_len, left=body
    EK_APP    - application: left=func, right=arg
}

const
  EK_INT   = 1;
  EK_BOOL  = 2;
  EK_VAR   = 3;
  EK_BINOP = 4;
  EK_UNARY = 5;
  EK_IF    = 6;
  EK_LET   = 7;
  EK_FUN   = 8;
  EK_APP   = 9;

  { Binary operator codes (reuse token codes for simplicity) }
  OP_ADD = 30;
  OP_SUB = 31;
  OP_MUL = 32;
  OP_DIV = 33;
  OP_MOD = 20;
  OP_EQ  = 34;
  OP_NEQ = 35;
  OP_LT  = 36;
  OP_GT  = 37;
  OP_LE  = 38;
  OP_GE  = 39;
  OP_AND = 40;
  OP_OR  = 41;
  OP_NOT = 19;

type
  PExpr = ^Expr;
  Expr = record
    kind: integer;
    ival: integer;
    op: integer;
    name: array[0..63] of char;
    name_len: integer;
    left: PExpr;
    right: PExpr;
    extra: PExpr
  end;

{ --- AST constructors --- }

function mk_int(v: integer): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_INT;
  n^.ival := v;
  n^.op := 0;
  n^.name_len := 0;
  n^.left := nil;
  n^.right := nil;
  n^.extra := nil;
  mk_int := n
end;

function mk_bool(v: integer): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_BOOL;
  n^.ival := v;
  n^.op := 0;
  n^.name_len := 0;
  n^.left := nil;
  n^.right := nil;
  n^.extra := nil;
  mk_bool := n
end;

function mk_var_node: PExpr;
{ Uses tok_id and tok_id_len from lexer globals }
var n: PExpr;
    j: integer;
begin
  new(n);
  n^.kind := EK_VAR;
  n^.ival := 0;
  n^.op := 0;
  n^.name_len := tok_id_len;
  j := 0;
  while j < tok_id_len do
  begin
    n^.name[j] := tok_id[j];
    j := j + 1
  end;
  n^.left := nil;
  n^.right := nil;
  n^.extra := nil;
  mk_var_node := n
end;

function mk_binop(o: integer; l, r: PExpr): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_BINOP;
  n^.ival := 0;
  n^.op := o;
  n^.name_len := 0;
  n^.left := l;
  n^.right := r;
  n^.extra := nil;
  mk_binop := n
end;

function mk_unary(o: integer; operand: PExpr): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_UNARY;
  n^.ival := 0;
  n^.op := o;
  n^.name_len := 0;
  n^.left := operand;
  n^.right := nil;
  n^.extra := nil;
  mk_unary := n
end;

function mk_if(cond, then_br, else_br: PExpr): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_IF;
  n^.ival := 0;
  n^.op := 0;
  n^.name_len := 0;
  n^.left := cond;
  n^.right := then_br;
  n^.extra := else_br;
  mk_if := n
end;

function mk_let_node(val_e, body_e: PExpr): PExpr;
{ Uses tok_id/tok_id_len captured before parsing val_e }
var n: PExpr;
begin
  new(n);
  n^.kind := EK_LET;
  n^.ival := 0;
  n^.op := 0;
  { name is set by caller via copy_name }
  n^.name_len := 0;
  n^.left := val_e;
  n^.right := body_e;
  n^.extra := nil;
  mk_let_node := n
end;

function mk_fun_node(body_e: PExpr): PExpr;
{ param name set by caller }
var n: PExpr;
begin
  new(n);
  n^.kind := EK_FUN;
  n^.ival := 0;
  n^.op := 0;
  n^.name_len := 0;
  n^.left := body_e;
  n^.right := nil;
  n^.extra := nil;
  mk_fun_node := n
end;

function mk_app(fn, arg: PExpr): PExpr;
var n: PExpr;
begin
  new(n);
  n^.kind := EK_APP;
  n^.ival := 0;
  n^.op := 0;
  n^.name_len := 0;
  n^.left := fn;
  n^.right := arg;
  n^.extra := nil;
  mk_app := n
end;

procedure copy_name(n: PExpr);
{ Copy tok_id/tok_id_len into node's name fields }
var j: integer;
begin
  n^.name_len := tok_id_len;
  j := 0;
  while j < tok_id_len do
  begin
    n^.name[j] := tok_id[j];
    j := j + 1
  end
end;
