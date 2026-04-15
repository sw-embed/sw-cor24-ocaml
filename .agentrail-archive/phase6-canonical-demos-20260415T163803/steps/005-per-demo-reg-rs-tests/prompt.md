Add per-demo reg-rs tests for canonical OCaml one-liners from docs/possible-demos.txt that the interpreter now supports.

Goal: one .ml + .rgt per canonical demo, matching ../sw-cor24-basic's one-scenario-per-test layout. Each test file is ~1-3 lines. This grows demo coverage and makes regressions easy to localize.

Scope — write tests for these canonical demos (as many as feasible; skip any that still don't run):
- 42                                                           => 42
- 1 + 2 * 3                                                    => 7
- "OCaml" ^ " rocks"                                           => "OCaml rocks"
- let x = 10 in x * x                                          => 100
- (fun x -> x * 2) 5                                           => 10
- let rec fact n = if n = 0 then 1 else n * fact (n - 1) in fact 5    => 120
- let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2) in fib 10 => 55
- match 3 with 1 -> "one" | 2 -> "two" | _ -> "many"          => "many"
- let abs x = match x with n when n < 0 -> -n | n -> n in abs (-7)   => 7
- List.map (fun x -> x * 2) [1;2;3]                            => [2; 4; 6]
- List.filter (fun x -> x mod 2 = 0) [1;2;3;4]                 => [2; 4]
- List.fold_left (fun a b -> a + b) 0 [1;2;3;4]                => 10
- let swap (x, y) = (y, x) in swap (1, 2)                      => (2, 1)
- print_endline (string_of_int (List.length [1;2;3]))          => "3" line
- Some 42                                                      => Some 42
- let safe_div x y = if y = 0 then None else Some (x / y) in safe_div 10 2  => Some 5

Layout: tests/canonical_<short_name>.ml + matching .rgt under work/reg-rs/, registered with reg-rs (mirror how existing eval_*.ml tests are wired). Keep each test minimal — one expression, one assertion.

Out of scope: operator-as-function, user pipelines (|>), List.init — those are explicitly deferred.

Do not modify src/ocaml.pas. If a canonical demo turns out not to work, leave it out and note it in the step summary rather than expanding scope.