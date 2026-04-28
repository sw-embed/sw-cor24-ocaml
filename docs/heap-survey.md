# OCaml runtime heap-allocation survey

Catalog of every `new(...)` site in the OCaml host sources, the Pascal record
type each one allocates, the logical runtime kind it represents, and the
pointer fields it carries. Produced for saga `ocaml-heap-reclaim`,
step 002 — the typed-allocator + mark/sweep work that follows uses this as
its worklist and as the field map for the marker.

## Build path scope

Only `src/ocaml.pas` is compiled into `build/ocaml.p24m` (see
`scripts/build.sh`). The interpreter image that traps in issue #28 is built
exclusively from that file. The other Pascal sources under `src/`
(`oc_ast.pas`, `oc_eval.pas`, `oc_lex.pas`, `oc_parse.pas`, `oc_value.pas`)
are smaller modules used by `tests/test_*.pas`, not by the production
interpreter, and are out of scope for the GC work targeting #28.

For completeness, `src/oc_eval.pas` has 5 `new()` sites of its own (lines
45, 56, 64, 72, 80) covering a simpler Val record. They are noted but not
acted on by this saga.

## Pascal record types (production)

All four record types are defined at `src/ocaml.pas:42-68`:

```
type
  PPat = ^Pat;
  PExpr = ^Expr;
  Expr = record
    kind: integer; ival: integer; op: integer;
    noff: integer; nlen: integer;
    left: PExpr; right: PExpr; extra: PExpr;
    pat: PPat
  end;
  Pat = record
    pk: integer;
    ival: integer;
    noff: integer; nlen: integer;
    sub1: PPat; sub2: PPat
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
```

Pointer fields per record type — these are exactly the edges the mark
phase will follow:

| Record    | Pointer fields                              |
|-----------|---------------------------------------------|
| Expr      | `left: PExpr`, `right: PExpr`, `extra: PExpr`, `pat: PPat` |
| Pat       | `sub1: PPat`, `sub2: PPat`                  |
| Val       | `body: PExpr`, `cenv: PEnv`, `head: PVal`, `tail: PVal`    |
| EnvEntry  | `val: PVal`, `next: PEnv`                   |

Note that `Val.body` points into `Expr` and `Val.cenv` points into
`EnvEntry`. Cross-type edges mean the marker can't sweep one type in
isolation — it has to traverse the full graph from roots before sweeping
any kind.

## Allocation sites — by Pascal type

### Expr nodes (16 sites, 16 logical kinds)

| Line | Helper / context              | Kind             | Pointer fields populated   |
|------|-------------------------------|------------------|-----------------------------|
| 336  | `mk_int`                      | EK_INT           | (none)                      |
| 340  | `mk_nil`                      | EK_NIL           | (none)                      |
| 344  | `mk_string`                   | EK_STRING        | (none, name-pool refs by offset) |
| 348  | `mk_bool`                     | EK_BOOL          | (none)                      |
| 352  | `mk_var`                      | EK_VAR           | (none, name-pool refs)      |
| 357  | `mk_binop`                    | EK_BINOP         | `left`, `right`             |
| 361  | `mk_unary`                    | EK_UNARY         | `left`                      |
| 365  | `mk_if`                       | EK_IF            | `left=cond`, `right=then`, `extra=else` |
| 369  | `mk_let`                      | EK_LET           | `left=value`, `right=body`  |
| 373  | `mk_fun`                      | EK_FUN           | `left=body`                 |
| 377  | `mk_app`                      | EK_APP           | `left=func`, `right=arg`    |
| 381  | `mk_match`                    | EK_MATCH         | `left=scrutinee`, `right=arms` |
| 385  | `mk_match_arm`                | EK_MATCH_ARM     | `pat=pattern`, `left=guard`, `right=body`, `extra=next-arm` |
| 389  | `mk_var_qualified`            | EK_VAR           | (none, qualified name in pool) |
| 552  | inline in `parse_atom` (record/field access chain) | EK_FIELD | `left=record-expr` |
| 571  | inline in `parse_atom` (record literal head/tail loop) | EK_RECORD | `left=value-expr`, `right=next-field-expr` |

### Pat nodes (11 sites, 11 logical kinds)

| Line | Helper / context              | Kind             | Pointer fields populated |
|------|-------------------------------|------------------|---------------------------|
| 422  | `mk_pat_wildcard`             | PK_WILDCARD      | (none)                    |
| 425  | `mk_pat_int`                  | PK_INT           | (none)                    |
| 428  | `mk_pat_bool`                 | PK_BOOL          | (none)                    |
| 431  | `mk_pat_var`                  | PK_VAR           | (none)                    |
| 434  | `mk_pat_nil`                  | PK_NIL           | (none)                    |
| 437  | `mk_pat_cons`                 | PK_CONS          | `sub1=head`, `sub2=tail`  |
| 440  | `mk_pat_pair`                 | PK_PAIR          | `sub1=fst`, `sub2=snd`    |
| 443  | `mk_pat_none`                 | PK_NONE          | (none)                    |
| 446  | `mk_pat_some`                 | PK_SOME          | `sub1=inner`              |
| 449  | `mk_pat_ctor`                 | PK_CTOR          | `sub1=arg-pat`            |
| 889  | inline in pattern parser      | PK_STRING        | (none, string-pool refs)  |

### Val nodes (16 sites, 14 logical kinds — VK_CLOSURE has 2 sites, VK_CTOR has 2)

The `Val` record is heavily overloaded. The `head`/`tail`/`body`/`cenv`
fields take on different meaning depending on `vk`. The mark phase needs
the per-kind interpretation below; not every field is live for every
kind.

| Line | Helper / context           | Kind         | Live pointer fields |
|------|----------------------------|--------------|----------------------|
| 1162 | `mk_val_int`               | VK_INT       | (none)              |
| 1165 | `mk_val_bool`              | VK_BOOL      | (none)              |
| 1168 | `mk_val_closure`           | VK_CLOSURE   | `body=fn-body`, `cenv=captured-env` |
| 1171 | `mk_val_nil`               | VK_NIL       | (none)              |
| 1174 | `mk_val_cons`              | VK_CONS      | `head=hd`, `tail=tl` |
| 1177 | `mk_val_pair`              | VK_PAIR      | `head=fst`, `tail=snd` |
| 1180 | `mk_val_none`              | VK_NONE      | (none)              |
| 1183 | `mk_val_some`              | VK_SOME      | `head=inner`        |
| 1186 | `mk_val_string`            | VK_STRING    | (none, string-pool refs) |
| 1189 | `mk_val_unit`              | VK_UNIT      | (none)              |
| 1192 | `mk_val_ctor`              | VK_CTOR (no arg) | (none)          |
| 1195 | `mk_val_ctor_arg`          | VK_CTOR (with arg) | `head=arg`    |
| 1830 | `mk_partial`               | VK_CLOSURE (partial-app marker; ival=stage 1\|2) | `head=fn`, `tail=acc` |
| 1854 | inline in `eval_expr` (record literal field-cons) | VK_FIELD | `head=field-value`, `tail=next-field` |
| 1860 | inline in `eval_expr` (record literal record wrapper) | VK_RECORD | `head=first-field` |
| 2160 | inline in `eval_expr` (`ref` builtin) | VK_REF | `head=cell-contents` (mutable) |

### EnvEntry nodes (1 site)

| Line | Helper / context       | Pointer fields                |
|------|------------------------|-------------------------------|
| 1137 | `env_extend`           | `val=binding-value`, `next=outer-env` |

## Per-kind pointer-field map (the marker's reference)

When the mark phase sees a pointer of a given Pascal type, this table
tells it which fields to traverse. For `Val` it must dispatch on `vk`
because most fields are interpreted differently per kind.

```
mark(p: PExpr):
  if marked(p) return
  set marked(p)
  mark(p.left); mark(p.right); mark(p.extra)
  mark_pat(p.pat)

mark_pat(p: PPat):
  if p = nil or marked(p) return
  set marked(p)
  mark_pat(p.sub1); mark_pat(p.sub2)

mark_env(p: PEnv):
  if p = nil or marked(p) return
  set marked(p)
  mark_val(p.val); mark_env(p.next)

mark_val(p: PVal):
  if p = nil or marked(p) return
  set marked(p)
  case p.vk of
    VK_CLOSURE:                       # both regular and mk_partial
      mark(p.body)                    # nil for partial-app markers
      mark_env(p.cenv)                # nil for partial-app markers
      mark_val(p.head)                # mk_partial: f
      mark_val(p.tail)                # mk_partial: acc
    VK_CONS, VK_PAIR:    mark_val(p.head); mark_val(p.tail)
    VK_SOME:             mark_val(p.head)
    VK_CTOR:             mark_val(p.head)              # head=arg, may be nil
    VK_FIELD:            mark_val(p.head); mark_val(p.tail)  # head=value, tail=next-field
    VK_RECORD:           mark_val(p.head)              # head=first-field
    VK_REF:              mark_val(p.head)              # head=mutable cell
    VK_INT/BOOL/NIL/NONE/STRING/UNIT: pass             # leaf
```

The "set marked before recursing" line above is what guards against
cycles; closures + refs can produce them.

## Non-`new(...)` allocators and other allocation surfaces

Other than the 44 `new(...)` sites, the host has these fixed-capacity
buffers (declared at module-level vars, not heap):

- `name_pool: array[0..16383] of char` (16 KiB, identifier text).
- `string_pool: array[0..16383] of char` (16 KiB, string-literal text).
- `current_module: array[0..63] of char`.
- `tok_id: array[0..63] of char`.
- `src: array[0..4095] of char` (source-input buffer).
- `ctor_names_off`, `ctor_names_len`, `ctor_arity: array[0..63] of integer`.
- `soi_tmp: array[0..31] of char`.

These are static allocations that consume linker space, not p-code heap,
and are not reclaimed because they are append-only (or refilled per
transaction). They are *not* in scope for the GC work — the mark/sweep
collector targets only `Expr`/`Pat`/`Val`/`EnvEntry` heap allocations.

There are **no manual mark/release patterns**, **no custom arenas**, and
**no `dispose()` calls** in `src/ocaml.pas`. Allocation is
strictly `new(...)`-then-leak, which is what produces the monotonic
heap growth that fills `heap_limit` and trips TRAP 5 in the #28 repro.

## Cross-type edges, summarized

```
Expr  --> Expr (left/right/extra), Pat (pat)
Pat   --> Pat (sub1/sub2)
Val   --> Expr (body, closures only), Env (cenv, closures only),
          Val (head/tail per vk)
Env   --> Val (val), Env (next)
```

Key implication for liveness: **a closure pins its body Expr graph and
its captured environment chain alive**. Any environment with a closure
binding therefore keeps that closure's lambda body and the env that
existed at closure-creation time reachable. This is exactly the kind of
retention that the mark phase has to honor — naive "drop AST after eval"
is wrong because closures escape.

## Pascal-runtime `dispose` availability

The lower runtime exposes `sys_free` (sys id 5, pvm.s:3133). Pascal
`dispose(ptr)` lowers to `sys_free`. The collector's sweep step can call
`dispose` on each unmarked object directly. There is no need to add new
runtime support — all of the missing infrastructure lives in the Pascal
host source (`src/ocaml.pas`).

## Worklist for step 003 (`typed-allocators`)

1. Add per-type allocator helpers — `alloc_expr`, `alloc_pat`, `alloc_val`,
   `alloc_env` — each calling `new(...)` and threading the new object
   onto a per-type tracking list. Pascal's record types do not have a
   spare pointer for an intrusive `next_alloc`, so a parallel
   bounded-array tracking table (or an extra field added to each record)
   will be required; pick whichever is cheaper after looking at the
   record sizes the linker emits.
2. Replace each of the 44 `new(...)` sites listed above with a single
   call to the matching allocator. The `mk_*` helpers are the natural
   chokepoints; only the inline allocations in `parse_atom`
   (lines 552, 571, 889) and `eval_expr` (lines 1854, 1860, 2160) need
   in-place edits.
3. Add per-type alloc counters readable from the dump path so step 005
   has a baseline.

After step 003 the interpreter's runtime behavior must be identical:
allocate-and-leak as today, just routed through helpers. The #28 repro
will still trap.
