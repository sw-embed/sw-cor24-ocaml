Add List.map, List.filter, List.fold_left, List.iter as builtins.

Scope: these four only. Skip List.init (plan: explicitly out of scope), List.length/rev/hd/tl (already implemented).

These should be closures that take one or two arguments depending on arity:
- List.iter : ('a -> unit) -> 'a list -> unit
- List.map : ('a -> 'b) -> 'a list -> 'b list
- List.filter : ('a -> bool) -> 'a list -> 'a list
- List.fold_left : ('a -> 'b -> 'a) -> 'a -> 'b list -> 'a

Approach: follow the existing pattern for List.length and List.rev in src/ocaml.pas:
- Intern each name in name_pool (procedure intern_list_module).
- In EK_VAR eval, return mk_val_closure(noff, nlen, nil, nil) — a builtin-marker closure.
- In EK_APP eval (nil-body closure branch), recognize each name and execute.

Because map/filter/fold/iter take a function as first arg, the natural implementation is: closure returns a partial-application closure that holds the function, then when applied to a list walks it and calls eval_expr on the function via EK_APP machinery.

Alternatively, implement each as a function-valued builtin that returns a NEW VK_CLOSURE whose body is a synthesized AST. That's more code but lets you reuse normal evaluator plumbing.

Simplest working path: implement each as a two-step: the first apply stashes the function in a VK_CLOSURE (encoded somehow, e.g. head=function, name=List.map_partial), then the second apply walks the list invoking the stashed function. Study how existing two-arg builtins are done if any, or just add the machinery.

Tests: tests/eval_list_higher_order.ml with bullet cases:
  List.map (fun x -> x * 2) [1;2;3]              (expected: [2; 4; 6])
  List.filter (fun x -> x mod 2 = 0) [1;2;3;4]   (expected: [2; 4])
  List.fold_left (fun acc x -> acc + x) 0 [1;2;3;4]   (expected: 10)
  List.iter print_int [1;2;3]                    (expected: prints 1, 2, 3 each on own line; returns ())

Then register with reg-rs: REG_RS_DATA_DIR=work/reg-rs reg-rs create -t eval_list_higher_order -c './scripts/run-ocaml.sh tests/eval_list_higher_order.ml'

Before committing: check wc -c src/ocaml.pas stays under ~65,000. We're at ~65,500 now, so this step will need to compact or spill. If it doesn't fit, pause and report.