{ oc_eval.pas -- Tree-walk evaluator for OCaml subset

  Requires: oc_ast.pas, oc_value.pas, name_pool globals
  Provides: function eval_expr(e: PExpr; env: PEnv): PVal
}

var
  eval_error: boolean;

function names_equal(off1, len1, off2, len2: integer): boolean;
var j: integer; eq: boolean;
begin
  names_equal := false;
  if len1 <> len2 then exit;
  eq := true;
  j := 0;
  while (j < len1) and eq do
  begin
    if name_pool[off1 + j] <> name_pool[off2 + j] then eq := false;
    j := j + 1
  end;
  names_equal := eq
end;

function env_lookup(env: PEnv; noff, nlen: integer): PVal;
var cur: PEnv;
begin
  env_lookup := nil;
  cur := env;
  while cur <> nil do
  begin
    if names_equal(cur^.noff, cur^.nlen, noff, nlen) then
    begin
      env_lookup := cur^.val;
      exit
    end;
    cur := cur^.next
  end;
  eval_error := true
end;

function env_extend(env: PEnv; noff, nlen: integer; v: PVal): PEnv;
var e: PEnv;
begin
  new(e);
  e^.noff := noff;
  e^.nlen := nlen;
  e^.val := v;
  e^.next := env;
  env_extend := e
end;

function mk_val_int(v: integer): PVal;
var p: PVal;
begin
  new(p); p^.vk := VK_INT; p^.ival := v;
  p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.env := nil;
  mk_val_int := p
end;

function mk_val_bool(v: integer): PVal;
var p: PVal;
begin
  new(p); p^.vk := VK_BOOL; p^.ival := v;
  p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.env := nil;
  mk_val_bool := p
end;

function mk_val_closure(noff, nlen: integer; body: PExpr; env: PEnv): PVal;
var p: PVal;
begin
  new(p); p^.vk := VK_CLOSURE; p^.ival := 0;
  p^.noff := noff; p^.nlen := nlen; p^.body := body; p^.env := env;
  mk_val_closure := p
end;

function mk_val_unit: PVal;
var p: PVal;
begin
  new(p); p^.vk := VK_UNIT; p^.ival := 0;
  p^.noff := 0; p^.nlen := 0; p^.body := nil; p^.env := nil;
  mk_val_unit := p
end;

{ print_int built-in name: interned at startup }
var
  print_int_noff: integer;
  print_int_nlen: integer;

procedure intern_print_int;
{ Intern the name "print_int" into the name pool }
begin
  print_int_noff := name_pool_len;
  name_pool[name_pool_len] := 'p'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 'r'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := '_'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 'i'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 'n'; name_pool_len := name_pool_len + 1;
  name_pool[name_pool_len] := 't'; name_pool_len := name_pool_len + 1;
  print_int_nlen := 9
end;

function eval_expr(e: PExpr; env: PEnv): PVal; forward;

function eval_expr(e: PExpr; env: PEnv): PVal;
var lv, rv, fv, av: PVal;
    l, r, x, body_node: PExpr;
    new_env, closure_env: PEnv;
    a, b, res: integer;
begin
  eval_expr := nil;
  if e = nil then begin eval_error := true; exit end;

  if e^.kind = EK_INT then
  begin eval_expr := mk_val_int(e^.ival); exit end;

  if e^.kind = EK_BOOL then
  begin eval_expr := mk_val_bool(e^.ival); exit end;

  if e^.kind = EK_VAR then
  begin
    { Check for print_int built-in }
    if names_equal(e^.noff, e^.nlen, print_int_noff, print_int_nlen) then
    begin
      { Return a special closure-like value; handled at application }
      eval_expr := mk_val_int(-1);
      eval_expr^.vk := VK_CLOSURE;
      eval_expr^.noff := print_int_noff;
      eval_expr^.nlen := print_int_nlen;
      eval_expr^.body := nil;
      exit
    end;
    eval_expr := env_lookup(env, e^.noff, e^.nlen);
    exit
  end;

  if e^.kind = EK_BINOP then
  begin
    l := e^.left; r := e^.right;
    lv := eval_expr(l, env);
    rv := eval_expr(r, env);
    if eval_error then exit;
    a := lv^.ival; b := rv^.ival;
    res := 0;
    if e^.op = OP_ADD then res := a + b
    else if e^.op = OP_SUB then res := a - b
    else if e^.op = OP_MUL then res := a * b
    else if e^.op = OP_DIV then begin
      if b = 0 then begin eval_error := true; exit end;
      res := a div b
    end
    else if e^.op = OP_MOD then begin
      if b = 0 then begin eval_error := true; exit end;
      res := a mod b
    end
    else if e^.op = OP_EQ then begin if a = b then res := 1 else res := 0 end
    else if e^.op = OP_NEQ then begin if a <> b then res := 1 else res := 0 end
    else if e^.op = OP_LT then begin if a < b then res := 1 else res := 0 end
    else if e^.op = OP_GT then begin if a > b then res := 1 else res := 0 end
    else if e^.op = OP_LE then begin if a <= b then res := 1 else res := 0 end
    else if e^.op = OP_GE then begin if a >= b then res := 1 else res := 0 end
    else if e^.op = OP_AND then begin if (a <> 0) and (b <> 0) then res := 1 else res := 0 end
    else if e^.op = OP_OR then begin if (a <> 0) or (b <> 0) then res := 1 else res := 0 end;
    { comparison/logic ops return bool, arithmetic returns int }
    if (e^.op >= OP_EQ) and (e^.op <= OP_OR) then
      eval_expr := mk_val_bool(res)
    else
      eval_expr := mk_val_int(res);
    exit
  end;

  if e^.kind = EK_UNARY then
  begin
    l := e^.left;
    lv := eval_expr(l, env);
    if eval_error then exit;
    if e^.op = OP_NOT then
    begin
      if lv^.ival = 0 then eval_expr := mk_val_bool(1)
      else eval_expr := mk_val_bool(0)
    end;
    exit
  end;

  if e^.kind = EK_IF then
  begin
    l := e^.left;
    lv := eval_expr(l, env);
    if eval_error then exit;
    if lv^.ival <> 0 then
    begin r := e^.right; eval_expr := eval_expr(r, env) end
    else
    begin x := e^.extra; eval_expr := eval_expr(x, env) end;
    exit
  end;

  if e^.kind = EK_LET then
  begin
    l := e^.left;
    if e^.ival = 1 then
    begin
      { let rec: create closure that can reference itself }
      lv := mk_val_closure(0, 0, nil, nil);
      new_env := env_extend(env, e^.noff, e^.nlen, lv);
      rv := eval_expr(l, new_env);
      if eval_error then exit;
      { Patch the placeholder with the real value }
      lv^.vk := rv^.vk;
      lv^.ival := rv^.ival;
      lv^.noff := rv^.noff;
      lv^.nlen := rv^.nlen;
      lv^.body := rv^.body;
      { For recursive closure, point env back to new_env }
      lv^.env := new_env
    end
    else
    begin
      lv := eval_expr(l, env);
      if eval_error then exit;
      new_env := env_extend(env, e^.noff, e^.nlen, lv)
    end;
    r := e^.right;
    eval_expr := eval_expr(r, new_env);
    exit
  end;

  if e^.kind = EK_FUN then
  begin
    eval_expr := mk_val_closure(e^.noff, e^.nlen, e^.left, env);
    exit
  end;

  if e^.kind = EK_APP then
  begin
    l := e^.left;
    fv := eval_expr(l, env);
    if eval_error then exit;
    r := e^.right;
    av := eval_expr(r, env);
    if eval_error then exit;
    if fv^.vk = VK_CLOSURE then
    begin
      if fv^.body = nil then
      begin
        { Built-in: print_int }
        if names_equal(fv^.noff, fv^.nlen, print_int_noff, print_int_nlen) then
        begin
          writeln(av^.ival);
          eval_expr := mk_val_unit;
          exit
        end;
        eval_error := true; exit
      end;
      body_node := fv^.body;
      closure_env := fv^.env;
      new_env := env_extend(closure_env, fv^.noff, fv^.nlen, av);
      eval_expr := eval_expr(body_node, new_env);
      exit
    end;
    eval_error := true;
    exit
  end;

  eval_error := true
end;
