The reg-rs baseline for eval_string_conversion expects:
  int_of_string "" -> EVAL ERROR
Current behavior in the built interpreter (after de562aa and TCO):
  int_of_string "" -> 0

Figure out which is correct and act on it. Steps:

1. Find int_of_string_impl in src/ocaml.pas. Read what it actually
   does for empty input.

2. Decide the correct behavior:
   - Real OCaml's int_of_string "" raises Failure "int_of_string".
     We don't have exceptions, so we use eval_error (EVAL ERROR).
   - Returning 0 silently is almost certainly wrong - it'd mask
     parse failures in user programs.
   - Recommend: restore EVAL ERROR for empty input.

3. If the fix is small (one or two lines in int_of_string_impl),
   apply it and rebuild.

4. Confirm the eval_string_conversion reg-rs test passes WITHOUT
   rebasing.

5. If the fix is bigger than expected, abort this step with
   agentrail abort and defer to its own saga.

Out of scope: rebasing the other stale baselines (next step),
touching sibling repos.