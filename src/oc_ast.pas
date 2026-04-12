{ oc_ast.pas -- AST node types for OCaml subset

  Nodes are heap-allocated via new(). Names are stored in a
  global name pool; AST nodes reference names by (noff, nlen).

  Node kinds:
    EK_INT    - integer literal: ival
    EK_BOOL   - boolean literal: ival (0=false, 1=true)
    EK_VAR    - variable: noff, nlen
    EK_BINOP  - binary op: op, left, right
    EK_UNARY  - unary op: op, left
    EK_IF     - conditional: left=cond, right=then, extra=else
    EK_LET    - let binding: noff, nlen, ival=1 if rec, left=value, right=body
    EK_FUN    - function: noff, nlen (param), left=body
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

  OP_ADD = 30; OP_SUB = 31; OP_MUL = 32; OP_DIV = 33; OP_MOD = 20;
  OP_EQ = 34; OP_NEQ = 35; OP_LT = 36; OP_GT = 37;
  OP_LE = 38; OP_GE = 39; OP_AND = 40; OP_OR = 41; OP_NOT = 19;

  NAME_POOL_MAX = 2048;

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
