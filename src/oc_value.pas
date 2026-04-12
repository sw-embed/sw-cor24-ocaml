{ oc_value.pas -- Runtime value types for OCaml subset

  Values are heap-allocated tagged records.
  VK_INT      - integer value
  VK_BOOL     - boolean value (ival: 0=false, 1=true)
  VK_CLOSURE  - function closure (param name via noff/nlen, body AST, captured env)
  VK_UNIT     - unit value ()
}

const
  VK_INT     = 1;
  VK_BOOL    = 2;
  VK_CLOSURE = 3;
  VK_UNIT    = 4;

type
  PEnv = ^EnvEntry;
  PVal = ^Val;

  Val = record
    vk: integer;
    ival: integer;
    noff: integer;
    nlen: integer;
    body: PExpr;
    env: PEnv
  end;

  EnvEntry = record
    noff: integer;
    nlen: integer;
    val: PVal;
    next: PEnv
  end;
