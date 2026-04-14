# Saga Plan: Lists, Pattern Matching, and Option

Future saga design based on `docs/possible-demos.txt`. This is the
single highest-impact next direction for the OCaml interpreter: it
unlocks roughly half the demos in that document and turns the language
from "ML-flavored arithmetic" into "recognizably OCaml."

## Why This Saga

The currently working language can do this:

```ocaml
let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5
```

But this is the canonical OCaml introduction:

```ocaml
let rec fact = function 0 -> 1 | n -> n * fact (n - 1)
```

The difference is **pattern matching**. Lists give us the data structure
that makes pattern matching matter:

```ocaml
let rec sum = function [] -> 0 | h :: t -> h + sum t
sum [1; 2; 3; 4]  (* => 10 *)
```

Adding lists without pattern matching (the current `phase3-lists-pairs`
plan) gets us `hd`/`tl`/`is_empty` -- usable but unidiomatic. Adding
pattern matching without lists has nothing interesting to match against.
**The two features must ship together.**

## Demo Targets

From `docs/possible-demos.txt`, this saga unlocks:

```ocaml
(* Section 5: Pattern matching *)
match 3 with 1 -> "one" | 2 -> "two" | _ -> "many"
let abs = function n when n < 0 -> -n | n -> n   (* without `when` -- see scope *)

(* Section 6: Lists *)
[1; 2; 3]
let rec map = fun f -> function [] -> [] | h :: t -> f h :: map f t
let rec sum = function [] -> 0 | h :: t -> h + sum t
let rec length = function [] -> 0 | _ :: t -> 1 + length t

(* Section 9: Option *)
let safe_div = fun x y -> if y = 0 then None else Some (x / y)
match Some 3 with Some x -> x | None -> 0
```

## Saga Scope

### IN scope (Phase 2 + early Phase 3 from PRD)

1. **List values**: `VK_NIL`, `VK_CONS` (head + tail pointers)
2. **List syntax**: `[]`, `[a; b; c]`, `e1 :: e2`
3. **Option values**: `VK_NONE`, `VK_SOME` (one payload pointer)
4. **Option syntax**: `None`, `Some e` parsed as identifier or constructor application
5. **Pattern matching**: `match e with p1 -> e1 | p2 -> e2 | ...`
   - Constant patterns: `0`, `true`, `[]`, `None`
   - Wildcard `_`
   - Variable binding (binds and matches anything)
   - Cons pattern `h :: t`
   - Constructor patterns `Some x`, `None`
   - List literal pattern `[a; b; c]` (sugar for cons chain ending in `[]`)
6. **REPL list/option printing**
   - `[1; 2; 3]` displays as `[1; 2; 3]`
   - `[]` displays as `[]`
   - `Some 3` displays as `Some 3`, `None` as `None`

### OUT of scope (deferred)

- Pairs/tuples and `,` syntax (separate small saga)
- Pattern matching `when` guards
- Named ADTs (`type color = Red | Green | Blue`)
- Strings as a first-class type
- `function` keyword as alternative to `fun x -> match x with ...`
  (parse it as sugar in a follow-up step if time permits)
- Pipeline operator `|>`

### Open question (decide during step 1)

The stash from the previous attempt at lists hit a "built-in dispatch
returns blank" bug that was never root-caused. Step 1 must reproduce
the bug on a clean tree and either fix it or file an upstream issue.
The new chr() fix in p24p (issue #16) may have already resolved it.

## Step Plan

1. **`debug-list-dispatch`** — Apply the WIP stash, rebuild against
   current pinned compiler, see if `nil` and `is_empty nil` work now
   that #16 is fixed. If still broken, isolate and file an issue.

2. **`list-values-builtins`** — Land `VK_NIL`, `VK_CONS`, `mk_val_nil`,
   `mk_val_cons`, and primitives `nil`, `hd`, `tl`, `is_empty`. Update
   REPL printing for VK_NIL (`[]`) and VK_CONS (recursive walk:
   `[h; t1; t2; ...]`).

3. **`list-syntax`** — Add `TK_LBRACKET`, `TK_RBRACKET`, `TK_COLONCOLON`.
   Parse `[]` (atom), `[e1; e2; e3]` (atom -> cons chain), `::`
   (right-associative binary, precedence between `+` and `=`).

4. **`option-values-syntax`** — Add `VK_NONE`, `VK_SOME`. Parse
   `None` as a built-in nullary constructor and `Some e` as a unary
   constructor application. Print `None` and `Some x`.

5. **`match-parser`** — Add `TK_MATCH`, `TK_WITH`, `TK_PIPE`,
   `TK_UNDERSCORE`. New AST node `EK_MATCH` with scrutinee, list of
   `(pattern, body)` arms. Pattern AST nodes:
   `PK_INT`, `PK_BOOL`, `PK_VAR`, `PK_WILDCARD`, `PK_NIL`, `PK_CONS`,
   `PK_NONE`, `PK_SOME`, `PK_LIST` (sugar).

6. **`match-evaluator`** — Implement pattern matching: try each arm,
   on a match bind variables and evaluate the body. On no match,
   raise `Match_failure` (eval_error with a specific message).

7. **`pattern-match-demos`** — Write the demo programs from this doc:
   `sum`, `length`, `map`, `safe_div`, `abs`. Add reg-rs baselines.
   Update README with the canonical OCaml factorial:
   `let rec fact = fun n -> match n with 0 -> 1 | _ -> n * fact (n-1)`.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Stash dispatch bug recurs | Step 1 isolates and files upstream issue if needed |
| Pattern match parser is large | Build incrementally: literal patterns first, then cons, then list literal sugar |
| Cons cell printing recursion deep | Already have heap headroom from PVM SRAM fix; bound to 4KB src reasonable |
| MAX_PROCS again | p24p MAX_PROCS=128 now; we have ~30, plenty of room |
| Memory pressure from new code | Single-file growth still under 32KB INPUT_BUF_SIZE |

## Success Criteria

The REPL session below must work end-to-end:

```
> let rec sum = fun l -> match l with [] -> 0 | h :: t -> h + sum t in sum [1; 2; 3; 4]
10
> let rec length = fun l -> match l with [] -> 0 | _ :: t -> 1 + length t in length [10; 20; 30]
3
> let rec map = fun f l -> match l with [] -> [] | h :: t -> f h :: map f t in map (fun x -> x * 2) [1; 2; 3]
[2; 4; 6]
> let safe_div = fun x y -> if y = 0 then None else Some (x / y) in safe_div 10 3
Some 3
> let safe_div = fun x y -> if y = 0 then None else Some (x / y) in safe_div 10 0
None
> match Some 42 with Some x -> x | None -> 0
42
```

When that runs, the OCaml interpreter has crossed the line from
"toy" to "actually OCaml-ish." That's the saga's exit criterion.

## What Comes After

Once this saga is done, natural next directions:

- **Tuples + records** — `(a, b)`, `let (x, y) = pair in ...`,
  destructuring patterns
- **Strings** — char arrays as first-class values, `^` concat,
  `print_endline`
- **Named ADTs** — `type color = Red | Green | Blue`,
  `function Red -> "R" | ...`
- **Standard prelude** — `List.map`, `List.filter`, `List.fold_left`
  written in OCaml itself, loaded automatically at REPL startup
- **Pipeline** — `let (|>) x f = f x` as a one-line user definition,
  then ship it in the prelude
