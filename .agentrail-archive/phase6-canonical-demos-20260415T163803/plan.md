Close out the canonical one-liner demos from docs/possible-demos.txt that don't work yet. Ordered by empirically-measured leverage against that doc:

1. List higher-order builtins (List.map, List.filter, List.fold_left, List.iter) — unlocks 3 failing canonical demos in one step. Highest leverage.
2. string_of_int / int_of_string builtins — unlocks 'print_endline (string_of_int ...)' style demos.
3. when-guards in match arms — unlocks 'let abs x = match x with n when n < 0 -> -n | n -> n'. Cheap and isolated.
4. Function-form let with pattern args — unlocks 'let swap (x, y) = (y, x)'.
5. Per-demo reg-rs tests — one .ml + .rgt per canonical demo, matching ../sw-cor24-basic's one-scenario-per-test layout. Each test file is ~1-3 lines.

Explicitly out of scope: operator-as-function (+), user-defined operators (|>), List.init, pipeline demos. The plan for phase5 already flagged these as lowest-value, and they each need their own significant parser work.

Hard constraint: the p24p compiler truncates Pascal source around 65,536 bytes. Current src/ocaml.pas is ~65KB. Any new feature must either (a) fit in remaining headroom by being compact, or (b) pay for itself by removing older bulk. Measure before committing.