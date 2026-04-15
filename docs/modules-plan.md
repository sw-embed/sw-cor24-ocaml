# Modules Plan: Options 1 + 2 (Prelude + Dotted Names)

Minimal module support for the COR24 OCaml interpreter. Defer
user-defined modules, signatures, and functors indefinitely.

## Scope

### In (this plan)

1. **Option 1 -- Prelude built-ins**: hardcode useful functions as
   identifiers recognized by the evaluator, just like `print_int`,
   `hd`, `tl`. Reachable without any module prefix.

2. **Option 2 -- Dotted names as qualified identifiers**: parse
   `List.length` as a single qualified name. Evaluator dispatches
   on the full string. Lets demos use idiomatic names like
   `List.map` without implementing a real module system.

### Out

- `module M = struct ... end` declarations
- `module type S = sig ... end` signatures
- Functors `module Make (X : ORD) = ...`
- `open M` / `open M in expr` / `M.(...)` scoped open
- `include M`
- Nested modules
- Abstract types
- First-class modules

These all require user-visible module environments, which is a
large evaluator change. Not needed for the demo targets.

## Built-in Inventory

Organized by "module" namespace. All dispatched by the name check
in EK_APP, same mechanism as `hd`/`tl`/`is_empty`.

### Global (no prefix)

Already implemented: `print_int`, `putc`, `set_led`, `led_on`,
`led_off`, `switch`, `hd`, `tl`, `is_empty`, `nil`.

Adding this saga: none new. Prelude functions go under `List.`.

### List

All list operations:

```
List.length  : 'a list -> int
List.rev     : 'a list -> 'a list
List.hd      : 'a list -> 'a           (alias of global hd)
List.tl      : 'a list -> 'a list      (alias of global tl)
List.is_empty: 'a list -> bool         (alias of global is_empty)
```

Deferred to after pattern matching (need match to implement
cleanly in OCaml):

```
List.map     : ('a -> 'b) -> 'a list -> 'b list
List.filter  : ('a -> bool) -> 'a list -> 'a list
List.fold_left  : ('a -> 'b -> 'a) -> 'a -> 'b list -> 'a
List.iter    : ('a -> unit) -> 'a list -> unit
```

Higher-order built-ins are possible in Pascal but require
partial-application machinery. Easier once we can write them
in OCaml as prelude code.

### Pair (after pair step)

```
fst          : 'a * 'b -> 'a
snd          : 'a * 'b -> 'b
```

No `Pair.` prefix in real OCaml -- `fst`/`snd` are global.

## Parser Changes

### Dotted names

Extend parse_atom's TK_IDENT case:

```
after reading IDENT into tok_id:
  while next token is TK_DOT and followed by TK_IDENT:
    append '.' and the next ident to tok_id
  mk_var_node now sees the full qualified name
```

New token:
- `TK_DOT` for `.` (when not part of a number)

The lexer currently has no single `.` token. Integers
don't have decimal points in our subset, so `.` is unambiguous
as an identifier-join.

### No other syntax

No `module` keyword, no `struct`, no `sig`, no `:`/`=` for module
defs. The dot is purely syntactic sugar for naming built-ins.

## Evaluator Changes

Just one conceptual change: built-in names can contain `.` now.
The name pool treats them as regular strings; `names_equal`
already works for any length.

Add new intern procedures for:
- `List.length`, `List.rev`, `List.hd`, `List.tl`, `List.is_empty`

Add new EK_VAR branches that return closures for each.

Add new EK_APP dispatch branches that implement each operation.

For `List.length` and `List.rev`, implementation is straightforward
recursion in Pascal -- walk the cons chain.

## Step Plan (new, additive to current saga)

### Now (in phase3-lists-pairs saga, after list-printing)

1. **dotted-names** -- Add TK_DOT and dotted-identifier parsing.
   Test: a variable named `x.y` fails with unbound because it isn't
   defined, but *parses* without error.
2. **list-module-builtins** -- Implement `List.length`, `List.rev`,
   and aliases `List.hd`, `List.tl`, `List.is_empty`. Test each.

### Later (new saga after pattern matching)

3. **prelude** -- Evaluate a prelude string at REPL startup that
   defines common helpers (`map`, `filter`, `fold_left`) in OCaml.
4. **persistent-top-level-env** -- REPL remembers `let x = ... in` bindings
   across lines. Required for prelude to be visible after startup.
5. **higher-order-list-builtins** -- If prelude isn't enough, implement
   `List.map`, `List.filter`, `List.fold_left` in Pascal with
   call-back-into-evaluator machinery.

## Success Criteria

After steps 1-2, this session works:

```
> List.length [1; 2; 3]
3
> List.rev [1; 2; 3]
[3; 2; 1]
> List.hd [42; 99]
42
> List.is_empty []
true
> length [10; 20]   (* also works without prefix -- alias *)
2
```

After full modules plan (later sagas), this works:

```
> List.map (fun x -> x * 2) [1; 2; 3]
[2; 4; 6]
> List.fold_left (fun a b -> a + b) 0 [1; 2; 3; 4]
10
> [1; 2; 3] |> List.map (fun x -> x * x) |> List.fold_left (fun a b -> a + b) 0
14
```

## Why This Order

Pattern matching is the biggest remaining language feature and
unlocks the most demos. But adding `List.length` and dotted names
is small (one parser rule, a few built-ins), provides immediate
visible value (`List.length [1;2;3]` works), and doesn't depend
on match. Doing it first gives a small win while we stage the
bigger match work.

After match lands, `List.map` etc. are trivial to define in OCaml
itself, so we don't need to implement them natively.
